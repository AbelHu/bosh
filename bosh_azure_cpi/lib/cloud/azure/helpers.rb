module Bosh::AzureCloud
  module Helpers

    def generate_instance_id(cloud_service_name, vm_name)
      instance_id = cloud_service_name + "&" + vm_name
    end

    def parse_instance_id(instance_id)
      cloud_service_name, vm_name = instance_id.split("&")
    end

    def symbolize_keys(hash)
      hash.inject({}) do |h, (key, value)|
        h[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
        h
      end
    end
    
    ##
    # Raises CloudError exception
    #
    # @param [String] message Message about what went wrong
    # @param [Exception] exception Exception to be logged (optional)
    def cloud_error(message, exception = nil)
      @logger.error(message) if @logger
      @logger.error(exception) if @logger && exception
      raise Bosh::Clouds::CloudError, message
    end
    
    def xml_content(xml, key, default = '')
      content = default
      node = xml.at_css(key)
      content = node.text if node
      content
    end

     def get_azure_storage(name,resource_group)
       return get_azure_resource(resource_group,name,"Microsoft.Storage/storageAccounts")
     end

    def get_azure_vm(name,resource_group)
       return get_azure_resource(resource_group,name,"Microsoft.Compute/virtualMachines")
    end

    def get_azure_publicip(name,resource_group)
       return get_azure_resource(resource_group,name,"Microsoft.Network/publicIPAddresses")
    end

     def get_azure_nic(name,resource_group)
        return get_azure_resource(resource_group,name,"Microsoft.Network/networkInterfaces")
     end


    def get_azure_resource(resource_group,name,type)
        resource_group = name[5..-41] if resource_group==nil || resource_group.length==0 
        ret_str = invoke_azure_js("-t get -r #{resource_group} #{name} #{type}".split(" "),logger)
        return JSON(ret_str) if ret_str
    end

    def azure_cmd(cmd,logger)
      logger.debug("execute command "+cmd)
      exit_status=0
      Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        exit_status= wait_thr.value
        logger.debug("stdout is:" + stdout.read)
        logger.debug("stderr is:" + stderr.read)
        logger.debug("exit_status is:"+String(exit_status))
        if exit_status!=0
          logger.error("execute command fail Please try it manually to see more details")
        end
      end
      return exit_status
    end

    def invoke_azure_js(args,logger,abort_on_error=true)
      node_js_file = File.join(File.dirname(__FILE__),"azure_crp","azure_crp_compute.js")
      cmd = "node #{node_js_file}".split(" ")
      cmd.concat(args)
      result  = {};
      node_path=ENV['NODE_PATH']
      node_path = "/usr/local/lib/node_modules" if not node_path or node_path.length==0
      
      Open3.popen3({'NODE_PATH' =>node_path},*cmd) {
      |stdin, stdout, stderr, wait_thr|

            data = ""
            stdstr=""
            begin
                while wait_thr.alive? do
                    IO.select([stdout])
                    data = stdout.read_nonblock(1024000)
                    logger.info(data)
                    stdstr+=data;
                    task_checkpoint
                end
                rescue Errno::EAGAIN
                retry
                rescue EOFError
            end

            errstr = stderr.read;
            stdstr+=stdout.read
            if errstr and errstr.length>0
                errstr="\n \t\tPlease check if env NODE_PATH is correct\r"+errstr if errstr=~/Function.Module._load/
                cloud_error(errstr);
                return nil
            end
            matchdata = stdstr.match(/##RESULTBEGIN##(.*)##RESULTEND##/im)
            result = JSON(matchdata.captures[0]) if  matchdata
            exitcode = wait_thr.value
            logger.debug(result)
            cloud_error("AuthorizationFailed please try azure login\n") if result["Failed"] and result["Failed"]["code"] =~/AuthorizationFailed/
            cloud_error("Can't find token in ~/.azure/azureProfile.json or ~/.azure/accessTokens.json\n 
                             Try azure login    \n") if result["Failed"] and result["Failed"]["code"] =~/RefreshToken Fail/

            return nil if result["Failed"];
            return result["R"] if result["R"][0] == nil
            return result["R"][0]
      }
    end

    def invoke_azure_js_with_id(arg,logger)
        task =arg[0]
        id = arg[1]
        logger.info("invoke azure js "+task+"id"+String(id))
        begin
           #bosh-qingfu3-bm-0458d6c4-6534-4724-81f1-d71e50df778f
            resource_group_name = id[5..-41]
            logger.debug("resource_group_name is" +resource_group_name)
            return invoke_azure_js(["-t",task,"-r",resource_group_name,id].concat(arg[2..-1]),logger)
        rescue Exception => ex
            puts("error:"+ex.message+ex.backtrace.join("\n"))
        end
    end



    private

    def validate(vm)
      (!vm.nil? && !nil_or_empty?(vm.vm_name) && !nil_or_empty?(vm.cloud_service_name))
    end

    def nil_or_empty?(obj)
      (obj.nil? || obj.empty?)
    end

    def handle_response(response)
      ret = wait_for_completion(response)
      Nokogiri::XML(ret.body) unless ret.nil?
    end
    
    def init_url(uri)
      "#{Azure.config.management_endpoint}/#{Azure.config.subscription_id}/#{uri}"
    end

    def http_get(uri)
      url = URI.parse(init_url(uri))
      request = Net::HTTP::Get.new(url.request_uri)
      request['x-ms-version'] = '2014-06-01'
      request['Content-Length'] = 0

      http(url).request(request)
    end

    def http_post(uri, body=nil)
      url = URI.parse(init_url(uri))
      request = Net::HTTP::Post.new(url.request_uri)
      request.body = body unless body.nil?
      request['x-ms-version'] = '2014-06-01'
      request['Content-Type'] = 'application/xml' unless body.nil?

      http(url).request(request)
    end

    def http_delete(uri, body=nil)
      url = URI.parse(init_url(uri))
      request = Net::HTTP::Delete.new(url.request_uri)
      request.body = body unless body.nil?
      request['x-ms-version'] = '2014-06-01'
      request['Content-Type'] = 'application/xml' unless body.nil?

      http(url).request(request)
    end

    def http(url)
      pem = File.read(Azure.config.management_certificate)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.cert = OpenSSL::X509::Certificate.new(pem)
      http.key = OpenSSL::PKey::RSA.new(pem)
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http
    end
    
    def wait_for_completion(response)
      ret_val = Nokogiri::XML response.body
      if ret_val.at_css('Error Code') && ret_val.at_css('Error Code').content == 'AuthenticationFailed'
        cloud_error(ret_val.at_css('Error Code').content + ' : ' + ret_val.at_css('Error Message').content)
      end
      if response.code.to_i == 200 || response.code.to_i == 201
        return response
      elsif response.code.to_i == 307
        #rebuild_request response
        cloud_error("Currently bosh_azure_cpi does not support proxy.")
      elsif response.code.to_i > 201 && response.code.to_i <= 299
        check_completion(response['x-ms-request-id'])
      elsif warn && !response.success?
      elsif response.body
        if ret_val.at_css('Error Code') && ret_val.at_css('Error Message')
          cloud_error(ret_val.at_css('Error Code').content + ' : ' + ret_val.at_css('Error Message').content)
        else
          cloud_error(nil, "http error: #{response.code}")
        end
      else
        cloud_error(nil, "http error: #{response.code}")
      end
    end
    
    def task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end

    def check_completion(request_id)
      request_path = "/operations/#{request_id}"
      done = false
      while not done
        print '# '
        response = http_get(request_path)
        ret_val = Nokogiri::XML response.body
        status = xml_content(ret_val, 'Operation Status')
        status_code = response.code.to_i
        if status != 'InProgress'
          done = true
        end
        if response.code.to_i == 307
          done = true
        end
        if done
          if status.downcase != 'succeeded'
            error_code = xml_content(ret_val, 'Operation Error Code')
            error_msg = xml_content(ret_val, 'Operation Error Message')
            cloud_error(nil, "#{error_code}: #{error_msg}")
          else
            puts "#{status.downcase} (#{status_code})"
          end
          return
        else
          sleep(5)
        end
      end
    end
  end
end
