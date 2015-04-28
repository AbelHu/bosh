module Bosh::AzureCloud
  class AzureClient
    attr_accessor :storage_manager
    attr_accessor :blob_manager
    attr_accessor :disk_manager
    attr_accessor :stemcell_manager
    attr_accessor :vm_manager

    include Helpers

    def initialize(azure_properties, registry, logger)
      Azure::Core::Utility.initialize_external_logger(logger)
      Azure.configure do |config|
        config.management_certificate = azure_properties['azure_certificate_file']

        config.subscription_id        = azure_properties['subscription_id']
        config.management_endpoint    = azure_properties['management_endpoint']
        config.storage_blob_host      = azure_properties['management_endpoint'].sub("//management.","//#{azure_properties['storage_account_name']}.blob.")
        config.storage_account_name   = azure_properties['storage_account_name']
        config.storage_access_key     = azure_properties['storage_access_key']
      end

      container_name = azure_properties['container_name'] || 'bosh'

      if azure_properties['tenant_id']
        azure_cmd("azure login -u #{azure_properties['client_id']} -p '#{azure_properties['client_secret']}' --tenant #{azure_properties['tenant_id']} --service-principal --quiet --json",logger)
      elsif azure_properties['client_id']
        azure_cmd("azure login -u #{azure_properties['client_id']} -p '#{azure_properties['client_secret']}' --json",logger)
      end

      if azure_properties['subscription_id']
        azure_cmd("azure account set  #{azure_properties['subscription_id']} --json",logger)
      end


      @storage_manager        = Bosh::AzureCloud::StorageAccountManager.new(azure_properties['storage_account_name'])
      @blob_manager           = Bosh::AzureCloud::BlobManager.new
      @disk_manager           = Bosh::AzureCloud::DiskManager.new(container_name, @storage_manager, @blob_manager)
      @stemcell_manager       = Bosh::AzureCloud::StemcellManager.new(@storage_manager, @blob_manager)
      @vm_manager             = Bosh::AzureCloud::VMManager.new(@storage_manager, registry, @disk_manager)
    end
  end
end
