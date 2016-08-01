require 'net/telnet'

module Net
  class Telnet
    alias __initialize__ initialize

    def initialize options
      if not options.has_key? 'Prompt'
        if options['windows']
          options['Prompt'] = /C:.*>/
        end
      end

      __initialize__ options
    end

    def print string
      if @options['Telnetmode']
        string = string.gsub /#{IAC}/no, IAC + IAC
      end

      if @options['Binmode']
        self.write string
      else
        if @telnet_option['BINARY'] and @telnet_option['SGA']
          self.write string.gsub(/\n/n, CR)
        elsif @telnet_option['SGA']
          self.write string.gsub(/\n/n, EOL)
        else
          self.write string.gsub(/\n/n, EOL)
        end
      end
    end
  end
end