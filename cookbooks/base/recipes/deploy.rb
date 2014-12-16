require 'yaml'

include_recipe 'logrotate'

secret = Chef::EncryptedDataBagItem.load_secret("/etc/chef/encrypted_data_bag_secret")
git = Chef::EncryptedDataBagItem.load("keys", "git", secret)[node.chef_environment]

# setup directories
['', "shared", "shared/config", "shared/log", "shared/public/assets", "shared/certs", ".ssh"].each do |dir|
  directory File.join(node[cookbook_name]['project_dir'], dir) do
    owner "ubuntu"
    group "ubuntu"
    mode 0775
    action :create
    recursive true
  end
end

if node.chef_environment == 'staging'
  template "#{node[cookbook_name]['project_dir']}/shared/.htpasswd" do
    source "htpasswd.erb"
    owner "ubuntu"
    group "ubuntu"
    mode "0644"
    action :create
  end
end

certs = Chef::DataBag.load('certs').keys
certs.each do |cert|
  data = Chef::EncryptedDataBagItem.load('certs', cert, secret)[node.chef_environment]
  file "#{node[cookbook_name]['project_dir']}/shared/certs/#{cert}.pem" do
    content data
    owner "ubuntu"
    group "ubuntu"
    mode "0770"
    action :create
  end
end


configs = Chef::DataBag.load('config').keys
configs.each do |config|
  json = Chef::EncryptedDataBagItem.load("config", config, secret)[node.chef_environment]
  yaml = {node.chef_environment => json}.to_yaml
  file "#{node[cookbook_name]['project_dir']}/shared/config/#{config}.yml" do
    content yaml
    owner "ubuntu"
    group "ubuntu"
    mode "0770"
    action :create
  end
end

template "#{node[cookbook_name]['project_dir']}/shared/public/robots.txt" do
  source "public/robots.txt.erb"
  owner "ubuntu"
  group "ubuntu"
  mode "0644"
  action :create
end

template "#{node[cookbook_name]['project_dir']}/wrap-ssh4git.sh" do
  source "wrap-ssh4git.sh.erb"
  owner "ubuntu"
  mode 00700
  variables({path: node[cookbook_name]['project_dir']})
end

file "#{node[cookbook_name]['project_dir']}/.ssh/id_deploy" do
  content git['deploy_key']
  owner "ubuntu"
  group "ubuntu"
  mode 0600
  action :create
end

symlinks = {
  "public/robots.txt" => "public/robots.txt",
  "public/assets" => "public/assets",
  "certs" => "certs"
}.merge Hash[ configs.map{|c| ["config/#{c}.yml", "config/#{c}.yml"]} ]

deploy "#{node[cookbook_name]['project_dir']}" do
  repo node[cookbook_name]['repo']
  branch node.chef_environment == "production" ? "master" : "staging"
  action :deploy
  user "ubuntu"
  group "ubuntu"
  restart_command "touch tmp/restart.txt"
  environment({ "RAILS_ENV" => node.chef_environment })
  ssh_wrapper "#{node[cookbook_name]['project_dir']}/wrap-ssh4git.sh"

  symlink_before_migrate.clear
  symlink_before_migrate symlinks

  before_symlink do
    rvm_shell "run bundle install for #{node['rvm']['default_ruby']}" do
      user "ubuntu"
      ruby_string node['rvm']['default_ruby']
      code "bundle install --gemfile #{release_path}/Gemfile --path #{node[cookbook_name]['project_dir']}/shared/bundle --deployment --quiet --without development test"
    end
    rvm_shell "rake db:migrate" do
      user "ubuntu"
      ruby_string node['rvm']['default_ruby']
      cwd "#{release_path}"
      code "cd #{release_path} && RAILS_ENV=#{node.chef_environment} bundle exec rake db:migrate"
    end
  end
  before_restart do
    rvm_shell "run rake assets:precompile" do
      user "ubuntu"
      ruby_string node['rvm']['default_ruby']
      cwd "#{release_path}"
      code "RAILS_ENV=#{node.chef_environment} bundle exec rake assets:precompile"
    end
  end
end

parent_cookbook = cookbook_name
logrotate_app "#{parent_cookbook}-#{node.chef_environment}" do
  cookbook 'logrotate'
  path node[parent_cookbook]['project_dir']+"/shared/log/#{node.chef_environment}.log"
  frequency 'daily'
  options ['missingok', 'compress', 'delaycompress', 'notifempty', 'copytruncate', 'dateext']
  rotate 7
  lastaction "/usr/local/bin/aws s3 sync "+node[parent_cookbook]['project_dir']+"/shared/log/ s3://#{node.chef_environment == 'production' ? '' : 'staging.'}"+node[parent_cookbook]['server_url']+"/logs/#{node.name}/ --region=ap-southeast-1"
  su 'ubuntu ubuntu'
end
