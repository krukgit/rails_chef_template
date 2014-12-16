log "Setting up RVM"

include_recipe "chef_gem"
include_recipe "rvm::system"
include_recipe "rvm::gem_package"

group "rvm" do
  action :modify
  members "ubuntu"
  append true
end

ENV['PATH']="#{node[cookbook_name]['rvm_path']}:#{ENV['PATH']}"

include_recipe "nginx::source"

config_name = "#{cookbook_name}-#{node.chef_environment}"

blog_ip = search(:node, "run_list:recipe\[#{cookbook_name}\:\:wordpress\]").first['ec2']['public_ipv4']
blog_url = "http://#{blog_ip}/blog/"

template "/etc/nginx/sites-available/#{config_name}" do
  source "etc/nginx/sites-available/config.erb"
  action :create
  mode "0644"
  notifies :reload, "service[nginx]", :delayed
  variables(blog_url: blog_url)
end

link "/etc/nginx/sites-enabled/#{config_name}" do
  to "/etc/nginx/sites-available/#{config_name}"
end

# install packages
['nodejs','libpq-dev','redis-server', 'imagemagick', 'mailutils'].each do |pkg|
  package pkg
end

service 'redis-server' do
  action [:enable, :start]
end
