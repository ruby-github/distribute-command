module DistributeCommand
  class Command
    attr_reader :doc, :sequence

    def initialize file, args = nil
      @doc = nil
      @sequence = load file, args
    end

    def exec
      status = nil

      $distributecommand = []
      $distributecommand_errors = []

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

    def reboot
      ip_list = ips

      if not ip_list.nil?
        if not ip_list.empty?
          windows_ips = []
          unix_ips    = []

          ip_list.each do |ip|
            drb = DRb::Object.new

            begin
              if drb.connect ip
                if drb.osname == 'windows'
                  windows_ips << ip
                else
                  unix_ips << ip
                end
              end
            rescue
              begin
                Net::SSH::start ip, 'user', :password => 'user' do |ssh|
                end

                unix_ips << ip
              rescue
                windows_ips << ip
              end
            end
          end

          OS::remote_reboot windows_ips
          OS::remote_reboot unix_ips, 'admin-cgs', false

          sleep 120
        end
      end
    end

    def reboot_drb
      ip_list = ips

      if not ip_list.nil?
        if not ip_list.empty?
          OS::remote_reboot_drb ip_list

          sleep 30
        end
      end
    end

    private

    def load file, args = nil
      args ||= {
        'date'              => Time.now.strftime('%Y-%m-%d'),
        'date_string'       => Time.now.strftime('%Y%m%d'),
        'yesterday'         => (Time.now - 3600 * 24).strftime('%Y-%m-%d'),
        'yesterday_string'  => (Time.now - 3600 * 24).strftime('%Y%m%d'),
        'version'           => ENV['VERSION'].utf8
      }

      args['version'] ||= 'daily_main_%s' % args['date_string']

      begin
        doc = REXML::Document.file file

        @doc = REXML::Document.new
        @doc.add_element expand(doc.root)
        @doc.expand args

        Sequence.new @doc.root
      rescue
        Util::Logger::exception $!

        nil
      end
    end

    def expand element
      if Template::respond_to? element.name
        args = {}

        element.attributes.each do |name, value|
          args[name] = value
        end

        Template::__send__ element.name, args
      else
        if element.has_elements?
          new_element = REXML::Element.new element.name
          new_element.add_attributes element.attributes

          element.each do |e|
            if e.kind_of? REXML::Element
              expand(e).to_array.each_with_index do |child_element, index|
                if index > 0
                  new_element.add_text "\n\n"
                end

                new_element << child_element
              end
            else
              if e.kind_of? REXML::Text
                new_element.add_text e.value
              else
                new_element.add e
              end
            end
          end

          new_element
        else
          element
        end
      end
    end

    def ips
      if not @doc.nil?
        ips = []

        REXML::XPath.each @doc, '//@ip' do |attribute|
          ip = attribute.value.nil

          if not ip.nil?
            if not ['127.0.0.1'].include? ip
              ips << ip
            end
          end
        end

        ips.sort!
        ips.uniq!

        ips
      else
        nil
      end
    end
  end
end