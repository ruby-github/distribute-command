module DistributeCommand
  class Command
    attr_reader :doc, :sequence

    def initialize
      @doc = nil
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

      @doc = nil
      @sequence = nil

      begin
        doc = REXML::Document.file file
      rescue
        Util::Logger::exception $!

        return false
      end

      @doc = REXML::Document.new
      @doc.add_element expand_template(doc.root)
      @doc.expand

      #@sequence = Sequence.new
      #@sequence.load @doc.root, args

      true
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

    private

    def expand_template element
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
              expand_template(e).to_array.each_with_index do |child_element, index|
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