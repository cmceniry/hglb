
require 'net/ssh'
require 'net/sftp'

module HGLB

  class SshError < HGLB::Error; end
  class AlreadyConnectedError < HGLB::SshError; end
  class ConnectionError < HGLB::SshError; end

  class VCLError < HGLB::SshError; end
  class VCLLoadError < HGLB::VCLError; end
  class VCLStatusError < HGLB::VCLError; end

  class SshManager

    VARNISHADM = "/usr/local/bin/varnishadm"

    def initialize(config)
      @config      = config
      @connections = {}   
      @cmdcache    = {}
    end

    def connect(lbname)
      @connections[lbname] = Net::SSH.start(@config.lb_hostname(lbname),
                                            @config.lb_user(lbname),
                                            :auth_methods => ["publickey"],
                                            :keys => [@config.lb_key(lbname)])
    end

    def connect_to_all_servers
      @config.loadbalancers.each { |lb| connect(lb) }
    end

    def cmd(lbname, command, nocache=false)
      cachekey = "#{lbname}::#{command}"
      if not nocache or                                   # no cache flag
         not @cmdcache.key?(cachekey) or                  # no key found
         (@cmdcache[cachekey][:last] < Time.now.to_i - 2) # cache too old
        result = @connections[lbname].exec!(command)
        @cmdcache[cachekey] = {
          :last   => Time.now.to_i,
          :result => result,
        }
      else
        result = @cmdcache[cachekey] = :result
      end
      result
    end

    def file_up_to_date?(lbname, filepath, contents)
      ret = false
      @connections[lbname].sftp.connect do |sftp|
        begin
          sftp.lstat!(filepath)
          ret = sftp.download!(filepath) == contents
          ret &&= File.basename(sftp.readlink!(File.dirname(filepath) + "/main.vcl").name, ".vcl") == 
                  File.basename(filepath, ".vcl")
        rescue Net::SFTP::StatusException => e
          ret = false
        end
      end
      ret
    end

    def upload(lbname, filepath, contents)
      @connections[lbname].sftp.connect do |sftp|
        begin
          sftp.file.open(filepath, "w") do |f|
            f.write(contents)
          end
          begin
            sftp.remove!(File.dirname(filepath) + "/main.vcl")
          rescue Net::SFTP::StatusException
          end
          sftp.symlink(File.basename(filepath),
                       File.dirname(filepath) + "/main.vcl")
        rescue Net::SFTP::StatusException => e
          puts "Error processing #{lbname}:#{filepath}"
          raise
        end
      end
    end

    def vcl_status(lbname, adminport, vclname)
      cmdbase = "#{VARNISHADM} -T localhost:#{adminport}"

      result = cmd(lbname, "#{cmdbase} vcl.list")
      result.strip.split("\n").each do |line|
        next if line == ""
        lsplit = line.split
        if lsplit[2] == vclname
          case lsplit[0]
          when "available"
            return :loaded
          when "active"
            return :active
          else
            raise VCLStatusError.new("Unknown status(#{lsplit[0]}) for #{vclname} on #{lbname}")
          end
        end
      end
      return :notfound
    end

    def vcl_loaded?(lbname, adminport, filepath)
      case vcl_status(lbname, adminport, File.basename(filepath, ".vcl"))
      when :loaded, :active
        true
      else
        false
      end
    end

    def vcl_in_use?(lbname, adminport, filepath)
      case vcl_status(lbname, adminport, File.basename(filepath, ".vcl"))
      when :active
        true
      else
        false
      end
    end

    def load_vcl(lbname, adminport, filepath)
      cmdbase = "#{VARNISHADM} -T localhost:#{adminport}"
      vclname = File.basename filepath, ".vcl"

      cmdstr = "#{cmdbase} vcl.load #{vclname} #{filepath}"
      result = cmd(lbname, cmdstr)
      if result.strip != "VCL compiled."
        raise VCLLoadError.new("Error loading #{vclname} on #{lbname}:\n  #{cmdstr}\n  #{prettyresult(result)}")
      end
    end

    def set_vcl(lbname, adminport, filepath)
      cmdbase = "#{VARNISHADM} -T localhost:#{adminport}"
      vclname = File.basename filepath, ".vcl"

      cmdstr = "#{cmdbase} vcl.use #{vclname}"
      result = cmd(lbname, cmdstr)
      if result.strip != ""
        raise VCLLoadError.new("Error activating #{vclname} on #{lbname}:\n  #{cmdstr}\n  #{prettyresult(result)}")
      end
    end

    def prettyresult(str)
      str.strip.gsub("\n", "\n  ")
    end

  end

end

# Modeline
# vim:ts=2:et:ai:sw=2
