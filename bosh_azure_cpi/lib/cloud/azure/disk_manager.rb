module Bosh::AzureCloud
  class DiskManager
    DISK_FAMILY = 'bosh'

    attr_reader   :container_name
    attr_accessor :logger
    
    include Bosh::Exec
    include Helpers

    def initialize(container_name, storage_manager, blob_manager)
      @container_name = container_name
      @storage_manager = storage_manager
      @blob_manager = blob_manager

      @logger = Bosh::Clouds::Config.logger

      @blob_manager.create_container(container_name)
    end

    def has_disk?(disk_id)
      (!find(disk_id).nil?)
    end

    def find(disk_name)
      logger.info("Start to find disk: disk_name: #{disk_name}")
      
      disk = nil
      begin
        response = handle_response http_get("/services/disks/#{disk_name}")
        info = response.css('Disk')
        disk = {
          :affinity_group => xml_content(info, 'AffinityGroup'),
          :logical_size_in_gb => xml_content(info, 'LogicalSizeInGB'),
          :media_link => xml_content(info, 'MediaLink'),
          :name => xml_content(info, 'Name')
        }
      rescue => e
        logger.debug("Failed to find disk: #{e.message}\n#{e.backtrace.join("\n")}")
      end
      disk
    end
    
    ##
    # Creates a disk (possibly lazily) that will be attached later to a VM.
    #
    # @param [Integer] size disk size in GB
    # @return [String] disk name
    def create_disk(size)
      disk_name = "bosh-disk-#{SecureRandom.uuid}"
      logger.info("Start to create disk: disk_name: #{disk_name}")
      
      logger.info("Start to create an empty vhd blob: blob_name: #{disk_name}.vhd")
      @blob_manager.create_empty_vhd_blob(container_name, "#{disk_name}.vhd", size)
      
      begin
        logger.info("Start to create an disk with created VHD")
        disk_name
      rescue => e
        @blob_manager.delete_blob(container_name, "#{disk_name}.vhd")
        cloud_error("Failed to create disk: #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    def delete_disk(disk_name)
    end

    def snapshot_disk(disk_id, metadata)
      snapshot_disk_name = "bosh-disk-#{SecureRandom.uuid}"

      logger.info("Start to take the snapshot for the blob of the disk #{disk_id}")
      disk = find(disk_id)
      logger.info("Get the media link of the disk: #{disk[:media_link]}")

      blob_info = disk[:media_link].split('/')
      blob_container_name = blob_info[3]
      disk_blob_name = blob_info[4]
      @blob_manager.snapshot_blob(blob_container_name, disk_blob_name, metadata, "#{snapshot_disk_name}.vhd")
      snapshot_disk_name
    end
  end
end
