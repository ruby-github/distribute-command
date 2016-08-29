module DistributeCommand
  class Command
    attr_reader :doc, :sequence

    def initialize file, args = nil
      @doc = nil
      @sequence = load file, args

      @inner = false

      if not @sequence.nil?
        @inner = @sequence.element.attributes['inner'].to_s.boolean false
      end
    end

    def exec
      status = nil

      $distributecommand = []
      $distributecommand_errors = []

      time = Time.now

      if not @sequence.nil?
        status = @sequence.exec
      end

      if not @inner
        Util::Logger::summary $distributecommand, ((Time.now - time) * 1000).to_i / 1000.0

        if not $distributecommand_errors.empty?
          Util::Logger::info nil
          Util::Logger::summary_error $distributecommand_errors
        end
      end

      status
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
        doc.expand args

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
        args = {
          :__element__  => element
        }

        element.attributes.each do |name, value|
          args[name] = value
        end

        Template::__send__(element.name, args) || []
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
  end
end