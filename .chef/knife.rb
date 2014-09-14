# See http://docs.opscode.com/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "dev"
client_key               "#{ENV['HOME']}/.chef/dev.pem"
validation_client_name   "validator"
validation_key           "#{ENV['HOME']}/.chef/validator.pem"
chef_server_url          "https://api.opscode.com/organizations/my_organization"
cache_type               'BasicFile'
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["#{current_dir}/../cookbooks"]

knife[:aws_credential_file] = "#{ENV['HOME']}/.chef/aws.credentials"
knife[:region] = 'ap-southeast-1'
knife[:editor] = 'emacs'
knife[:secret_file] = '/etc/chef/chef_secret'
