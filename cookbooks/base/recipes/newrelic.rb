secret = Chef::EncryptedDataBagItem.load_secret("/etc/chef/encrypted_data_bag_secret")
license_key = Chef::EncryptedDataBagItem.load('config', 'newrelic', secret)['production']['license_key']

remote_file "/etc/apt/sources.list.d/newrelic.list" do
  source "http://download.newrelic.com/debian/newrelic.list"
  owner "root"
  group "root"
  mode 0644
  notifies :run, "execute[apt-get update]", :immediately
  action :create_if_missing
end


directory "/etc/newrelic" do
  owner "root"
  group "root"
  mode "640"
end

bash "Trust NewRelic GPG key" do
  code "apt-key add /etc/newrelic/newrelic.gpg && apt-get update"
  action :nothing
  user "root"
end

template "/etc/newrelic/newrelic.gpg" do
  source "etc/newrelic/newrelic.gpg"
  notifies :run, "bash[Trust NewRelic GPG key]", :immediately
end

package "newrelic-sysmond" do
  action :install
end

service "newrelic-sysmond" do
  action :nothing
end

template "/etc/newrelic/nrsysmond.cfg" do
  source "etc/newrelic/nrsysmond.cfg.erb"
  owner 'root'
  group 'newrelic'
  mode '0640'
  notifies :restart, resources(:service => "newrelic-sysmond")
  variables(:license_key => license_key)
end
