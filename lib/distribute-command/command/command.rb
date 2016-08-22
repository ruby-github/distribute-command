module DistributeCommand
  class Command
    attr_reader :sequence

    def initialize
      @sequence = nil
    end

    def load file, args = nil
      if args.nil?
        args = {
          'date'              => Time.now.strftime('%Y-%m-%d'),
          'date_string'       => Time.now.strftime('%Y%m%d'),
          'yesterday'         => (Time.now - 3600 * 24).strftime('%Y-%m-%d'),
          'yesterday_string'  => (Time.now - 3600 * 24).strftime('%Y%m%d'),
          'version'           => nil
        }

        args['version'] = ENV['VERSION'].utf8 || ('daily_main_%s' % args['date_string'])
      end

      begin
        doc = REXML::Document.file file

        @sequence = Sequence.new
        @sequence.load doc.root, args

        true
      rescue
        Util::Logger::exception $!

        @sequence = nil

        false
      end
    end

    def exec
      $distributecommand = []
      $distributecommand_errors = []

      status = true

      time = Time.now

      if not @sequence.nil?
        status = @sequence.exec
      end

      Util::Logger::summary $distributecommand, ((Time.now - time) * 1000).to_i / 1000.0

      if not $distributecommand_errors.empty?
        Util::Logger::info nil
        Util::Logger::summary_error $distributecommand_errors
      end

      status
    end

    def ips reboot_drb = false
      if not @sequence.nil?
        ips = @sequence.ips

        if not ips.nil?
          if reboot_drb
            OS::remote_reboot_drb ips

            sleep 30
          end
        end

        ips
      else
        nil
      end
    end
  end
end