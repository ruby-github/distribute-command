require 'rake'

namespace :command do
  task :exec, [:home, :configure, :version] do |t, args|
    home = args[:home].to_s.nil || ($home || '.')
    configure = args[:configure].to_s.nil || 'configure.xml'
    version = args[:version].to_s.nil || $version

    if not version.nil?
      ENV['VERSION'] = version.to_s
    end

    status = true

    Dir.chdir home do
      cmd = DistributeCommand::Command.new

      if cmd.load configure
        cmd.ips true

        if not cmd.exec
          status = false
        end
      else
        status = false
      end
    end

    status.exit
  end

  task :puts, [:home, :configure, :version] do |t, args|
    home = args[:home].to_s.nil || ($home || '.')
    configure = args[:configure].to_s.nil || 'configure.xml'
    version = args[:version].to_s.nil || $version

    if not version.nil?
      ENV['VERSION'] = version.to_s
    end

    status = true

    Dir.chdir home do
      cmd = DistributeCommand::Command.new

      if cmd.load configure
        Util::Logger::puts cmd.sequence.to_string
      else
        status = false
      end
    end

    status.exit
  end
end