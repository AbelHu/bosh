require 'spec_helper'

module Bosh::Director
  describe LinksResolver do
    subject(:links_resolver) { described_class.new(deployment_plan, logger) }

    let(:deployment_plan) do
      planner_factory = Bosh::Director::DeploymentPlan::PlannerFactory.create(event_log, logger)
      planner_factory.planner(deployment_manifest, nil, {})
    end

    let(:deployment_manifest) do
      {
        'name' => 'fake-deployment',
        'jobs' => [
          {
            'name' => 'api-server',
            'templates' => [
              {'name' => 'api-server-template', 'release' => 'fake-release', 'links' => links}
            ],
            'resource_pool' => 'fake-resource-pool',
            'instances' => 1,
            'networks' => [
              {
                'name' => 'fake-network',
                'static_ips' => ['127.0.0.2']
              }
            ],
          },
          {
            'name' => 'mysql',
            'templates' => [
              {'name' => 'mysql-template', 'release' => 'fake-release'}
            ],
            'resource_pool' => 'fake-resource-pool',
            'instances' => 1,
            'networks' => [
              {
                'name' => 'fake-network',
                'static_ips' => ['127.0.0.3']
              }
            ],
          }
        ],
        'resource_pools' => [
          {
            'name' => 'fake-resource-pool',
            'stemcell' => {
              'name' => 'fake-stemcell',
              'version' => 'fake-stemcell-version',
            },
            'network' => 'fake-network',
          }
        ],
        'networks' => [
          {
            'name' => 'fake-network',
            'type' => 'manual',
            'subnets' => [
              {
                'name' => 'fake-subnet',
                'range' => '127.0.0.0/20',
                'gateway' => '127.0.0.1',
                'static' => ['127.0.0.2', '127.0.0.3'],
              }
            ]
          }
        ],
        'releases' => [
          {
            'name' => 'fake-release',
            'version' => '1.0.0',
          }
        ],
        'compilation' => {
          'workers' => 1,
          'network' => 'fake-network',
        },
        'update' => {
          'canaries' => 1,
          'max_in_flight' => 1,
          'canary_watch_time' => 1,
          'update_watch_time' => 1,
        },
      }
    end

    let(:event_log) { Bosh::Director::Config.event_log }
    let(:logger) { Logging::Logger.new('TestLogger') }

    let(:api_server_job) do
      deployment_plan.job('api-server')
    end

    before do
      Bosh::Director::Models::Stemcell.make(name: 'fake-stemcell', version: 'fake-stemcell-version')

      allow(Bosh::Director::Config).to receive(:cloud).and_return(nil)
      allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(false)

      release_model = Bosh::Director::Models::Release.make(name: 'fake-release')
      version = Bosh::Director::Models::ReleaseVersion.make(version: '1.0.0')
      release_model.add_version(version)

      template_model = Bosh::Director::Models::Template.make(name: 'api-server-template', requires: ['db'])
      version.add_template(template_model)

      template_model = Bosh::Director::Models::Template.make(name: 'mysql-template', provides: ['db'])
      version.add_template(template_model)
    end

    describe '#resolve' do
      context 'when job requires link' do
        context 'when link source is provided by some job' do
          let(:links) { {'db' => 'fake-deployment.mysql.mysql-template.db'} }

          it 'does not fail' do
            expect {
              links_resolver.resolve(api_server_job)
            }.to_not raise_error
          end
        end

        context 'when links source is not provided' do
          let(:links) { {'db' => 'fake-deployment.mysql.mysql-template.non_existent'} }

          it 'fails'  do
            expect {
              links_resolver.resolve(api_server_job)
            }.to raise_error DeploymentInvalidLink, "Link 'non_existent' is not provided by template 'mysql-template' in job 'mysql'"
          end
        end

        context 'when link format is invalid' do
          let(:links) { {'db' => 'mysql.mysql-template.db'} }

          it 'fails' do
            expect {
              links_resolver.resolve(api_server_job)
            }.to raise_error DeploymentInvalidLink
          end
        end

        context 'when required link is not specified in manifest' do
          let(:links) { {'other' => 'a.b.c'} }

          it 'fails' do
            expect {
              links_resolver.resolve(api_server_job)
            }.to raise_error(
                JobMissingLink,
                "Job 'api-server' requires links: [\"db\"] but only has following links: [\"other\"]"
              )
          end
        end
      end
    end
  end
end
