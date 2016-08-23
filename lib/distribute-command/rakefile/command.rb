require 'rake'

namespace :command do
  task :exec, [:home, :configure, :version, :reboot] do |t, args|
    home = args[:home].to_s.nil || ($home || '.')
    configure = args[:configure].to_s.nil || 'configure.xml'
    version = args[:version].to_s.nil || $version
    reboot = args[:reboot].to_s.boolean false

    if not version.nil?
      ENV['VERSION'] = version.to_s
    end

    status = true

    Dir.chdir home do
      if not distributecommand configure do |command|
          if reboot
            command.reboot
          else
            command.reboot_drb
          end

          true
        end

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
      if not distributecommand configure do |command|
          command.sequence.to_string

          false
        end

        status = false
      end
    end

    status.exit
  end
end