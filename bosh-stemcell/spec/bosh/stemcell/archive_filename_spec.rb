require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/infrastructure'

module Bosh
  module Stemcell
    describe ArchiveFilename do
      subject(:archive_filename) do
        ArchiveFilename.new(version, infrastructure, 'bosh-stemcell', light)
      end

      describe '#to_s' do
        context 'when stemcell is light' do
          let(:light) { true }
          let(:infrastructure) { Infrastructure::Vsphere.new }

          context 'and the version is a build number' do
            let(:version) { 123 }
            it 'prepends light before name' do
              expect(archive_filename.to_s).to eq ('light-bosh-stemcell-123-vsphere-esxi-ubuntu.tgz')
            end
          end

          context 'and the version is latest' do
            let(:version) { 'latest' }

            it 'appends light after latest' do
              expect(archive_filename.to_s).to eq ('light-bosh-stemcell-latest-vsphere-esxi-ubuntu.tgz')
            end
          end
        end

        context 'when stemcell is not light' do
          let(:light) { false }
          context 'when the infrastructure has a hypervisor' do
            let(:infrastructure) { Infrastructure::OpenStack.new }

            context 'and the version is a build number' do
              let(:version) { 123 }

              it 'ends with the infrastructure, hypervisor and build number' do
                expect(archive_filename.to_s).to eq('bosh-stemcell-123-openstack-kvm-ubuntu.tgz')
              end
            end

            context 'and the version is latest' do
              let(:version) { 'latest' }

              it 'begins with latest and ends with the infrastructure' do
                expect(archive_filename.to_s).to eq('bosh-stemcell-latest-openstack-kvm-ubuntu.tgz')
              end
            end
          end

          context 'when the infrastructure does not have a hypervisor' do
            let(:infrastructure) { Infrastructure::Aws.new }

            context 'and the version is a build number' do
              let(:version) { 123 }

              it 'ends with the infrastructure and build number' do
                expect(archive_filename.to_s).to eq('bosh-stemcell-123-aws-xen-ubuntu.tgz')
              end
            end

            context 'and the version is latest' do
              let(:version) { 'latest' }

              it 'begins with latest and ends with the infrastructure' do
                expect(archive_filename.to_s).to eq('bosh-stemcell-latest-aws-xen-ubuntu.tgz')
              end
            end
          end
        end
      end
    end
  end
end
