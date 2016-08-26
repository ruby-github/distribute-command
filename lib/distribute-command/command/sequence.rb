module DistributeCommand
  class CommandBase
    attr_reader :desc, :ip, :element

    @@lock = Monitor.new

    def initialize element, ip = nil
      @desc = nil
      @ip = nil

      @element = expand element, ip
    end

    def command_valid?
      ['copy', 'delete', 'mkdir', 'cmdline', 'function'].include? @element.name
    end

    def to_string
      @element.to_string
    end

    private

    def expand element, ip
      ip = ip.to_s.nil

      if ip.to_s == '127.0.0.1'
        ip = nil
      end

      if element.attributes.has_key? 'ip'
        ip = element.attributes['ip'].to_s.nil

        if ip.to_s == '127.0.0.1'
          ip = nil
        end

        if ip.nil?
          element.attributes.delete 'ip'
        end
      else
        if not ip.nil?
          element.attributes['ip'] = ip
        end
      end

      @ip = ip

      if @ip.nil?
        @desc = element.attributes['name'].to_s.nil
      else
        @desc = '%s - %s' % [element.attributes['name'].to_s.nil, ip]
      end

      element
    end

    def distributecommand status, time
      @@lock.synchronize do
        $distributecommand << [@desc, status, ((Time.now - time) * 1000).to_i / 1000.0]

        if not $errors.nil?
          $distributecommand_errors << [@desc, $errors.uniq]

          $errors = nil
        end
      end
    end

    def ensure?
      @element.attributes['ensure'].to_s.boolean false
    end

    def skip?
      skip = @element.attributes['skip'].to_s.nil
      home = @element.attributes['home'].to_s.nil
      ip = @element.attributes['ip'].to_s.nil

      if not skip.nil? and not home.nil?
        file = File.join home, 'create.id'

        if ip.nil?
          if File.file? file
            skip == IO.read(file).to_s.nil.utf8
          else
            false
          end
        else
          string = nil

          drb = DRb::Object.new

          if drb.connect ip
            string = drb.file file
          end

          drb.close

          skip == string.to_s.nil.utf8
        end
      else
        false
      end
    end

    def skiped
      skip = @element.attributes['skip'].to_s.nil
      home = @element.attributes['home'].to_s.nil
      ip = @element.attributes['ip'].to_s.nil

      if not skip.nil? and not home.nil?
        file = File.join home, 'create.id'

        if ip.nil?
          File.open file, 'w' do |f|
            f << skip.to_s.locale
          end
        else
          drb = DRb::Object.new

          if drb.connect ip
            drb.file file do |string|
              skip.to_s.locale
            end
          end

          drb.close
        end
      end
    end

    def skipfail
      @element.attributes['skipfail'].to_s.boolean false
    end

    def attributes
      hash = {}

      @element.attributes.each do |name, value|
        hash[name] = value.to_s.nil
      end

      hash
    end
  end

  class Sequence < CommandBase
    attr_reader :sequences

    def initialize element, ip = nil
      super element, ip

      @sequences = []

      @element.each_element do |element|
        case element.name
        when 'sequence'
          @sequences << Sequence.new(element, @ip)
        when 'list_sequence'
          @sequences << ListSequence.new(element, @ip)
        when 'parallel'
          @sequences << Parallel.new(element, @ip)
        else
          command = CommandAction.new element, @ip

          if command.command_valid?
            @sequences << command
          end
        end
      end
    end

    def exec skip = false
      if ensure?
        skip = false
      end

      if skip?
        skip = true
      end

      if skip
        distributecommand nil, Time.now

        true
      else
        status = true

        @sequences.each do |sequence|
          if not sequence.exec skip
            skip = true
            status = false
          end
        end

        if skipfail
          status = true
        end

        if status
          skiped
        end

        status
      end
    end

    def to_string
      lines = []

      lines << 'sequence:'

      @sequences.each do |sequence|
        sequence.to_string.each_line do |line|
          lines << INDENT + line.rstrip
        end

        lines << ''
      end

      lines.join("\n").rstrip
    end
  end

  class ListSequence < Sequence
    def exec skip = false
      if ensure?
        skip = false
      end

      if skip?
        skip = true
      end

      if skip
        distributecommand nil, Time.now

        true
      else
        status = true

        @sequences.each do |sequence|
          if not sequence.exec skip
            status = false
          end
        end

        if skipfail
          status = true
        end

        if status
          skiped
        end

        status
      end
    end

    def to_string
      lines = []

      lines << 'list_sequence:'

      @sequences.each do |sequence|
        sequence.to_string.each_line do |line|
          lines << INDENT + line.rstrip
        end

        lines << ''
      end

      lines.join("\n").rstrip
    end
  end

  class Parallel < Sequence
    def exec skip = false
      if ensure?
        skip = false
      end

      if skip?
        skip = true
      end

      if skip
        distributecommand nil, Time.now

        true
      else
        status = true

        tmpdir = File.tmpname

        threads = []

        @sequences.each_with_index do |sequence, index|
          command_file = File.join tmpdir, index.to_s, 'command.xml'

          doc = REXML::Document.new '<sequence/>'
          doc.root << sequence.element
          doc.to_file command_file

          cmdline = 'ruby -e "distributecommand(\'%s\', \'%s\')"' % [command_file, File.dirname(command_file)]
          cmdline += ' -r "distribute-command"'

          threads << Thread.new do
            if not CommandLine::cmdline cmdline, cmdline: false do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              status = false
            end
          end
        end

        threads.each do |thread|
          thread.join
        end

        threads.each do |thread|
          if not thread.value
            status = false
          end
        end

        @sequences.each_with_index do |sequence, index|
          info = YAML::load_tmpfile 'distributecommand', tmpdir

          if not info.nil?
            if info.kind_of? Hash
              $distributecommand += info['distributecommand'] || []
              $distributecommand_errors += info['distributecommand_errors'] || []
            end
          end
        end

        if skipfail
          status = true
        end

        if status
          skiped
        end

        status
      end
    end

    def to_string
      lines = []

      lines << 'parallel:'

      @sequences.each do |sequence|
        sequence.to_string.each_line do |line|
          lines << INDENT + line.rstrip
        end

        lines << ''
      end

      lines.join("\n").rstrip
    end
  end

  class CommandAction < CommandBase
    def exec skip = false
      if ensure?
        skip = false
      end

      if skip?
        skip = true
      end

      if skip
        distributecommand nil, Time.now

        true
      else
        status = true

        $errors = nil

        time = Time.now

        Util::Logger::head 'Execute %s' % @desc

        begin
          case @element.name.to_s.nil
          when 'copy'
            status = command_copy
          when 'delete'
            status = command_delete
          when 'mkdir'
            status = command_mkdir
          when 'cmdline'
            status = command_cmdline
          when 'function'
            status = command_function
          else
          end
        rescue
          Util::Logger::exception $!

          status = false
        end

        $errors = nil

        if skipfail
          status = true
        end

        if status
          skiped
        end

        distributecommand status, time

        status
      end
    end

    def to_string
      lines = []

      lines << 'name  : %s' % @element.name.to_s.nil
      lines << 'args  :'

      attributes.to_string.each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines.join "\n"
    end

    private

    def command_copy
      args = attributes

      if not args['path'].nil? and not args['to_path'].nil?
        status = true

        if @ip.nil?
          if not File.copy args['path'], args['to_path'] do |src, dest|
              Util::Logger::puts src

              [src, dest]
            end

            status = false
          end

          if not args['callback'].nil?
            if callback_valid? args['callback']
              if not DistributeCommand::Callback::__send__ args['callback'], args do |line|
                  Logger::puts line
                end

                status = false
              end
            else
              Util::Logger::error 'No found callback @ command_copy - DistributeCommand::Callback::%s' % args['callback']

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect @ip
            if not drb.copy args['path'], args['to_path'] do |src, dest|
                if dest.nil?
                  Util::Logger::exception src
                else
                  Util::Logger::puts src
                end

                [src, dest]
              end

              status = false
            end

            if not args['callback'].nil?
              if callback_valid? args['callback']
                if not drb.callback args['callback'], args do |line|
                    Util::Logger::puts line
                  end

                  status = false
                end
              else
                Util::Logger::error 'No found callback @ command_copy - DistributeCommand::Callback::%s' % args['callback']

                status = false
              end
            end

            if not drb.errors.nil?
              $errors ||= []
              $errors += drb.errors
            end
          else
            status = false
          end

          drb.close
        end

        status
      else
        Util::Logger::error 'No found parameter @ command_copy - path or to_path'

        false
      end
    end

    def command_delete
      args = attributes

      if not args['path'].nil?
        status = true

        if @ip.nil?
          if not File.delete args['path'] do |path|
              Util::Logger::puts path

              path
            end

            status = false
          end

          if not args['callback'].nil?
            if callback_valid? args['callback']
              if not DistributeCommand::Callback::__send__ args['callback'], args do |line|
                  Logger::puts line
                end

                status = false
              end
            else
              Util::Logger::error 'No found callback @ command_delete - DistributeCommand::Callback::%s' % args['callback']

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect @ip
            if not drb.delete args['path'] do |path|
                Util::Logger::puts path

                path
              end

              status = false
            end

            if not args['callback'].nil?
              if callback_valid? args['callback']
                if not drb.callback args['callback'], args do |line|
                    Util::Logger::puts line
                  end

                  status = false
                end
              else
                Util::Logger::error 'No found callback @ command_delete - DistributeCommand::Callback::%s' % args['callback']

                status = false
              end
            end

            if not drb.errors.nil?
              $errors ||= []
              $errors += drb.errors
            end
          else
            status = false
          end

          drb.close
        end

        status
      else
        Util::Logger::error 'No found parameter @ command_delete - path'

        false
      end
    end

    def command_mkdir
      args = attributes

      if not args['path'].nil?
        status = true

        if @ip.nil?
          if not File.mkdir args['path'] do |path|
              Util::Logger::puts path

              path
            end

            status = false
          end

          if not args['callback'].nil?
            if callback_valid? args['callback']
              if not DistributeCommand::Callback::__send__ args['callback'], args do |line|
                  Logger::puts line
                end

                status = false
              end
            else
              Util::Logger::error 'No found callback @ command_mkdir - DistributeCommand::Callback::%s' % args['callback']

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect @ip
            if not drb.mkdir args['path'] do |path|
                Util::Logger::puts path

                path
              end

              status = false
            end

            if not args['callback'].nil?
              if callback_valid? args['callback']
                if not drb.callback args['callback'], args do |line|
                    Util::Logger::puts line
                  end

                  status = false
                end
              else
                Util::Logger::error 'No found callback @ command_mkdir - DistributeCommand::Callback::%s' % args['callback']

                status = false
              end
            end

            if not drb.errors.nil?
              $errors ||= []
              $errors += drb.errors
            end
          else
            status = false
          end

          drb.close
        end

        status
      else
        Util::Logger::error 'No found parameter @ command_mkdir - path'

        false
      end
    end

    def command_cmdline
      args = attributes

      if not args['cmdline'].nil?
        status = true

        if @ip.nil?
          callback = args['callback']

          if not callback.nil?
            if not callback_valid? callback
              Util::Logger::error 'No found callback @ command_cmdline - DistributeCommand::Callback::%s' % callback

              callback = nil
              status = false
            end
          end

          lines = []

          if not CommandLine::cmdline args['cmdline'], args do |line, stdin, wait_thr|
              Util::Logger::puts line

              lines << line

              if not callback.nil?
                if not DistributeCommand::Callback::__send__ callback, args.merge({'line' => line}) do |line|
                    Util::Logger::puts line
                  end

                  status = false
                end
              end
            end

            status = false
          end

          if not args['callback_finish'].nil?
            if callback_valid? args['callback_finish']
              if not DistributeCommand::Callback::__send__ args['callback_finish'], args.merge({'lines' => lines}) do |line|
                  Logger::puts line
                end

                status = false
              end
            else
              Util::Logger::error 'No found callback_finish @ command_cmdline - DistributeCommand::Callback::%s' % args['callback_finish']

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect @ip
            callback = args['callback']

            if not callback.nil?
              if not callback_valid? callback
                Util::Logger::error 'No found callback @ command_cmdline - DistributeCommand::Callback::%s' % callback

                callback = nil
                status = false
              end
            end

            lines = []

            if not drb.cmdline args['cmdline'], args do |line, stdin, wait_thr|
                Util::Logger::puts line

                lines << line

                if not callback.nil?
                  if not drb.callback callback, args.merge({'line' => line}) do |line|
                      Util::Logger::puts line
                    end

                    status = false
                  end
                end
              end

              status = false
            end

            if not args['callback_finish'].nil?
              if callback_valid? args['callback_finish']
                if not drb.callback args['callback_finish'], args.merge({'lines' => lines}) do |line|
                    Logger::puts line
                  end

                  status = false
                end
              else
                Util::Logger::error 'No found callback_finish @ command_cmdline - DistributeCommand::Callback::%s' % args['callback_finish']

                status = false
              end
            end

            if not drb.errors.nil?
              $errors ||= []
              $errors += drb.errors
            end
          else
            status = false
          end

          drb.close
        end

        status
      else
        Util::Logger::error 'No found parameter @ command_cmdline - cmdline'

        false
      end
    end

    def command_function
      args = attributes

      if not args['function'].nil?
        status = true

        if @ip.nil?
          if not DistributeCommand::Function::__send__ args['function'], args do |line|
              Util::Logger::puts line
            end

            status = false
          end

          if not args['callback'].nil?
            if callback_valid? args['callback']
              if not DistributeCommand::Callback::__send__ args['callback'], args do |line|
                  Logger::puts line
                end

                status = false
              end
            else
              Util::Logger::error 'No found callback @ command_function - DistributeCommand::Callback::%s' % args['callback']

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect @ip
            if not drb.function args['function'], args do |line|
                Util::Logger::puts line
              end

              status = false
            end

            if not args['callback'].nil?
              if callback_valid? args['callback']
                if not drb.callback args['callback'], args do |line|
                    Util::Logger::puts line
                  end

                  status = false
                end
              else
                Util::Logger::error 'No found callback @ command_function - DistributeCommand::Callback::%s' % args['callback']

                status = false
              end
            end

            if not drb.errors.nil?
              $errors ||= []
              $errors += drb.errors
            end
          else
            status = false
          end

          drb.close
        end

        status
      else
        Util::Logger::error 'No found parameter @ command_function - function'

        false
      end
    end

    def callback_valid? callback, sleep = true
      if sleep
        Kernel::sleep 1
      end

      DistributeCommand::Callback::respond_to? callback
    end

    def function_valid? function
      DistributeCommand::Function::respond_to? function
    end
  end
end
