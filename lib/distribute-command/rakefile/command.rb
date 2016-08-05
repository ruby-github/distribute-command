require 'rake'

namespace :command do
  task :exec, [:home, :ips, :version] do |t, args|
    home = args[:home].to_s.nil || ($home || '.')
    ips = (args[:ips].to_s.nil || $ips).to_s.gsub(';', ',').split(',').map {|x| x.strip}
    version = args[:version].to_s.nil || $version

    if not ips.empty?
      OS::remote_reboot_drb ips

      sleep 2 * 60
    end

    if not version.nil?
      ENV['VERSION'] = version.to_s
    end

    Dir.chdir home do
      cmd = DistributeCommand::Command.new
      cmd.load 'configure.xml'

      cmd.exec.exit
    end
  end

  task :puts, [:home, :version] do |t, args|
    home = args[:home].to_s.nil || ($home || '.')
    version = args[:version].to_s.nil || $version

    if not version.nil?
      ENV['VERSION'] = version.to_s
    end

    Dir.chdir home do
      cmd = DistributeCommand::Command.new
      cmd.load 'configure.xml'

      Util::Logger::puts cmd.sequence.to_string
    end

    true.exit
  end
end