module Bosh::AzureCloud
  class VMManager
    attr_accessor :logger

    include Helpers

    def initialize(storage_manager, registry, disk_manager)
      @storage_manager = storage_manager
      @registry = registry
      @disk_manager = disk_manager

      @azure_cloud_service    = Azure::CloudServiceManagement::CloudServiceManagementService.new
      @azure_vm_service       = Azure::VirtualMachineManagementService.new
      @reserved_ip_manager    = Bosh::AzureCloud::ReservedIpManager.new
      @affinity_group_manager = Bosh::AzureCloud::AffinityGroupManager.new

      @logger = Bosh::Clouds::Config.logger
    end

    def create(uuid, stemcell, cloud_opts, network_configurator, resource_pool)
      logger.info("create(#{uuid}, #{stemcell}...)")
      params = {
          :vm_name             => "bosh-vm-#{uuid}",
          :vm_user             => cloud_opts['ssh_user'],
          :image               => stemcell,
          :affinity_group_name => cloud_opts['affinity_group_name'],
      }

      opts = {
          :cloud_service_name   => "bosh-service-#{uuid}",
          :storage_account_name => @storage_manager.get_storage_account_name,
          :vm_size              => resource_pool['instance_type'] || 'Small',
          :certificate_file     => cloud_opts['ssh_certificate_file'],
          :private_key_file     => cloud_opts['ssh_private_key_file']
      }

      if !network_configurator.vip_network.nil?
        affinity_group = @affinity_group_manager.get_affinity_group(cloud_opts["affinity_group_name"])

        reserved_ip = @reserved_ip_manager.find(network_configurator.reserved_ip)

        raise "Given reserved ip does not exist" if reserved_ip.nil?
        raise "Given reserved ip #{reserved_ip[:location]} does not belong to the location #{affinity_group.location}" unless reserved_ip[:location] == affinity_group.location
        raise "Given reserved ip #{reserved_ip} is in use" if reserved_ip[:in_use]

        logger.debug("reserved ip: #{reserved_ip}")
        opts[:reserved_ip_name] = reserved_ip[:name]
      end

      if (network_configurator.vnet?)
        opts[:virtual_network_name] = network_configurator.virtual_network_name
        opts[:subnet_name]          = network_configurator.subnet_name

        unless network_configurator.private_ip.nil?
          opts[:static_virtual_network_ipaddress] = network_configurator.private_ip
        end
      end

      opts[:tcp_endpoints] = network_configurator.tcp_endpoints
      opts[:udp_endpoints] = network_configurator.udp_endpoints

      params[:custom_data] = get_user_data(params[:vm_name], network_configurator.dns)

      logger.debug("params: #{params}")
      logger.debug("opts: #{opts}")

      max_retry = 10

      begin
        retry_interval = 0
        result = @azure_vm_service.create_virtual_machine(params, opts)

        if result.is_a? String
          if result.include?("ConflictError")
            retry_interval = 6
            max_retry -= 1
          elsif result.include?("TooManyRequests")
            retry_interval = 15
            max_retry -= 1
          end
          if retry_interval != 0 && max_retry > 0
              raise "retry to create(#{uuid})"
          end
        end
      rescue => e
        sleep(retry_interval)
        logger.warn(e.message)
        retry
      end

      if result.is_a? String
        logger.error("Failed to create vm: #{result}")
        @azure_cloud_service.delete_cloud_service(opts[:cloud_service_name]) if @azure_cloud_service.get_cloud_service(opts[:cloud_service_name])
        cloud_error("vm_manager.create: #{result}")
      end

      result
    end

    def find(instance_id)
      logger.debug("find(#{instance_id})")
      cloud_service_name, vm_name = parse_instance_id(instance_id)
      @azure_vm_service.get_virtual_machine(vm_name, cloud_service_name)
    end

    def delete(instance_id)
      logger.debug("delete(#{instance_id})")
      cloud_service_name, vm_name = parse_instance_id(instance_id)
      max_retry = 10

      begin
        retry_interval = 0
        handle_response http_delete("services/hostedservices/#{cloud_service_name}?comp=media")
      rescue => e
        if e.message.include?("ConflictError")
          retry_interval = 6
          max_retry -= 1
        elsif e.message.include?("TooManyRequests")
          retry_interval = 15
          max_retry -= 1
        end

        if retry_interval != 0 && max_retry > 0
          sleep(retry_interval)
          logger.info("retry to delete(#{instance_id})")
          retry
        end
        logger.warn("delete(#{instance_id}): #{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

    def reboot(instance_id)
      logger.debug("reboot(#{instance_id})")
      cloud_service_name, vm_name = parse_instance_id(instance_id)
      @azure_vm_service.restart_virtual_machine(vm_name, cloud_service_name)
    end

    def instance_id(wala_lib_path)
      logger.debug("instance_id(#{wala_lib_path})")
      contents = File.open(wala_lib_path + "/SharedConfig.xml", "r"){ |file| file.read }

      service_name = contents.match("^*<Service name=\"(.*)\" guid=\"{[-0-9a-fA-F]+}\"[\\s]*/>")[1]
      vm_name = contents.match("^*<Incarnation number=\"\\d*\" instance=\"(.*)\" guid=\"{[-0-9a-fA-F]+}\"[\\s]*/>")[1]
      
      generate_instance_id(service_name, vm_name)
    end
    
    ##
    # Attach a disk to the Vm
    #
    # @param [String] instance_id Instance id
    # @param [String] disk_name disk name
    # @return [String] volume name. "/dev/sd[c-r]"
    def attach_disk(instance_id, disk_name)
      logger.debug("attach_disk(#{instance_id}, #{disk_name})")
      vm = find(instance_id) || cloud_error('Given instance id does not exist')

      cloud_service_name, vm_name = parse_instance_id(instance_id)

      next_disk_lun = vm.data_disks.size
      options = {
          :import => true,
          :disk_name => disk_name,
          :host_caching => 'ReadOnly',
          :disk_label => 'bosh',
          :lun => next_disk_lun
      }
      @azure_vm_service.add_data_disk(vm_name, cloud_service_name, options)

      disks_size = next_disk_lun
      until disks_size > next_disk_lun do
        sleep(5)
        vm = find(instance_id)
        disks_size = vm.data_disks.size
      end

      get_volume_name(instance_id, disk_name)
    end
    
    def detach_disk(instance_id, disk_name)
      logger.debug("detach_disk(#{instance_id}, #{disk_name})")
      vm = find(instance_id) || cloud_error('Given instance id does not exist')
      
      cloud_service_name, vm_name = parse_instance_id(instance_id)
      
      data_disk = vm.data_disks.find { |disk| disk[:name] == disk_name}
      data_disk || cloud_error('Given disk name is not attached to given instance id')
      
      lun = get_disk_lun(data_disk)
      max_retry = 10

      begin
        retry_interval = 0
        handle_response http_delete("services/hostedservices/#{cloud_service_name}/deployments/#{vm.deployment_name}/"\
                             "roles/#{vm_name}/DataDisks/#{lun}")
      rescue => e
        if e.message.include?("ConflictError")
          retry_interval = 6
          max_retry -= 1
        elsif e.message.include?("TooManyRequests")
          retry_interval = 15
          max_retry -= 1
        end

        if retry_interval != 0 && max_retry > 0
          sleep(retry_interval)
          logger.info("retry to delete(#{instance_id})")
          retry
        end
        logger.warn("delete(#{instance_id}): #{e.message}\n#{e.backtrace.join("\n")}")
      end

      current_disks_size = vm.data_disks.size
      disks_size = current_disks_size
      until disks_size < current_disks_size do
        sleep(5)
        vm = find(instance_id)
        disks_size = vm.data_disks.size
      end
    end
    
    def get_disks(instance_id)
      logger.debug("get_disks(#{instance_id})")
      vm = find(instance_id) || cloud_error('Given instance id does not exist')
      
      data_disks = []
      vm.data_disks.each do |disk|
        data_disks << disk[:name]
      end
      
      data_disks
    end
    
    private
    
    def get_user_data(vm_name, dns)
      user_data = {registry: {endpoint: @registry.endpoint}}
      user_data[:server] = {name: vm_name}
      user_data[:dns] = {nameserver: dns} if dns

      Base64.strict_encode64(Yajl::Encoder.encode(user_data))
    end
    
    def get_volume_name(instance_id, disk_name)
      vm = find(instance_id) || cloud_error('Given instance id does not exist')
      
      data_disk = vm.data_disks.find { |disk| disk[:name] == disk_name}
      data_disk || cloud_error('Given disk name is not attached to given instance id')
      
      lun = get_disk_lun(data_disk)
      
      "/dev/sd#{('c'.ord + lun).chr}"
    end
    
    def get_disk_lun(data_disk)
      data_disk[:lun] != "" ? data_disk[:lun].to_i : 0
    end
  end
end
