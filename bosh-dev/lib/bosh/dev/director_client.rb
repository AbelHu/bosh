require 'cli'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  class DirectorClient
    def initialize(options = {})
        @uri = options.fetch(:uri)
        @username = options.fetch(:username)
        @password = options.fetch(:password)
        @cli = BoshCliSession.new
        @director_handle = Bosh::Cli::Client::Director.new(uri, username, password)
    end

    def upload_stemcell(stemcell_archive)
      target_and_login!
      cli.run_bosh("upload stemcell #{stemcell_archive.path}", debug_on_fail: true)  unless has_stemcell?(stemcell_archive.name, stemcell_archive.version)
    end

    def upload_release(release_path)
      target_and_login!
      cli.run_bosh("upload release #{release_path} --rebase", debug_on_fail: true)
    rescue => e
      raise unless /Error 100: Rebase is attempted without any job or package changes/.match(e.message)
    end

    def deploy(manifest_path)
      target_and_login!
      cli.run_bosh("deployment #{manifest_path}")
      cli.run_bosh('deploy', debug_on_fail: true)
    end

    private

    attr_reader :uri, :username, :password, :cli, :director_handle

    def target_and_login!
      cli.run_bosh("target #{uri}")
      cli.run_bosh("login #{username} #{password}")
    end

    def has_stemcell?(name, version)
      director_handle.list_stemcells.any? do |stemcell|
        stemcell['name'] == name && stemcell['version'] == version
      end
    end
  end
end
