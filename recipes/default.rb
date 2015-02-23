#
# Cookbook Name:: tomcat
# Recipe:: default
#
# Copyright 2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# required for the secure_password method from the openssl cookbook
::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

include_recipe 'java'

tomcat_pkgs = value_for_platform(
  ['smartos'] => {
    'default' => ['apache-tomcat'],
  },
  'default' => ["tomcat#{node['tomcat']['base_version']}"]
  )
if node['tomcat']['deploy_manager_apps']
  tomcat_pkgs << value_for_platform(
    %w{ debian  ubuntu } => {
      'default' => "tomcat#{node['tomcat']['base_version']}-admin",
    },    
    %w{ centos redhat fedora amazon scientific oracle } => {
      'default' => "tomcat#{node['tomcat']['base_version']}-admin-webapps",
    }
    )
end

tomcat_pkgs.compact!


# Custom setup for Tomcat 8
if node['tomcat']['base_version'].to_i == 8

  # Define version and construct download link
  tomcat8_mirror  = "http://archive.apache.org"
  tomcat8_version = node['tomcat']['release_version'] || "0.15"
  tomcat8_package = "apache-tomcat-8.#{tomcat8_version}"
  tomcat8_tarball = "#{tomcat8_package}.tar.gz"
  tomcat8_link = "#{tomcat8_mirror}/dist/tomcat/tomcat-8/v8.#{tomcat8_version}/bin/#{tomcat8_tarball}"

  # Create user & group
  user node[:tomcat][:user] do
    action :create
  end
  group node[:tomcat][:group] do
    action :create
    members node[:tomcat][:user]
  end

  # Download tarball, extract, and move into $TOMCAT_HOME
  remote_file "#{Chef::Config[:file_cache_path]}/#{tomcat8_tarball}" do
    source "#{tomcat8_link}"
  end
  bash 'extract_tomcat8_binary' do
    user 'root'
    cwd Chef::Config[:file_cache_path]
    code <<-EOH
      mkdir #{node.tomcat.home}
      tar xzf #{tomcat8_tarball} --strip-components=1 --directory #{node.tomcat.home}
      mkdir -p #{node.tomcat.home}/common/classes
      chmod -R 777 #{node.tomcat.home}
      EOH
  end
  # create symlink to tomcat base
  link node[:tomcat][:base] do
    to node[:tomcat][:home]
    owner 'root'
    group 'root'
  end
  # create symlink to tomcat configuration directory
  link node[:tomcat][:config_dir] do
    to "#{node.tomcat.home}/conf"
    owner 'root'
    group 'root'
  end
  # create tomcat8 service
  template "/etc/init.d/tomcat8" do
    source 'tomcat8.erb'
    owner 'root'
    group 'root'
    mode 0755
  end
  # finally, register tomcat as a service within Chef and start it up.
  service "tomcat" do
     init_command "/etc/init.d/tomcat8"
     action :start
  end
# Otherwise, use standard package installer
else
  tomcat_pkgs.each do |pkg|
    package pkg do
      action :install
      version node['tomcat']['base_version'].to_s if platform_family?('smartos')
    end
   end
end


unless node['tomcat']['deploy_manager_apps']
  directory "#{node['tomcat']['webapp_dir']}/manager" do
    action :delete
    recursive true
  end
  file "#{node['tomcat']['config_dir']}/Catalina/localhost/manager.xml" do
    action :delete
  end
  directory "#{node['tomcat']['webapp_dir']}/host-manager" do
    action :delete
    recursive true
  end
  file "#{node['tomcat']['config_dir']}/Catalina/localhost/host-manager.xml" do
    action :delete
  end
end

node.set_unless['tomcat']['keystore_password'] = secure_password
node.set_unless['tomcat']['truststore_password'] = secure_password

if node['tomcat']['run_base_instance']
  tomcat_instance "base" do
    port node['tomcat']['port']
    proxy_port node['tomcat']['proxy_port']
    ssl_port node['tomcat']['ssl_port']
    ssl_proxy_port node['tomcat']['ssl_proxy_port']
    ajp_port node['tomcat']['ajp_port']
    shutdown_port node['tomcat']['shutdown_port']
  end
end

node['tomcat']['instances'].each do |name, attrs|
  tomcat_instance "#{name}" do
    port attrs['port']
    proxy_port attrs['proxy_port']
    ssl_port attrs['ssl_port']
    ssl_proxy_port attrs['ssl_proxy_port']
    ajp_port attrs['ajp_port']
    shutdown_port attrs['shutdown_port']
    config_dir attrs['config_dir']
    log_dir attrs['log_dir']
    work_dir attrs['work_dir']
    context_dir attrs['context_dir']
    webapp_dir attrs['webapp_dir']
    catalina_options attrs['catalina_options']
    java_options attrs['java_options']
    use_security_manager attrs['use_security_manager']
    authbind attrs['authbind']
    max_threads attrs['max_threads']
    ssl_max_threads attrs['ssl_max_threads']
    ssl_cert_file attrs['ssl_cert_file']
    ssl_key_file attrs['ssl_key_file']
    ssl_chain_files attrs['ssl_chain_files']
    keystore_file attrs['keystore_file']
    keystore_type attrs['keystore_type']
    truststore_file attrs['truststore_file']
    truststore_type attrs['truststore_type']
    certificate_dn attrs['certificate_dn']
    loglevel attrs['loglevel']
    tomcat_auth attrs['tomcat_auth']
    user attrs['user']
    group attrs['group']
    home attrs['home']
    base attrs['base']
    tmp_dir attrs['tmp_dir']
    lib_dir attrs['lib_dir']
    endorsed_dir attrs['endorsed_dir']
  end
end
