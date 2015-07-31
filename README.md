# BOSH [![Build Status](https://travis-ci.org/cloudfoundry/bosh.png?branch=master)](https://travis-ci.org/cloudfoundry/bosh) [![Code Climate](https://codeclimate.com/github/cloudfoundry/bosh.png)](https://codeclimate.com/github/cloudfoundry/bosh)

* Documentation:
	- [bosh.io/docs](https://bosh.io/docs) for installation & usage guide
	- [docs/ directory](docs/) for developer docs

* IRC: [`#bosh` on freenode](http://webchat.freenode.net/?channels=bosh)

* Mailing lists:
    - [cf-bosh](https://lists.cloudfoundry.org/pipermail/cf-bosh) for asking BOSH usage and development questions
    - [cf-dev](https://lists.cloudfoundry.org/pipermail/cf-dev) for asking CloudFoundry questions

* Archived Google groups (use mailing lists above):
	- [bosh-users](https://groups.google.com/a/cloudfoundry.org/group/bosh-users/topics) for asking BOSH usage questions
	- [bosh-dev](https://groups.google.com/a/cloudfoundry.org/group/bosh-dev/topics) for having BOSH dev discussions
	- [vcap-dev](https://groups.google.com/a/cloudfoundry.org/group/vcap-dev/topics) for asking CloudFoundry questions

* Roadmap: [Pivotal Tracker](https://www.pivotaltracker.com/n/projects/956238)

Cloud Foundry BOSH is an open source tool chain for release engineering, deployment and lifecycle management of large scale distributed services.

## Configure Azure Environment

Recommend you to reference the guide [beta-guide-template.md](https://github.com/Azure/bosh-azure-cpi-release/blob/master/docs/beta-template-guide.md) to use [Azure Resource Template](https://github.com/Azure/azure-quickstart-templates/tree/master/bosh-setup) to configure your Azure account and dev machine.

Or you can do it step by step by following the guide [beta-guide.md](https://github.com/Azure/bosh-azure-cpi-release/blob/master/docs/beta-guide.md).

Currently BOSH can only be deployed from a virtual machine in the same VNET on Azure.
After you configure your azure account, please create an Azure VM based on Ubuntu Server 14.04 LTS in your VNET.

## Configure Dev Machine

To install bosh_cli and bosh-init:

```
sudo apt-get update

sudo apt-get install -y build-essential ruby ruby-dev libxml2-dev libsqlite3-dev libxslt1-dev libpq-dev libmysqlclient-dev zlibc zlib1g-dev openssl libxslt-dev libssl-dev libreadline6 libreadline6-dev libyaml-dev sqlite3 libffi-dev

sudo gem install bosh_cli -v 1.3016.0 --no-ri --no-rdoc

wget https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-0.0.51-linux-amd64
chmod +x ./bosh-init-*
sudo mv ./bosh-init-* /usr/local/bin/bosh-init
```

To deploy BOSH, you can reference [bosh.yml](http://cloudfoundry.blob.core.windows.net/misc/bosh.yml).

To deploy cloud foundry, you can reference [cf_212.yml](http://cloudfoundry.blob.core.windows.net/misc/cf_212.yml).

## File a bug

Bugs can be filed using Github Issues.

## Contributing

Please read the [contributors' guide](CONTRIBUTING.md)