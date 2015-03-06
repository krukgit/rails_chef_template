# setup locale
execute "locale-gen" do
  command "locale-gen en_US.UTF-8"
end

execute "dpkg-reconfigure-locales" do
  command "dpkg-reconfigure locales"
end

# update repositories
include_recipe "apt"

# setup ntp
include_recipe "ntp"

# setup hostname
file '/etc/hostname' do
  content "#{node.name}\n"
  mode "0644"
end

if node[:hostname] != node.name
  execute "hostname #{node.name}"
  ohai "reload"
end

template "/etc/hosts" do
  source "etc/hosts.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(:servers => search(:node, "chef_environment:#{node.chef_environment}"),
            :region => node['ec2']['placement_availability_zone'].match(/(\w*\-\w*\-\d*).*/)[1])
end

template "/etc/sudoers" do
  source "etc/sudoers.erb"
  owner "root"
  group "root"
  mode "0440"
end

template "/etc/ssh/ssh_config" do
  source "etc/ssh/ssh_config"
  owner "root"
  group "root"
  mode "644"
  notifies :restart, "service[ssh]", :delayed
end

service "ssh" do
  provider Chef::Provider::Service::Upstart
  action :nothing
  supports restart: true
end

# install packages
['git', 'emacs', 'vim', 'openssl', 'unzip', 'python-pip',
 'postgresql-client-common', 'postgresql-client-9.3'].each do |pkg|
  package pkg
end

template "#{ENV['HOME']}/.bashrc" do
  source "bashrc.erb"
  owner "ubuntu"
  group "ubuntu"
  mode "0644"
end

template "#{ENV['HOME']}/.aws_config" do
  source "aws_config.erb"
  owner "ubuntu"
  group "ubuntu"
  mode "0644"
end

execute "install AWS CLI" do
  command "pip install awscli"
end

# setup newrelic
include_recipe "#{cookbook_name}::newrelic"
