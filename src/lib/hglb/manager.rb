require 'hglb/config'
require 'hglb/state'
require 'hglb/ssh'
require 'md5'

module HGLB

  class Manager

    LOCKFILE = "/var/lib/lbadmin/state.lock"

    def initialize(configfile, statefile="/var/lib/lbadmin/state.yaml")
      @config = HGLB::Config.new(configfile)
      @config.check_consistency
      @state  = HGLB::State.new(@config)
      @ssh    = HGLB::SshManager.new(@config)
      @ssh.connect_to_all_servers
    end

    def lock_state
      return false if File.exists?(LOCKFILE)
      File.open(LOCKFILE, "w") { |f| f.write(Process.pid) }
      pid = File.read(LOCKFILE).strip.to_i
      return false if pid != Process.pid
      return true
    end

    def unlock_state
      if File.exists?(LOCKFILE)
        return false if File.read(LOCKFILE).strip.to_i != Process.pid
      end
      File.unlink(LOCKFILE)
      return true
    end

    def commit
      @state.commit
    end

    def check_backend_connection_counts(clustername, opts = {})
      ret = {}

      loadbalancers = @config.cluster_loadbalancers(clustername)
      unless opts[:loadbalancers].nil? or opts[:loadbalancers].empty?
        loadbalancers = loadbalancers.select { |lb| opts[:loadbalancers].include?(lb) }
      end

      targets = @config.cluster_backends(clustername)
      unless opts[:backends].nil? or opts[:backends].empty?
        targets = targets.select { |be| opts[:backends].include?(be) }
      end
      unless opts[:hosts].nil? or opts[:hosts].empty?
        targets = targets.select do |be|
          opts[:hosts].any? { |h| @config.backend_host?(be, h) }
        end
      end
      unless opts[:directors].nil? or opts[:directors].empty?
        targets = targets.select do |be|
          opts[:directors].any? { |d| @config.director_backend?(d, be) }
        end
      end
      canon_targets = targets.map do |be|
        @config.backend_netstatform(be)
      end

      loadbalancers.each do |lb|
        results = {}
        canon_targets.each { |target| results[target] = 0 }

        netstat = @ssh.cmd(lb, "netstat -anW")
        conns = netstat.split("\n").select { |line| line =~ /^tcp4.*ESTABLISHED$/ }.map do |conn|
          linesplit = conn.split
          {:laddr => linesplit[3], :faddr => linesplit[4]}
        end.each do |conn|
          if canon_targets.include?(conn[:faddr])
            results[conn[:faddr]] += 1
          end
        end

        ret[lb] = {}
        canon_targets.each do |canon_target|
          backend = @config.ipport_backend(canon_target.split(".")[0..3].join("."),
                                           canon_target.split(".")[4].to_i)
          ret[lb][backend] = results[canon_target]
        end
        ret[lb][:total] = results.values.inject(0) { |a,b| a+b }
      end
      ret[:total] = ret.values.map { |r| r[:total] }.inject(0) { |a,b| a+b }

      ret
    end

    def cluster?(clustername)
      @config.clusters.include?(clustername)
    end

    def backend?(backendname)
      @config.backends.include?(backendname)
    end

    def backends_status(opts)
      @state.backends_status(opts)
    end

    def suspend_backend(backendname)
      @state.suspend_backend(backendname)
    end

    def resume_backend(backendname)
      @state.resume_backend(backendname)
    end

    def update_cluster(clustername, opts = {})
      @state.generate_config(clustername, opts)
    end

    def vclfilepath(clustername, vclname)
      "/u01/lb/#{clustername}/#{vclname}.vcl"
    end

    def sync_cluster_config(clustername, vclconfig)
      vclname = MD5.hexdigest(vclconfig)
      @config.loadbalancers.each do |lbname|
        if not @ssh.file_up_to_date?(lbname, vclfilepath(clustername, vclname), vclconfig)
          @ssh.upload(lbname, vclfilepath(clustername, vclname), vclconfig)
        end
      end
    end

    def reload_cluster_config(clustername, vclconfig)
      vclname = MD5.hexdigest(vclconfig)
      fullpath = vclfilepath(clustername, vclname)
      adminport = @config.cluster_adminport(clustername)

      @config.loadbalancers.each do |lbname|
        begin
          @ssh.load_vcl(lbname, adminport, fullpath) unless @ssh.vcl_loaded?(lbname, adminport, fullpath)
          @ssh.set_vcl(lbname, adminport, fullpath) unless @ssh.vcl_in_use?(lbname, adminport, fullpath)
        rescue VCLError => e
          puts "VCL Error on #{clustername}:\n  #{e}"
        end
      end
    end

    def sync
      @config.clusters.each do |clustername|
        vclconfig = update_cluster(clustername)
        sync_cluster_config(clustername, vclconfig)
        reload_cluster_config(clustername, vclconfig)
      end
    end

  end

end

# Modeline
# vim:ts=2:et:ai:sw=2
