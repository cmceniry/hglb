#!/usr/bin/ruby

$: << "./lib"

require 'rubygems'
require 'pp'
require 'getoptlong'
require 'hglb'

def lbstats_usage
  puts <<EOF
  Usage info:...
EOF
end

def lbstats
  if Process.euid != 0
    puts "Must be run as root"
    exit -2
  end

  config        = "/etc/hglb.yaml"
  verbose       = false
  loadbalancers = nil
  directors     = nil
  hosts         = nil
  backends      = nil

  opts = GetoptLong.new(
    [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--loadbalancers', '-n', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--directors', '-d', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--hosts', '-h', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--backends', '-b', GetoptLong::REQUIRED_ARGUMENT],
    [ '--verbose', '-v', GetoptLong::NO_ARGUMENT ],
    [ '--help', GetoptLong::NO_ARGUMENT ]
  )
  begin
    opts.each do |opt,arg|
      case opt
        when '--config'
          config = arg
        when '--loadbalancers'
          loadbalancers = arg.split(",")
        when '--directors'
          directors = arg.split(",")
        when '--hosts'
          hosts = arg.split(",")
        when '--backends'
          backends = arg.split(",")
        when '--verbose'
          verbose = true
        when '--help'
          lbstats_usage
          exit 0
     end
    end
  rescue GetoptLong::InvalidOption => e
    puts "Invalid usage: #{e}"
    exit -1
  end

  manager = HGLB::Manager.new(config)
  counts = manager.check_backend_connection_counts( ARGV[0],
                                                    :loadbalancers => loadbalancers,
                                                    :directors     => directors,
                                                    :hosts         => hosts,
                                                    :backends      => backends
  )
  if verbose
    counts.each_pair do |lb,results|
      if lb != :total
        puts "--#{lb} (#{results[:total]})"
        results.keys.reject { |b| b == :total } .sort.each do |backend|
          puts "  #{backend} : #{results[backend]}"
        end
      end
    end
  end
  puts counts[:total]

end

def lbstatus_usage
  puts <<EOF
  Usage info:...
EOF
end

def lbstatus
  if Process.euid != 0
    puts "Must be run as root"
    exit -2
  end

  config        = "/etc/hglb.yaml"
  verbose       = false
  loadbalancers = nil
  directors     = nil
  hosts         = nil
  backends      = nil

  opts = GetoptLong.new(
    [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--loadbalancers', '-n', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--directors', '-d', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--hosts', '-h', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--backends', '-b', GetoptLong::REQUIRED_ARGUMENT],
    [ '--verbose', '-v', GetoptLong::NO_ARGUMENT ],
    [ '--help', GetoptLong::NO_ARGUMENT ]
  )
  begin
    opts.each do |opt,arg|
      case opt
        when '--config'
          config = arg
        when '--loadbalancers'
          loadbalancers = arg.split(",")
          puts "--loadbalancers not in use"
          exit -1
        when '--directors'
          directors = arg.split(",")
          puts "--directors not in use"
          exit -1
        when '--hosts'
          hosts = arg.split(",")
        when '--backends'
          backends = arg.split(",")
        when '--verbose'
          verbose = true
        when '--help'
          lbstats_usage
          exit 0
     end
    end
  rescue GetoptLong::InvalidOption => e
    puts "Invalid usage: #{e}"
    exit -1
  end

  manager = HGLB::Manager.new(config)
  res = manager.backends_status(
                                :loadbalancers => loadbalancers,
                                :directors     => directors,
                                :hosts         => hosts,
                                :backends      => backends
  )
  res.keys.sort.each do |backendname|
    puts "#{backendname} : #{res[backendname]}"
  end
end

def lbsuspend_usage
  puts <<EOF
  Usage info:...
EOF
end

def lbsuspend
  if Process.euid != 0
    puts "Must be run as root"
    exit -2
  end

  config        = "/etc/hglb.yaml"

  opts = GetoptLong.new(
    [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--help', GetoptLong::NO_ARGUMENT ]
  )
  begin
    opts.each do |opt,arg|
      case opt
        when '--config'
          config = arg
        when '--help'
          lbsuspend_usage
          exit 0
     end
    end
  rescue GetoptLong::InvalidOption => e
    puts "Invalid usage: #{e}"
    exit -1
  end

  if ARGV.empty?
    puts "No backends specified"
    exit -1
  end

  manager = HGLB::Manager.new(config)
  error = false
  ARGV.each do |backendname|
    unless manager.backend?(backendname)
      puts "Unknown backend: #{backendname}"
      error = true
    end
  end
  exit -1 if error
  manager.lock_state
  at_exit do
    manager.unlock_state
  end
  ARGV.each do |backendname|
    manager.suspend_backend(backendname)
  end
  manager.commit
  manager.sync
end

def lbresume_usage
  puts <<EOF
  Usage info:...
EOF
end

def lbresume
  if Process.euid != 0
    puts "Must be run as root"
    exit -2
  end

  config        = "/etc/hglb.yaml"

  opts = GetoptLong.new(
    [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--help', GetoptLong::NO_ARGUMENT ]
  )
  begin
    opts.each do |opt,arg|
      case opt
        when '--config'
          config = arg
        when '--help'
          lbresume_usage
          exit 0
     end
    end
  rescue GetoptLong::InvalidOption => e
    puts "Invalid usage: #{e}"
    exit -1
  end

  if ARGV.empty?
    puts "No backends specified"
    exit -1
  end

  manager = HGLB::Manager.new(config)
  error = false
  ARGV.each do |backendname|
    unless manager.backend?(backendname)
      puts "Unknown backend: #{backendname}"
      error = true
    end
  end
  exit -1 if error
  manager.lock_state
  at_exit do
    manager.unlock_state
  end
  ARGV.each do |backendname|
    manager.resume_backend(backendname)
  end
  manager.commit
  manager.sync
end

def lbsync_usage
  puts <<EOF
  Usage info:...
EOF
end

def lbsync
  if Process.euid != 0
    puts "Must be run as root"
    exit -2
  end

  config        = "/etc/hglb.yaml"

  opts = GetoptLong.new(
    [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--help', GetoptLong::NO_ARGUMENT ]
  )
  begin
    opts.each do |opt,arg|
      case opt
        when '--config'
          config = arg
        when '--help'
          lbresume_usage
          exit 0
     end
    end
  rescue GetoptLong::InvalidOption => e
    puts "Invalid usage: #{e}"
    exit -1
  end

  manager = HGLB::Manager.new(config)
  manager.lock_state
  at_exit do
    manager.unlock_state
  end
  manager.sync
end

case File.basename($0)
when "lb-stats"
  lbstats
when "lb-status"
  lbstatus
when "lb-suspend"
  lbsuspend
when "lb-resume"
  lbresume
when "lb-sync"
  lbsync
else
  puts "Unknown command"
  exit -1
end

# Modeline
# vim:ts=2:et:ai:sw=2
