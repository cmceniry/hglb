require 'ipaddr'

module HGLB

  class ConfigChecker

    def initialize( confighash )
      @config = confighash

      @state = {
        :frontips      => [],
        :backips       => [],
        :hosts         => [],
        :backends      => [],
        :directors     => [],
        :loadbalancers => [],
      }
    end

    def check
      errors = []
      errors += check_hosts
      errors += check_backends
      errors += check_directors
      errors += check_loadbalancers
      errors += check_clusters
      errors
    end

    def check_attribute(attribute, hash, error_prefix)
      if hash.key?(attribute)
        errors = yield []
        errors.map { |err| "#{error_prefix} #{err}" }
      else
        ["#{error_prefix} missing :#{attribute}"]
      end
    end

    #################################################################
    # Hosts
    #################################################################
    def check_hosts
      errors = []
      
      if @config.key?(:hosts)
        if @config[:hosts].class == Hash
          @config[:hosts].each_pair do |hostname, hostinfo|
            @state[:hosts] << hostname unless @state[:hosts].include?(hostname)
            begin
              errors += check_host_ip(hostname, hostinfo)
            rescue StandardError => e
              errors << "Host #{hostname} error: #{e}"
            end
          end
        else
          errors << "Invalid format for :hosts stanza - must be a hash"
        end
      else
        errors << "No hosts defined"
      end
      errors
    end

    def check_host_ip(hostname, hostinfo)
      check_attribute(:ip, hostinfo, "Host #{hostname}") do |errors|
        begin
          IPAddr.new(hostinfo[:ip])
          @state[:backips] << hostinfo[:ip] unless @state[:backips].include?(hostinfo[:ip])
        rescue ArgumentError => e
          errors << "#{hostinfo[:ip]} is invalid: #{e}"
        end
        errors
      end
    end

    #################################################################
    # Backends
    #################################################################
    def check_backends
      errors = []

      if @config.key?(:backends)
        if @config[:backends].class == Hash
          @config[:backends].each_pair do |backendname, backendinfo|
            @state[:backends] << backendname unless @state[:backends].include?(backendname)
            begin
              errors += check_backend_host(backendname, backendinfo)
              errors += check_backend_port(backendname, backendinfo)
              errors += check_backend_options(backendname, backendinfo)
            rescue StandardError => e
              errors << "Backend #{backendname} error: #{e}"
            end
          end
        else
          errors << "Invalid format for :backends stanza - must be a hash"
        end
      else
        error << "No backends defined"
      end
      errors
    end

    def check_loadbalancer_hostname(lbname, lb)
      check_attribute(:hostname, lb, "Loadbalancer #{lbname}") do |errors|
        # no formal checking here, so []
        errors
      end
    end

    def check_backend_host(backendname, backendinfo)
      check_attribute(:host, backendinfo, "Backend #{backendname}") do |errors|
        unless @state[:hosts].include?(backendinfo[:host])
          errors << "unknown host #{backendinfo[:host]}"
        end
        errors
      end
    end

    def check_backend_port(backendname, backendinfo)
      check_attribute(:port, backendinfo, "Backend #{backendname}") do |errors|
        # no formal checking here, so []
        errors
      end
    end

    def check_backend_options(backendname, backinfo)
      # options are not required or validated (could cause varnish issue)
      []
    end

    #################################################################
    # Directors
    #################################################################
    def check_directors
      errors = []

      if @config.key?(:directors)
        if @config[:directors].class == Hash
          @config[:directors].each_pair do |directorname, backends|
            @state[:directors] << directorname unless @state[:directors].include?(directorname)
            begin
              errors += check_director_backends(directorname, backends)
            rescue StandardError => e
              errors << "Director #{directorname} error: #{e}"
            end
          end
        else
          errors << "Invalid format for :directors stanza - must be a hash"
        end
      else
        errors << "No directors defined"
      end
      errors
    end

    def check_director_backends(directorname, backends)
      errors = []
      if backends.class == Array
        backends.each do |backend|
          unless @state[:backends].include?(backend)
            errors << "Director #{directorname} unknown backend #{backend}"
          end
        end
      else
        errors << "Director #{directorname} Invalid format - must be an array of backends"
      end
      errors
    end

    #################################################################
    # Load balancers
    #################################################################
    def check_loadbalancers
      errors = []

      if @config.key?(:loadbalancers)
        if @config[:loadbalancers].class == Hash
          @config[:loadbalancers].each_pair do |lbname, lb|
            @state[:loadbalancers] << lbname unless @state[:loadbalancers].include?(lbname)
            begin
              errors += check_loadbalancer_hostname(lbname, lb)
              errors += check_loadbalancer_user(lbname, lb)
              errors += check_loadbalancer_key(lbname, lb)
              errors += check_loadbalancer_ips(lbname, lb)
            rescue StandardError => e
              errors << "Loadbalancer #{lbname}: #{e}"
            end
          end
        else
          errors << "Invalid format for :loadbalancers stanza - must be a hash"
        end
      else
        errors << "No loadbalancers defined"
      end
      errors
    end

    def check_loadbalancer_hostname(lbname, lb)
      check_attribute(:hostname, lb, "Loadbalancer #{lbname}") do |errors|
        # no formal checking here, so []
        errors
      end
    end

    def check_loadbalancer_user(lbname, lb)
      check_attribute(:user, lb, "Loadbalancer #{lbname}") do |errors|
        # no formal checking here, so []
        errors
      end
    end

    def check_loadbalancer_key(lbname, lb)
      check_attribute(:key, lb, "Loadbalancer #{lbname}") do |errors|
        unless File.readable?(lb[:key])
          errors << "#{lb[:key]} not readable"
        end
        errors
      end
    end

    def check_loadbalancer_ips(lbname, lb)
      check_attribute(:ips, lb, "Loadbalancer #{lbname}") do |errors|
        if lb[:ips].class == Array
          unless lb[:ips].empty?
            lb[:ips].each do |ip|
              begin
                IPAddr.new(ip)
                @state[:frontips] << ip unless @state[:frontips].include?(ip)
              rescue ArguementError => e
                errors << "#{ip} is invalid: #{e}"
              end
            end
          else
            errors << ":ips is empty"
          end
        else
          errors << ":ips not an array"
        end
        errors
      end
    end

    #################################################################
    # Clusters
    #################################################################
    def check_clusters
      errors = []

      if @config.key?(:clusters)
        if @config[:clusters].class == Hash
          @config[:clusters].each_pair do |clustername, clusterinfo|
            begin
              errors += check_cluster_ips(clustername, clusterinfo)
              errors += check_cluster_adminport(clustername, clusterinfo)
              errors += check_cluster_loadbalancers(clustername, clusterinfo)
              #errors += check_cluster_loadbalancerip_combo(clustername, clusterinfo)
              errors += check_cluster_ports(clustername, clusterinfo)
              #errors += check_cluster_ipport_combo(clustername, clusterinfo)
              errors += check_cluster_directors(clustername, clusterinfo)
              errors += check_cluster_template(clustername, clusterinfo)
            rescue StandardError => e
              errors << "Cluster #{clustername}: #{e}"
            end
          end
        else
          errors << "Invalid format for :clusters stanza - must be a hash"
        end
      else
        errors << "No clusters defined"
      end
      errors
    end

    def check_cluster_ips(clustername, clusterinfo)
      check_attribute(:ips, clusterinfo, "Cluster #{clustername}") do |errors|
        if clusterinfo[:ips].class == Array
          clusterinfo[:ips].each do |ip|
            begin
              IPAddr.new(ip)
              unless @state[:frontips].include?(ip)
                errors << "#{ip} is unknown - does not appear on any load balancers"
              end
            rescue ArgumentError => e
              errors << "ip #{ip} is invalid: #{e}"
            end
          end
        else
          errors << "Invalid format for :ips stanza - must be an array"
        end
        errors
      end
    end

    def check_cluster_adminport(clustername, clusterinfo)
      check_attribute(:adminport, clusterinfo, "Cluster #{clustername}") do |errors|
        begin
          if clusterinfo[:adminport].to_i > 1
            if clusterinfo[:adminport].to_i < 65536
            else
              errors << "adminport #{clusterinfo[:adminport]} is invalid: greater than 65535"
            end
          else
            errors << "adminport #{clusterinfo[:adminport]} is invalid: less than 1"
          end
        rescue StandardError => e
          errors << "adminport #{clusterinfo[:adminport]} is invalid: #{e}"
        end
        errors
      end
    end

    def check_cluster_loadbalancers(clustername, clusterinfo)
      check_attribute(:loadbalancers, clusterinfo, "Cluster #{clustername}") do |errors|
        if clusterinfo[:loadbalancers].class == Array
          clusterinfo[:loadbalancers].each do |lbname|
            unless @state[:loadbalancers].include?(lbname)
              errors << "#{lbname} is unknown"
            end
          end
        else
          errors << "Invalid format(#{clusterinfo[:loadbalancers].class}) for :loadbalancers stanza - must be an array"
        end
        errors
      end
    end

    def check_cluster_ports(clustername, clusterinfo)
      check_attribute(:ports, clusterinfo, "Cluster #{clustername}") do |errors|
        if clusterinfo[:ports].class == Array
          clusterinfo[:ports].each do |port|
            begin
              if port.to_i > 1
                if port.to_i < 65536
                else
                  errors << "port #{port} is invalid: greater than 65535"
                end
              else
                errors << "port #{port} is invalid: less than 1"
              end
            rescue StandardError => e
              errors << "port #{port} is invalid: #{e}"
            end
          end
        else
          errors << "Invalid format for :ports stanza - must be an array"
        end
        errors
      end
    end

    def check_cluster_directors(clustername, clusterinfo)
      check_attribute(:directors, clusterinfo, "Cluster #{clustername}") do |errors|
        if clusterinfo[:directors].class == Array
          clusterinfo[:directors].each do |director|
            unless @state[:directors].include?(director)
              errors << "unknown director #{director}"
            end
          end
        else
          errors << "Invalid format for :directors stanza - must be an array"
        end
        errors
      end
    end

    def check_cluster_template(clustername, clusterinfo)
      check_attribute(:template, clusterinfo, "Cluster #{clustername}") do |errors|
        unless File.readable?(clusterinfo[:template])
          errors << "template #{clusterinfo[:template]} not readable"
        end
        errors
      end
    end

  end

end

# Modeline
# vim:ts=2:et:ai:sw=2
