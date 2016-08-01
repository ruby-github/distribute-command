require 'rake'

namespace :distribute_command do
  task :command, [:configure] do |t, args|
    configure = args[:configure].to_s.nil || 'configure.xml'

    cmd = DistributeCommand::Command.new
    cmd.load configure
    cmd.exec.exit
  end

  task :reboot, [:ips, :password, :windows] do |t, args|
    OS::remote_reboot(args[:ips].to_s.nil, args[:password], args[:windows]).exit
  end
end