module Bosh::AzureCloud
  class VMManager
    attr_accessor :logger

    include Helpers

    def initialize(storage_manager, registry, disk_manager)
      @storage_manager = storage_manager
      @registry = registry
      @disk_manager = disk_manager
      @logger = Bosh::Clouds::Config.logger
    end
    
    def invoke_auzre_js(args,logger,abort_on_error=true)
      node_js_file = File.join(File.dirname(__FILE__),"azure_op.js") 
      cmd = "node #{node_js_file} ".split(" ")
      cmd.concat(args)
      result  = {};
      Open3.popen3(*cmd) {
      |stdin, stdout, stderr, wait_thr|
   
            data = ""
            stdstr=""
            begin
                while wait_thr.alive? do
                    IO.select([stdout]) 
                    data = stdout.read_nonblock(1024000)
                    logger.info(data)
                    stdstr+=data;
                end
                rescue Errno::EAGAIN
                retry
                rescue EOFError
            end

            errstr = stderr.read;
            stdstr+=stdout.read
            if errstr
                logger.warn(errstr);
            end
            matchdata = stdstr.match(/##RESULTBEGIN##(.*)##RESULTEND##/im)
            result = JSON(matchdata.captures[0]) if  matchdata
            exitcode = wait_thr.value 
            logger.debug(result)
            #cloud_error("command execute failed ,abort :"+args) if exitcode==1 and abort_on_error
            return nil if result["Failed"];
            return result["R"] 
      }
    end

    def create(uuid, stemcell, cloud_opts, network_configurator, resource_pool)
       raise Bosh::Clouds::CloudError, "resource_group_name required for deployment"  if cloud_opts["resource_group_name"]==nil
       instanceid = "bosh-#{cloud_opts["resource_group_name"]}-#{uuid}"
       imageUri = "https://#{@storage_manager.get_storage_account_name}.blob.core.windows.net/stemcell/#{stemcell}"
       sshKeyData = File.read(cloud_opts['ssh_certificate_file'])
       params = {
          :vmName             => instanceid,
          :nicName             => instanceid,
          :adminUserName       => cloud_opts['ssh_user'],
          :imageUri           => imageUri,
          :location           => cloud_opts['location'],
          :vmSize => resource_pool['instance_type'],
          :storageAccountName => @storage_manager.get_storage_account_name,
          :customData => get_user_data(instanceid, network_configurator.dns),
          :sshKeyData => sshKeyData
      }
        params[:virtualNetworkName] = network_configurator.virtual_network_name
        params[:subnetName]          = network_configurator.subnet_name

      unless network_configurator.private_ip.nil?
          params[:privateIPAddress] = network_configurator.private_ip
          params[:privateIPAddressType] = "Static"
      end
 
      args = "-t deploy -r #{cloud_opts['resource_group_name']}".split(" ")      
      args.push(File.join(File.dirname(__FILE__),"bosh_deploy_vm.json"))
      args.push(Base64.encode64(params.to_json()))
      result = invoke_auzre_js(args,logger)
      network_property = network_configurator.network.spec["cloud_properties"] 
      if !network_configurator.vip_network.nil? and result
           ipname = invoke_auzre_js("-r #{cloud_opts['resource_group_name']} -t findResource properties:ipAddress  #{network_configurator.reserved_ip} Microsoft.Network/publicIPAddresses".split(" "),logger)[0]
           
         p = {"StorageAccountName"=> @storage_manager.get_storage_account_name,
              "lbName"=> network_property['load_balance_name']?network_property['load_balance_name']:instanceid,
              "publicIPAddressName"=>ipname,
              "nicName"=>instanceid,
              "virtualNetworkName"=>"vnet",
              "TcpEndPoints"=> network_configurator.tcp_endpoints,
              "UdpEndPoints"=>network_configurator.udp_endpoints
            }
          p = p.merge(params)
          args = "-t deploy -r #{cloud_opts["resource_group_name"]}  ".split(" ")      
          args.push(File.join(File.dirname(__FILE__),"bosh_create_endpoints.json"))
          args.push(Base64.encode64(p.to_json()))
          result = invoke_auzre_js(args,logger)
      end
      if not result
        invoke_auzre_js("-t delete -r #{cloud_opts["resource_group_name"]} #{instanceid} Microsoft.Network/loadBalancers".split(" "),logger)
        invoke_auzre_js("-t delete -r #{cloud_opts["resource_group_name"]} #{instanceid} Microsoft.Compute/virtualMachines".split(" "),logger)
        invoke_auzre_js("-t delete -r #{cloud_opts["resource_group_name"]} #{instanceid} Microsoft.Network/networkInterfaces".split(" "),logger)
        cloud_error("create vm failed")        
      end 

      return {:cloud_service_name=>instanceid,:vm_name=>instanceid} if result
      
    end

    def invoke_auzre_js_with_id(arg,logger)
        task =arg[0]
        id = arg[1]
        logger.info("invoke azure js "+task)
        begin
           #(__bosh-qingfu3-bm-0458d6c4-6534-4724-81f1-d71e50df778fService&_bosh-qingfu3-bm-0458d6c4-6534-4724-81f1-d71e50df778f
            resource_group_name = id.split('&')[0][7..-48]
            puts("resource_group_name is" +resource_group_name)
            return invoke_auzre_js(["-t",task,"-r",resource_group_name,id.split('&')[1][1..-1]].concat(arg[2..-1]),logger)
        rescue Exception => ex
            puts("error:"+ex.message+ex.backtrace.join("\n"))
        end
    end
    
    def find(instance_id)
       return JSON(invoke_auzre_js_with_id(["getvm",instance_id],logger)[0])
    end

    def delete(instance_id)
       shutdown(instance_id)
       invoke_auzre_js_with_id(["delete",instance_id,"Microsoft.Compute/virtualMachines"],logger)[0]
       invoke_auzre_js_with_id(["delete",instance_id,"Microsoft.Network/loadBalancers"],logger)[0]
       invoke_auzre_js_with_id(["delete",instance_id,"Microsoft.Network/networkInterfaces"],logger)[0]
    end

    def reboot(instance_id)
        invoke_auzre_js_with_id(["reboot",instance_id],logger)[0]
    end

    def start(instance_id)
        invoke_auzre_js_with_id(["start",instance_id],logger)[0]
    end

    def shutdown(instance_id)
         invoke_auzre_js_with_id(["stop",instance_id],logger)[0]
    end
    def set_tag(instance_id,tag)
         tagStr = ""
         tag.each do |i| tagStr<<"#{i[0]}=#{i[1]};" end    
         tagStr = tagStr[0..-2]
         invoke_auzre_js_with_id(["setTag",instance_id,"Microsoft.Compute/virtualMachines",tagStr],logger)[0]
    end
    def instance_id(wala_lib_path)
      contents = File.open(wala_lib_path + "/SharedConfig.xml", "r"){ |file| file.read }
      vm_name = contents.match("^*<Incarnation number=\"\\d*\" instance=\"(.*)\" guid=\"{[-0-9a-fA-F]+}\"[\\s]*/>")[1]
      generate_instance_id(vm_name)
    end
    
    ##
    # Attach a disk to the Vm
    #
    # @param [String] instance_id Instance id
    # @param [String] disk_name disk name
    # @return [String] volume name. "/dev/sd[c-r]"
    def attach_disk(instance_id, disk_name)
       disk_uri="https://"+@storage_manager.get_storage_account_name()+".blob.core.windows.net/bosh/"+disk_name+".vhd"
       invoke_auzre_js_with_id(["adddisk",instance_id,disk_uri],logger)
       get_volume_name(instance_id, disk_uri)
    end
    
    def detach_disk(instance_id, disk_name)
        disk_uri="https://"+@storage_manager.get_storage_account_name()+".blob.core.windows.net/bosh/"+disk_name+".vhd"
        invoke_auzre_js_with_id(["rmdisk",instance_id,disk_uri],logger)
    end
    
    private

    def get_user_data(vm_name, dns)
      user_data = {registry: {endpoint: @registry.endpoint}}
      user_data[:server] = {name: vm_name}
      user_data[:dns] = {nameserver: dns} if dns
      Base64.strict_encode64(Yajl::Encoder.encode(user_data))
    end
    
    def get_volume_name(instance_id, disk_name)
      vm_property = invoke_auzre_js_with_id(["getvm",instance_id],logger)[0]
      vm_property = JSON(vm_property)
      data_disk = vm_property["properties"]["storageProfile"]["dataDisks"].find { |disk| disk["vhd"]["uri"] == disk_name}
      data_disk || cloud_error('Given disk name is not attached to given instance id')
      lun = get_disk_lun(data_disk)
      logger.info("get_volume_name return lun #{lun}")
      "/dev/sd#{('c'.ord + lun).chr}"
    end
    
    def get_disk_lun(data_disk)
      data_disk["lun"] != "" ? data_disk["lun"].to_i : 0
    end
    
  end
end

