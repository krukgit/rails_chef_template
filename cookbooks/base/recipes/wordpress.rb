secret = Chef::EncryptedDataBagItem.load_secret("/etc/chef/encrypted_data_bag_secret")
database = Chef::EncryptedDataBagItem.load('config', 'database', secret)

directory node[cookbook_name]['wordpress']['dir'] do
  owner "www-data"
  group "www-data"
  mode 0775
  action :create
  recursive true
end

bash "retrieve most recent copy of the blog" do
  user "www-data"
  cwd "/tmp/"
  code <<-EOH
  filename=`/usr/local/bin/aws s3 ls #{node[cookbook_name]['wordpress']['s3_backup_path']} --region=#{node[cookbook_name]['wordpress']['s3_region']} | awk '{print $4}' | sort -r | head -1` &&
  /usr/local/bin/aws s3 cp #{node[cookbook_name]['wordpress']['s3_backup_path']}$filename /tmp/ --region=#{node[cookbook_name]['wordpress']['s3_region']} &&
  tar -zxvf /tmp/$filename -C #{node[cookbook_name]['wordpress']['dir']}
  EOH
  action :nothing
  subscribes :run, "directory[#{node[cookbook_name]['wordpress']['dir']}]", :immediately
end

template "#{node[cookbook_name]['wordpress']['dir']}/wp-config.php" do
  source "wp-config.php.erb"
  owner "www-data"
  group "www-data"
  mode "0644"
  action :create
  variables({ database: database['wordpress'] })
end

cron "daily backup" do
  hour "20"
  minute "0"
  user "ubuntu"
  command "file=/tmp/folr-blog.`date +\\%F`.tgz && tar -zcvf $file --exclude='wp-config.php' -C #{node[cookbook_name]['wordpress']['dir']} . && /usr/local/bin/aws s3 cp $file #{node[cookbook_name]['wordpress']['s3_backup_path']} --region=#{node[cookbook_name]['wordpress']['s3_region']} && rm $file"
end

['php5-fpm', 'php5-mysql', 'php5-imagick', 'php5-curl'].each do |pkg|
  package pkg
end

execute "disable_fix_pathinfo" do
  command "sed -i s/.*cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g /etc/php5/fpm/php.ini"
end

execute "restart php" do
  command "service php5-fpm restart"
  action :nothing
  subscribes :run, "execute[disable_fix_pathinfo]", :immediately
end

# For some reason this causes 'invalid byte sequence in US-ASCII' error on fresh chef runs
#
# service "php5-fpm" do
#   provider Chef::Provider::Service::Upstart
#   subscribes :restart, "execute[disable_fix_pathinfo]", :immediately
# end
