require 'azure'
require 'base64'
require 'digest/md5'

module Bosh
  module Blobstore
    class AzureBlobstoreClient < BaseClient

      AZURE_ENVIRONMENTS = {
        'AzureCloud' => {
          'portalUrl' => 'http://go.microsoft.com/fwlink/?LinkId=254433',
          'publishingProfileUrl' => 'http://go.microsoft.com/fwlink/?LinkId=254432',
          'managementEndpointUrl' => 'https://management.core.windows.net',
          'resourceManagerEndpointUrl' => 'https://management.azure.com/',
          'sqlManagementEndpointUrl' => 'https://management.core.windows.net:8443/',
          'sqlServerHostnameSuffix' => '.database.windows.net',
          'galleryEndpointUrl' => 'https://gallery.azure.com/',
          'activeDirectoryEndpointUrl' => 'https://login.windows.net',
          'activeDirectoryResourceId' => 'https://management.core.windows.net/',
          'commonTenantName' => 'common',
          'activeDirectoryGraphResourceId' => 'https://graph.windows.net/',
          'activeDirectoryGraphApiVersion' => '2013-04-05'
        },
        'AzureChinaCloud' => {
          'portalUrl' => 'http://go.microsoft.com/fwlink/?LinkId=301902',
          'publishingProfileUrl' => 'http://go.microsoft.com/fwlink/?LinkID=301774',
          'managementEndpointUrl' => 'https://management.core.chinacloudapi.cn',
          'sqlManagementEndpointUrl' => 'https://management.core.chinacloudapi.cn:8443/',
          'sqlServerHostnameSuffix' => '.database.chinacloudapi.cn',
          'activeDirectoryEndpointUrl' => 'https://login.chinacloudapi.cn',
          'activeDirectoryResourceId' => 'https://management.core.chinacloudapi.cn/',
          'commonTenantName' => 'common',
          'activeDirectoryGraphResourceId' => 'https://graph.windows.net/',
          'activeDirectoryGraphApiVersion' => '2013-04-05'
        }
      }

      attr_reader :container_name

      # Blobstore client for Azure blob storage
      # @param [Hash] options Azure BlobStore options
      # @option options [Symbol] environment
      # @option options [Symbol] container_name
      # @option options [Symbol] storage_account_name
      # @option options [Symbol] storage_access_key
      def initialize(options)
        super(options)
        @container_name = @options[:container_name]

        Azure.configure do |config|
          config.storage_account_name = @options[:storage_account_name]
          config.storage_access_key   = @options[:storage_access_key]
        end

        @azure_blob_service = Azure::BlobService.new

        begin
          container = @azure_blob_service.get_container_properties(container_name)
        rescue Azure::Core::Error => e
          # container does not exist
          @azure_blob_service.create_container(container_name)
        end
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to initialize Azure blobstore: #{e.description}"
      end

      def create_file(id, file)
        id ||= generate_object_id

        raise BlobstoreError, "object id #{id} is already in use" if object_exists?(id)

        block_list = []
        counter    = 1

        open(file, 'rb') do |f|
          f.each_chunk {|chunk|
            block_id = counter.to_s.rjust(5, '0')
            block_list << [block_id, :uncommitted]

            options = {
              :content_md5 => Base64.strict_encode64(Digest::MD5.digest(chunk)),
              :timeout     => 300 # seconds
            }

            md5 = @azure_blob_service.create_blob_block(container_name, id, block_id, chunk, options)
            counter += 1
          }
        end

        @azure_blob_service.commit_blob_blocks(container_name, id, block_list)

        id
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to create object, Azure response error: #{e.description}"
      end

      def get_file(id, file)
        blob, content = @azure_blob_service.get_blob(container_name, id)
        file.write(content)
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to find object '#{id}', Azure response error: #{e.description}"
      end

      def delete_object(id)
        @azure_blob_service.delete_blob(container_name, id)
      rescue Azure::Core::Error => e
        raise BlobstoreError, "Failed to delete object '#{id}', Azure response error: #{e.description}"
      end

      def object_exists?(id)
        result = @azure_blob_service.get_blob_properties(container_name, id)
        true
      rescue Azure::Core::Error => e
        false
      end
    end

    class ::File
      def each_chunk(chunk_size = 2* 1024 * 1024)
        yield read(chunk_size) until eof?
      end
    end
  end
end
