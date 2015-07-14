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

Recommend you to reference the guide [deploy_for_azure/guide_template.doc](https://raw.githubusercontent.com/Azure/bosh/azure_cpi_external/deploy_for_azure/guide_template.doc) to use [Azure Resource Template](https://github.com/Azure/azure-quickstart-templates/tree/master/microbosh-setup) to configure your Azure account and dev machine.

Or you can do it step by step by following the guide [deploy_for_azure/guide.doc](https://raw.githubusercontent.com/Azure/bosh/azure_cpi_external/deploy_for_azure/guide.doc).

Currently MicroBOSH can only be deployed from a virtual machine in the same VNET on Azure.
After you configure your azure account, please create a VM in your VNET. 
Recommend you to use Ubuntu Server 14.04LTS. If you use other distros, please update install.sh before executing it.

## Install

To install the Azure BOSH CLI:

```
wget https://raw.githubusercontent.com/Azure/bosh/azure_cpi_external/deploy_for_azure/install.sh
./install.sh
```

To deploy MicroBosh, you can reference deploy_for_azure/config/micro_bosh.yml.

To deploy single VM cloud foundry, you can reference deploy_for_azure/config/micro_cf.yml.

## File a bug

Bugs can be filed using Github Issues.

## Contributing

Please read the [contributors' guide](CONTRIBUTING.md)