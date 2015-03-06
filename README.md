Create validation key
----------------------

Go to `https://manage.opscode.com/login` and create a new organization for your startup. Refresh the page and switch the organization to your startup. Navigate to `Administration` -> `Reset Validation Key`.
Copy the newly generated key to ~/.chef/name-validator.pem.

Create Encrypted Data Bag secret
----------------------

Run `sudo bash -c "openssl rand -base64 512 | tr -d '\r\n' > /etc/chef/organization_secret"` to generate the secret used for encrypting and decrypting content of data bags.


Edit .chef/knife.rb
----------------------

* `node_name` - A name that identifies your computer
* `client_key` - Path to your private validation key
* `validation_key` - Path to your organization's validation key (the one you just created)
* `chef_server_url` - https://api.opscode.com/organizations/your_organization_name
* `knife[:aws_credential_file]` - Path to your AWS credentials
* `knife[:region]` - Your default AWS region
* `knife[:secret_file]` - data bag secret path

If your project has more than one maintainer, copy the file to .chef/knife.rb.example and add .chef/knife.rb to your project's .gitignore

Update cookbook attributes
----------------------

Rename `base` cookbook to your organization's name by running `mv cookbooks/base cookbooks/organization`.

Edit `cookbooks/organization/metadata.rb`.

Update `cookbooks/organization/attributes/rails_server.rb` with appropriate version of Ruby (`normal['rvm']['rubies']`), nginx (`normal['nginx']['version']`) and Passenger (`normal['nginx']['passenger']['version']`).

Change project variables:

* `default['base']['rvm_path']` to `default['organization']['rvm_path']`
* `default['base']['project_dir'] = "/var/proj/base-#{node.chef_environment}"` to `default['organization']['project_dir'] = "/var/proj/organization-#{node.chef_environment}"`
* `default['base']['server_url']` to `default['organization']['server_url']` and `base.com` to your website url

Modify `attributes/deploy.rb` appropriately.

Update `templates/default/htpasswd.erb` (default credentials base:Base2014).

Setup AWS
----------------------

Open AWS web console and navigate to:

### S3

Create three buckets with names corresponding to your server name and environment, e.g. *organization.com*, *staging.organization.com*, *development.organization.com*.
Make sure to do this in the correct region.

### EC2

Create 2 key pairs, e.g.: *organization-staging* and *organization-production*. Save them somewhere safe and change access permission to 600 e.g. `chmod 600 ~/.ssh/organization/*.pem`

Create 3 load balancers, e.g.: *organization-staging*, *organization-production* and *organization-blog*. For now allow only listening on port 80, unless you already have an SSL certificate.

In health check configuration change port to `81` and path to `/`.

While creating the first balancer, create a security group named *organization-lb* that will allow connecting on port 80 and 443. Use the same security group for all 3 load balancers. Don't add instances for the time being.

Create 2 security groups, e.g.: *organization-staging* and *organization-production*.

Add rules to allow SSH (TCP, port 22) connection from your current IP and TCP ports 80-81 connections from the load balancer (Add Rule -> HTTP -> Source -> Custom IP -> start typing *organization-lb*).

Create 1 additional security group: *organization-db*. Allow connections on TCP port 5432 from the two security groups you just created.

### IAM

Create two roles: *organization-production* and *organization-staging*. Role type: EC2, No Permission. Edit the roles and add the following role policies:

* role: organization-production
* policy name: s3_organization.com

        {
        "Statement": [
            {
              "Effect": "Allow",
              "Action": "s3:*",
              "Resource": [
                   "arn:aws:s3:::organization.com/*",
                   "arn:aws:s3:::organization.com"
              ]
            }
          ]
        }


* role: organization-staging
* policy name: s3_staging.organization.com

        {
        "Statement": [
            {
              "Effect": "Allow",
              "Action": "s3:*",
              "Resource": [
                   "arn:aws:s3:::staging.organization.com/*",
                   "arn:aws:s3:::staging.organization.com"
              ]
            }
          ]
        }

* role: organization-production and organization-staging
* policy name: ses


        {
        "Statement": [
            {
              "Effect":"Allow",
              "Action": ["ses:SendRawEmail","ses:SendEmail"],
              "Resource":"*"
            }
          ]
        }

### Create database

Navigate to RDS. Setup PostgreSQL db.m1.small with multi AZ deployment and 10 GB storage. Select previously created *organization-db* as security group.
Select backup and maintenance windows to be the early morning in your timezone.

### Upload cookbooks

Run `bundle install`

Upload community cookbooks using `berks upload`.

Upload cookbook using `knife cookbook upload organization`



### Data bags

Create config bag

    knife data bag create config --secret-file /etc/chef/organization_secret

Every `item` you add to this data bag will generate a corresponding `config/item.yml` configuration file.
Items should have three keys: `id`, `staging`, `production`. Id is the name of the item. Content of `staging` and `production` will populate the yml file in staging and production environment respectively.

You can generate json config from existing `yml` files running the following command in ruby console

    config='database'; puts JSON.pretty_generate({id: config}.merge(YAML.load(File.read("config/#{config}.yml")).slice('staging','production'))); 1

Sample config files:

Create `config/database.yml`

    knife data bag create config database --secret-file /etc/chef/organization_secret
    {
        "id": "database",
        "production": {
            "adapter": "postgresql",
            "encoding": "unicode",
            "username": "<USERNAME>",
            "host": "<HOST>",
            "password": "<PASSWORD>",
            "port": 5432,
            "database": "<DBNAME>"
        },
        "staging": {
            "adapter": "postgresql",
            "encoding": "unicode",
            "username": "<USERNAME>",
            "host": "<HOST>",
            "password": "<PASSWORD>",
            "port": 5432,
            "database": "<DBNAME>_staging"
        }
    }


Create `config/newrelic.yml`

    knife data bag create config newrelic --secret-file /etc/chef/organization_secret
    {
        "id": "newrelic",
        "production": {
            "license_key": "<LICENSE KEY>",
            "app_name": "<ORGANIZATION NAME>",
            "monitor_mode": true,
            "developer_mode": false,
            "log_level": "info",
            "browser_monitoring": {
                "auto_instrument": true
            },
            "audit_log": {
                "enabled": false
            },
            "capture_params": false,
            "transaction_tracer": {
                "enabled": true,
                "transaction_threshold": "apdex_f",
                "record_sql": "obfuscated",
                "stack_trace_threshold": 0.5
            },
            "error_collector": {
                "enabled": true,
                "ignore_errors": "ActionController::RoutingError,Sinatra::NotFound"
            }
        },
        "staging": {
            "license_key": "<LICENSE KEY>",
            "app_name": "<ORGANIZATION> (Staging)",
            "monitor_mode": true,
            "developer_mode": false,
            "log_level": "info",
            "browser_monitoring": {
                "auto_instrument": true
            },
            "audit_log": {
                "enabled": false
            },
            "capture_params": false,
            "transaction_tracer": {
                "enabled": true,
                "transaction_threshold": "apdex_f",
                "record_sql": "obfuscated",
                "stack_trace_threshold": 0.5
            },
            "error_collector": {
                "enabled": true,
                "ignore_errors": "ActionController::RoutingError,Sinatra::NotFound"
                }
        }
    }

Create `config/secrets.yml`

    (cd .. && rake secret)
    (cd .. && rake secret)
    knife data bag create config newrelic --secret-file /etc/chef/organization_secret
    {
        "id": "secrets",
        "production": {
            "secret_key_base": "<KEYBASE1>",
            "aws": {
                "region": "ap-southeast-1",
                "bucket": "<PRODUCTION BUCKET>",
                "log_level": "debug"
            }
        },
        "staging": {
            "secret_key_base": "<KEYBASE2>",
            "aws": {
                "region": "ap-southeast-1",
                "bucket": "<STAGING BUCKET>",
                "log_level": "debug"
            }
        }
    }


Create 2 deploy keys (production and staging)

    ssh-keygen -C organization-deploy-production -f ~/.ssh/organization-deploy-production
    ssh-keygen -C organization-deploy-staging -f ~/.ssh/organization-deploy-staging

Add public keys to github repository (navigate to the rails project\'s repository -> Settings -> Deploy keys -> Add deploy key x2).

    cat ~/.ssh/organization-deploy-production.pub
    cat ~/.ssh/organization-deploy-staging.pub

Add private keys to `keys git` data bag (you need to replace new line with \n)

    cat ~/.ssh/organization-deploy-production | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
    cat ~/.ssh/organization-deploy-staging | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'

    knife data bag create keys git --secret-file /etc/chef/organization_secret
    {
        "id": "git",
        "production": {
            "deploy_key": "<PRIVATE DEPLOY KEY1>"
        },
        "staging": {
            "deploy_key": "<PRIVATE DEPLOY KEY2>"
        }
    }

Create empty certs data bag (you will later use it for payments and push notification certs)

    knife data bag create certs --secret-file /etc/chef/organization_secret

Create a staging branch in Rails project\'s repostiory

    git checkout -b staging
    git push origin staging

Create environments

    knife environment create staging
    knife environment create production

Instance definition
---------------------

Add your AWS credentials to ~/.chef/aws.credentials

    AWSAccessKeyId=<ACCESS_KEY>
    AWSSecretKey=<SECRET_KEY>

Update `setup_staging.sh` and `setup_production.sh` with security group ids, role names, key names and ami id.
