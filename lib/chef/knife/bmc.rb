module BmcPlugins

  require 'bmc-sdk'
  require 'json'

  class BmcSshkeyList < Chef::Knife
    banner "knife bmc sshkey list"

    def run
      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red 
        exit
      end

      begin
        list = Bmc::Sdk::GetSSHKeys.new(client)
        result = list.execute
        ui.output JSON.parse(result.body).map { |o| {'id' => o['id'], 'name' => o['name']} } unless config[:verbosity] && config[:verbosity] > 0 
        ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0 
      rescue Exception => e
        ui.error e
        err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
        ui.error ui.color err.message, :red
      end
    end
  end

  class BmcSshkeyCreate < Chef::Knife
    banner "knife bmc sshkey create (OPTIONS) KEYFILE"

    option :name,
      :short => "-n NAME",
      :long => "--name NAME",
      :description => "The name used to identify the SSH key in later use"

    option :default,
      :long => "--default",
      :boolean => true,
      :default => false 

    def run
      unless name_args.size == 1
        ui.error ui.color "You must specify an SSH public key file name.", :red
        show_usage
        exit
      end

      unless config[:name] && config[:name].length > 0
        ui.error ui.color "You must specify a --name for the new SSH key.", :red
        show_usage
        exit
      end

      begin 
        keyfile = File.open(name_args.first)
        keydata = keyfile.read.chomp
      rescue Exception => e
        ui.fatal "Unable to read the SSH key file: #{e}"
        show_usage
        exit
      ensure
        keyfile && keyfile.close
      end

      keyspec = Bmc::Sdk::SSHKeySpec.new(nil , config[:default], config[:name], keydata, nil, nil, nil)

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      begin
        create = Bmc::Sdk::CreateSSHKey.new(client, keyspec)
        result = create.execute
        ui.output [JSON.parse(result.body)].map { |o| {'id' => o['id'], 'name' => o['name']} }  unless config[:verbosity] && config[:verbosity] > 0 
        ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0 
      rescue Exception => e
        err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
        ui.error ui.color err.message, :red
      end
    end
  end

  class BmcSshkeyDelete < Chef::Knife
    banner "knife bmc sshkey delete (OPTIONS)"
    def run

      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one SSH key ID to delete.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          rm = Bmc::Sdk::DeleteSSHKey.new(client, id)
          result = rm.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to delete: #{id} -> #{err.message}", :red
        end
      end
    end
  end

  class BmcServerList < Chef::Knife
    banner "knife bmc server list (OPTIONS)"

    def run

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      begin
        list = Bmc::Sdk::GetServers.new(client)
        result = list.execute
        ui.output JSON.parse(result.body).map { |o| {'id' => o['id'], 'name' => o['hostname']} }  unless config[:verbosity] && config[:verbosity] > 0 
        ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0 
      rescue Exception => e
        err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
        ui.error ui.color err.message, :red
      end
    end
  end

  class BmcServerCreate < Chef::Knife
    banner "knife bmc server create (OPTIONS) HOSTNAME"

    DEFAULT_SSH_PORT = 22
    DEFAULT_SSH_PROBE_INTERVAL_SECONDS = 15
    DEFAULT_SSH_MAX_WAIT_SECONDS = 300
    DEFAULT_SSH_CONNECT_PAUSE_SECONDS = 60

    deps do
      require 'chef/knife/bootstrap'
      Chef::Knife::Bootstrap.load_deps
    end

    # BMC Options
    option :description,
      :long => "--description DESCRIPTION",
      :description => "A description of the instance purpose",
      :default => ""
    option :os,
      :short => "-i BMC_OS_IMAGE",
      :long => "--os BMC_OS_IMAGE",
      :description => "Set the OS image"
    option :type,
      :short => "-t BMC_TYPE",
      :long => "--os BMC_TYPE",
      :description => "Set the instance type"
    option :location,
      :short => "-l LOCATION",
      :long => "--location LOCATION",
      :description => "The instance data center",
      :default => "PHX"
    option :sshKeyIds,
      :long => "--sshKeyIds SSH_KEY_IDS",
      :description => "The SSH keys to grant access to this machine (comma separated list)",
      :proc => Proc.new { |sshKeyIds| sshKeyIds.split(',') },
      :default => []
    option :no_bootstrap,
      :long => "--no-bootstrap",
      :boolean => false | true,
      :proc => Proc.new { |no_bootstrap| !no_bootstrap },
      :default => false 

    # Bootstrap Options 
    option :chef_node_name,
      :short => "-N NAME",
      :long => "--node-name NAME",
      :description => "The Chef node name for the new node. If not specified, hostname will be used"
    option :ssh_user,
      :short => "-x USER",
      :long => "--ssh-user USER",
      :description => "The SSH username to use during bootstrapping. Defaults to root."
    option :ssh_identity_file,
      :short => "-X FILE",
      :long => "--ssh-identity-file FILE",
      :description => "The SSH identity file to use during authentication. Must correspond to a SSH key specified at creation."
    option :run_list,
      :short => "-r RUN_LIST",
      :long => "--run-list RUN_LIST",
      :description => "A comma-separated list of roles or recipies to be applied.",
      :proc => Proc.new { |l| l.split(',') },
      :default => []

    def run
      $stdout.sync = true
      unless name_args.size == 1
        ui.error ui.color "You must specify at lease one HOSTNAME.", :red
        show_usage
        exit
      end

      unless config[:no_bootstrap] || config[:ssh_user]
        ui.error ui.color "You must specify an ssh-user for bootstrapping.", :red
        show_usage
        exit
      end

      unless config[:no_bootstrap] || config[:ssh_identity_file]
        ui.error ui.color "You must specify an ssh-identity-file for bootstrapping.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      serverSpec = Bmc::Sdk::ProvisionedServer.new(
        nil, nil, 
        nil, 
        config[:description],
        config[:os],
        config[:type],
        config[:location],
        nil,
        config[:sshKeyIds],
      )

      name_args.each do|hostname|
        working = serverSpec.dup
        working.hostname = hostname
        details = {}
        begin
          create = Bmc::Sdk::CreateServer.new(client, working)
          result = create.execute
          
          details = JSON.parse(result.body)
          ui.output [details].map { |o| {'id' => o['id']} } unless config[:verbosity] && config[:verbosity] > 0
          ui.output details unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color err.message, :red
          next
        end

        next if config[:no_bootstrap] || !details['publicIpAddresses'] || details['publicIpAddresses'].length <= 0
        ui.msg "Bootstrapping #{hostname} at #{details['publicIpAddresses'].first}"
        config[:chef_node_name] = hostname unless config[:chef_node_name]

        # wait for 'poweron'
        ui.info "Waiting for machine powered-on..."
        next unless wait_for_poweron(client, details['id'])
        ui.info "Powered-On"

        # wait for ssh
        ui.info "Waiting for SSH availability..."
        next unless wait_for_ssh(details['publicIpAddresses'].first)
        ui.info "SSH Up"

        # wait for ready
        ui.info "Pausing for system preparation..."
        sleep DEFAULT_SSH_CONNECT_PAUSE_SECONDS

        # do bootstrap
        ui.info "Bootstrapping..."
        bootstrap = Chef::Knife::Bootstrap.new
        bootstrap.name_args = [details['publicIpAddresses'].first] # needs to be an IP address of the machine
        bootstrap.config[:chef_node_name] = config[:chef_node_name]
        bootstrap.config[:ssh_user] = config[:ssh_user]
        bootstrap.config[:ssh_identity_file] = config[:ssh_identity_file]
        bootstrap.config[:run_list] = config[:run_list]
        bootstrap.config[:ssh_verify_host_key] = :accept_new
        bootstrap.config[:use_sudo] = true
        bootstrap.config[:yes] = config[:yes]
        bootstrap.run
        ui.msg "Created and bootstraped Chef node '#{config[:chef_node_name]}'"
      end

    end

    def wait_for_poweron(client, id)
      stop_at = Time.now + DEFAULT_SSH_MAX_WAIT_SECONDS
      while Time.now < stop_at
        return true if is_poweron(client, id)
        drip
        sleep DEFAULT_SSH_PROBE_INTERVAL_SECONDS
      end
      ui.warn ui.color "Server failed to power on before timeout expired.", :yellow
      return false
    rescue Exception => e
      err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
      ui.error ui.color "Unable to fetch server details: #{err.message}", :red
      return false
    end

    def is_poweron(client, id)
      get = Bmc::Sdk::GetServer.new(client, id)
      result = get.execute
      return result.parsed['status'] && result.parsed['status'] == "powered-on"
    rescue Exception => e
      raise e
    end

    def wait_for_ssh(ip)
      stop_at = Time.now + DEFAULT_SSH_MAX_WAIT_SECONDS
      while Time.now < stop_at
        return true if is_ssh_reachable(ip)
        drip
        sleep DEFAULT_SSH_PROBE_INTERVAL_SECONDS
      end
      ui.warn ui.color "Server was not reachable for SSH before timeout expired.", :yellow
      return false
    end

    def is_ssh_reachable(ip)
      socket = TCPSocket.new(ip, DEFAULT_SSH_PORT)
      ready = IO.select([socket], nil, nil, DEFAULT_SSH_PROBE_INTERVAL_SECONDS)
      if ready
        data = socket.gets
        return true unless data.nil? || data.empty?
      else
        return false
      end
    rescue SocketError, IOError, Errno::ETIMEDOUT, Errno::EPERM, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ECONNRESET, Errno::ENOTCONN
      return false
    ensure
      socket && socket.close
    end

    def drip
      print ui.color '.', :cyan 
      $stdout.flush
    end
  end

  class BmcServerGet < Chef::Knife
    banner "knife bmc server get (OPTIONS) SERVER_LIST"

    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to retrieve.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          get = Bmc::Sdk::GetServer.new(client, id)
          result = get.execute
          ui.output JSON.parse(result.body)
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to get: #{id} -> #{err.message}", :red
        end
      end
    end
  end

  class BmcServerDelete < Chef::Knife
    banner "knife bmc server delete (OPTIONS) SERVER_LIST"

    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to delete.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          rm = Bmc::Sdk::DeleteServer.new(client, id)
          result = rm.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to delete: #{id} -> #{err.message}", :red
        end
      end
    end
  end

 class BmcServerReboot < Chef::Knife
    banner "knife bmc server reboot (OPTIONS) SERVER_LIST"
    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to reboot.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          reboot = Bmc::Sdk::Reboot.new(client, id)
          result = reboot.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to reboot: #{id} -> #{err.message}", :red
        end
      end
    end
  end

  class BmcServerShutdown < Chef::Knife
    banner "knife bmc server shutdown (OPTIONS) SERVER_LIST"
    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to shutdown.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          shut = Bmc::Sdk::Shutdown.new(client, id)
          result = shut.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to shutdown: #{id} -> #{err.message}", :red
        end
      end
    end
  end

  class BmcServerPoweron < Chef::Knife
    banner "knife bmc server poweron (OPTIONS) SERVER_LIST"
    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to power on.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          poweron = Bmc::Sdk::PowerOn.new(client, id)
          result = poweron.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to power on: #{id} -> #{err.message}", :red
        end
      end
    end
  end

  class BmcServerPoweroff < Chef::Knife
    banner "knife bmc server poweroff (OPTIONS) SERVER_LIST"
    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to power off.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      name_args.each do|id|
        begin
          poweroff = Bmc::Sdk::PowerOff.new(client, id)
          result = poweroff.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to power off: #{id} -> #{err.message}", :red
        end
      end

    end
  end

  class BmcServerReset < Chef::Knife
    banner "knife bmc server reset (OPTIONS) SERVER_ID_LIST"

    option :sshKeyIds,
      :long => "--sshKeyIds SSH_KEY_IDS",
      :description => "The SSH keys to grant access to this machine (comma separated list)",
      :proc => Proc.new { |sshKeyIds| sshKeyIds.split(',') },
      :default => []

    option :installDefaultSshKeys,
      :long => "--installDefaultKeys",
      :boolean => true,
      :default => false 

    def run
      unless name_args.size >= 1
        ui.error ui.color "You must specify at least one service ID to rekey.", :red
        show_usage
        exit
      end

      begin
        client = Bmc::Sdk::load_client
      rescue Exception => e
        ui.fatal ui.color e, :red
        exit
      end

      resetspec = Bmc::Sdk::ServerResetSpec.new(nil, nil, config[:sshKeyIds], config[:installDefaultSshKeys])

      name_args.each do|id|
        working = resetspec.dup
        working.id = id
        begin
          rekey = Bmc::Sdk::Reset.new(client, working)
          result = rekey.execute
          ui.info id unless config[:verbosity] && config[:verbosity] > 0 
          ui.output JSON.parse(result.body) unless config[:verbosity] && config[:verbosity] == 0
        rescue Exception => e
          err = Bmc::Sdk::ErrorMessage.new(e.response.parsed['message'], e.response.parsed['validationErrors'])
          ui.error ui.color "Failed to reset: #{id} -> #{err.message}", :red
        end
      end
    end
  end

end
