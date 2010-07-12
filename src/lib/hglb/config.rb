require 'yaml'
require 'hglb'
require 'hglb/configchecker'

module HGLB

  class ConfigError < HGLB::Error; end
  class ConsistencyError < HGLB::ConfigError; end

  class Config

    def initialize(configfile, check_consistency_p=false)
      @configfile = configfile
      @config     = YAML.load_file(configfile)
      check_consistency if check_consistency_p
    end

    def backends
      @config[:backends].keys
    end

    def backend(backendname)
      @config[:backends][backendname]
    end

    def backend_ip(backendname)
      host_ip(@config[:backends][backendname][:host])
    end

    def backend_host(backendname)
      @config[:backends][backendname][:host]
    end

    def backend_port(backendname)
      @config[:backends][backendname][:port]
    end

    def backend_netstatform(backendname)
      "#{backend_ip(backendname)}.#{backend_port(backendname)}"
    end

    def backend_host?(backendname, hostname)
      @config[:backends][backendname][:host] == hostname
    end

    def hosts
      @config[:hosts]
    end

    def host(hostname)
      @config[:hosts][hostname]
    end

    def host_ip(hostname)
      @config[:hosts][hostname][:ip]
    end

    def lb_hostname(lbname)
      @config[:loadbalancers][lbname][:hostname]
    end

    def lb_user(lbname)
      @config[:loadbalancers][lbname][:user]
    end

    def lb_key(lbname)
      @config[:loadbalancers][lbname][:key]
    end

    def clusters
      @config[:clusters].keys
    end

    def cluster_ips(clustername)
      @config[:clusters][clustername][:ips]
    end

    def cluster_template(clustername)
      @config[:clusters][clustername][:template]
    end

    def cluster_adminport(clustername)
      @config[:clusters][clustername][:adminport]
    end

    def loadbalancers
      @config[:loadbalancers].keys
    end

    def loadbalancer(lbname)
      @config[:loadbalancers][lbname]
    end

    def cluster_loadbalancers(clustername)
      cluster_ips(clustername).map do |ip|
        ip_loadbalancers(ip)
      end.flatten.uniq
    end

    def cluster_directors(clustername)
      @config[:clusters][clustername][:directors]
    end

    def cluster_backends(clustername)
      cluster_directors(clustername).map do |directorname|
        director_backends(directorname)
      end.flatten.uniq
    end

    def ip_loadbalancers(ip)
      loadbalancers.select { |lb| loadbalancer(lb)[:ips].include?(ip) }
    end

    def directors
      @config[:directors].keys
    end

    def director(directorname)
      @config[:directors][directorname]
    end

    def director_backends(directorname)
      @config[:directors][directorname]
    end

    def director_backend?(directorname, backendname)
      @config[:directors][directorname].include?(backendname)
    end

    def ip_host(ip)
      @config[:hosts].index({ :ip => ip})
    end

    def hostport_backend(host, port)
      needle = { :host => host, :port => port }
      @config[:backends].index(needle)
    end

    def ipport_backend(ip, port)
      hostport_backend(ip_host(ip), port)
    end

    def check_consistency(dont_raise=false)
      checker = ConfigChecker.new(@config)
      errors = checker.check
      unless errors.empty?
        raise ConsistencyError.new("\n  " + errors.join("\n  "))
      end
    end

  end

end

# Modeline
# vim:ts=2:et:ai:sw=2
