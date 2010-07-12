require 'yaml'
require 'tempfile'
require 'hglb/vcltemplate'

module HGLB

  class State

    def initialize(config, statefile="/var/lib/lbadmin/state.yaml")
      @config = config
      @statefile = statefile
      load_statefile
      ensure_keys
    end

    def load_statefile
      begin
        @state = YAML.load_file(@statefile)
      rescue Errno::ENOENT
      end
    end

    def save_statefile
      tmpfile = Tempfile.new(File.basename(@statefile), File.dirname(@statefile))
      tmpfile.write(YAML.dump(@state))
      tmpfile.chmod(0644)
      tmpfile.close
      File.rename(tmpfile.path, @statefile)
    end

    def ensure_keys
      @state ||= {}
      @state[:backends] ||= {}
    end

    def commit
      save_statefile
    end

    ######################################################
    # Backend manipulation
    ######################################################
    def backends_status(opts = {})
      ret = {}

      backends = @config.backends

      unless opts[:backends].nil? or opts[:backends].empty?
        backends = backends.select do |backendname|
          opts[:backends].include?(backendname)
        end
      end

      backends.each do |backendname|
        if @state[:backends].key?(backendname)
          ret[backendname] = @state[:backends][backendname]
        else
          ret[backendname] = :unknown
        end
      end

      ret
    end

    def backend_enabled?(backendname)
      (not @state[:backends].key?(backendname)) or (@state[:backends][backendname] == :enabled)
    end

    def resume_backend(backendname)
      if @config.backends.include?(backendname)
        @state[:backends][backendname] = :enabled
      end
    end

    def suspend_backend(backendname)
      if @config.backends.include?(backendname)
        @state[:backends][backendname] = :disabled
      end
    end

    ######################################################
    # Director manipulation
    ######################################################
    def director_enabled?(directorname)
      true
    end

    ######################################################
    # Configs
    ######################################################
    def generate_config(clustername, opts = {})
      configtemplate = HGLB::VCLTemplate.new(@config, self, clustername)
      configtemplate.generate_config
    end

  end

end

# Modeline
# vim:ts=2:et:ai:sw=2
