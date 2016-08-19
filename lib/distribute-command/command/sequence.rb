module DistributeCommand
  class CommandBase
    attr_reader :args

    def initialize args = nil
      @args = args || {}
    end

    def command_valid? name
      ['copy', 'delete', 'mkdir', 'cmdline', 'function'].include? name
    end

    private

    def attributes element, opt = nil
      hash = opt.clone || {}

      args = @args.clone

      element.attributes.each do |k, v|
        @args[k] = v.to_s.strip.vars hash.merge(args)
      end

      if element.attributes.has_key? 'ip'
        @args['ip'] = element.attributes['ip'].to_s.nil
      end

      @args.each do |k, v|
        @args[k] = v.to_s.vars hash.merge(@args)
      end

      hash = hash.merge @args

      @args['ensure'] = @args['ensure'].to_s.boolean false
      @args['skipfail'] = @args['skipfail'].to_s.boolean false

      if @args['ip'].nil.nil? or System::ip_list(true).include? @args['ip']
        @args.delete 'ip'
      end

      if @args['callback'].nil.nil? or not Callback::respond_to? @args['callback']
        @args.delete 'callback'
      end

      if @args['callback_finish'].nil.nil? or not Callback::respond_to? @args['callback_finish']
        @args.delete 'callback_finish'
      end

      hash
    end

    def skip? args
      if not args['skip'].nil.nil? and not args['home'].nil.nil?
        file = File.join args['home'].to_s, 'create.id'
        ip = args['ip'].to_s.nil

        if ip.nil?
          if File.file? file
            args['skip'].to_s.strip == IO.read(file).to_s.utf8.strip
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

          args['skip'].to_s.strip == string.to_s.utf8.strip
        end
      else
        false
      end
    end

    def skiped args
      if not args['skip'].nil.nil? and not args['home'].nil.nil?
        file = File.join args['home'].to_s, 'create.id'
        ip = args['ip'].to_s.nil

        if ip.nil?
          File.open file, 'w' do |f|
            f << args['skip'].to_s.strip.locale
          end
        else
          drb = DRb::Object.new

          if drb.connect ip
            drb.file file do |string|
              args['skip'].to_s.strip.locale
            end
          end

          drb.close
        end
      end
    end
  end

  class Sequence < CommandBase
    def initialize args = nil
      @args = args || {}
      @sequence_list = []
    end

    def exec skip = false
      if skip? @args
        skip = true
      end

      status = true

      @sequence_list.each do |sequence|
        if not sequence.exec skip
          skip = true
          status = false
        end
      end

      if status
        if not @args['skip'].nil.nil?
          skiped @args
        end
      end

      status
    end

    def load element, opt = nil
      hash = attributes element, opt

      args = {}

      if is_a? Sequence
        if not @args['ip'].nil?
          args['ip'] = @args['ip']
        end
      end

      element.each_element do |e|
        case e.name
        when 'sequence'
          sequence = Sequence.new args.clone
          sequence.load e, hash

          @sequence_list << sequence
        when 'list'
          sequence = ListSequence.new args.clone
          sequence.load e, hash

          @sequence_list << sequence
        when 'parallel'
          parallel = Parallel.new args.clone
          parallel.load e, hash

          @sequence_list << parallel
        else
          if Template.respond_to? e.name
            e_args = {
              :__element__ => e
            }

            e.attributes.each do |k, v|
              e_args[k] = v.to_s.strip.vars hash
            end

            template_element = Template::__send__ e.name, e_args

            if not template_element.nil?
              template_element.to_array.each do |element|
                sequence = Sequence.new args.clone
                sequence.load element, hash

                @sequence_list << sequence
              end
            end
          else
            command = CommandAction.new e.name, args.clone
            command.load e, hash

            if command_valid? e.name
              @sequence_list << command
            end
          end
        end
      end
    end

    def ips
      ips = []

      @sequence_list.each do |sequence|
        if sequence.is_a? Sequence
          ips += sequence.ips
        else
          if not sequence.args['ip'].nil?
            ips << sequence.args['ip']
          end
        end
      end

      ips.sort!
      ips.uniq!

      ips
    end

    def to_string
      lines = []

      lines << 'sequence:'

      @sequence_list.each do |sequence|
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
      if skip? @args
        skip = true
      end

      status = true

      @sequence_list.each do |sequence|
        if not sequence.exec skip
          status = false
        end
      end

      if status
        if not @args['skip'].nil.nil?
          skiped @args
        end
      end

      status
    end

    def to_string
      lines = []

      lines << 'list_sequence:'

      @sequence_list.each do |sequence|
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
      if skip? @args
        skip = true
      end

      threads = []

      @sequence_list.each do |sequence|
        threads << Thread.new do
          sequence.exec skip
        end
      end

      threads.each do |thread|
        thread.join
      end

      status = true

      threads.each do |thread|
        if not thread.value
          status = false
        end
      end

      if status
        if not @args['skip'].nil.nil?
          skiped @args
        end
      end

      status
    end

    def to_string
      lines = []

      lines << 'parallel:'

      @sequence_list.each do |sequence|
        sequence.to_string.each_line do |line|
          lines << INDENT + line.rstrip
        end

        lines << ''
      end

      lines.join("\n").rstrip
    end
  end

  class CommandAction < CommandBase
    @@lock = Monitor.new

    def initialize name, args = nil
      @name = name
      @args = args || {}
    end

    def exec skip = false
      if skip? @args
        skip = true
      end

      if @args['ensure']
        skip = false
      end

      desc = @args['name'].to_s
      ip = @args['ip'].to_s.nil

      if not ip.nil?
        desc += ' - %s' % ip
      end

      status = true

      $errors = nil

      if command_valid? @name
        if not skip
          Util::Logger::head 'Execute ' + desc

          time = Time.now

          begin
            case @name
            when 'copy'
              status = command_copy ip
            when 'delete'
              status = command_delete ip
            when 'mkdir'
              status = command_mkdir ip
            when 'cmdline'
              status = command_cmdline ip
            when 'function'
              status = command_function ip
            end
          rescue
            Util::Logger::exception $!

            status = false
          end

          if @args['skipfail']
            status = true
          end

          if status
            if not @args['skip'].nil.nil?
              skiped @args
            end
          end

          @@lock.synchronize do
            $distributecommand << [desc, status, ((Time.now - time) * 1000).to_i / 1000.0]

            if not $errors.nil?
              $distributecommand_errors << [desc, $errors.uniq]
            end
          end
        else
          @@lock.synchronize do
            $distributecommand << [desc, nil, 0]
          end
        end
      end

      status
    end

    def load element, opt = nil
      attributes element, opt
    end

    def to_string
      lines = []

      lines << 'name    : ' + @name
      lines << 'args    :'

      @args.to_string.each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines.join "\n"
    end

    private

    def command_copy ip = nil
      path = @args['path'].to_s.nil
      to_path = @args['to_path'].to_s.nil
      callback = @args['callback'].to_s.nil

      if not path.nil? and not to_path.nil?
        status = true

        if ip.nil?
          thread = Thread.new do
            File.copy path, to_path do |src, dest|
              Util::Logger::info src

              [src, dest]
            end
          end

          thread.join

          if not thread.value
            status = false
          end

          if not callback.nil?
            sleep 1

            if DistributeCommand::Callback::respond_to? callback
              thread = Thread.new do
                string = "DistributeCommand::Callback::#{callback}"

                CommandLine::function string, true, nil, @args.merge({'status' => status}) do |line, stdin, wait_thr|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
                status = false
              end
            else
              Util::Logger::exception 'No found function @ command_copy - DistributeCommand::Callback::%s' % callback

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect ip
            thread = Thread.new do
              drb.copy path, to_path do |src, dest|
                if dest.nil?
                  Util::Logger::exception src
                else
                  Util::Logger::info src
                end

                [src, dest]
              end
            end

            thread.join

            if not thread.value
              status = false
            end

            if not callback.nil?
              sleep 1

              thread = Thread.new do
                drb.callback callback, true, @args.merge({'status' => status}) do |line|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
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
        false
      end
    end

    def command_delete ip = nil
      path = @args['path'].to_s.nil
      callback = @args['callback'].to_s.nil

      if not path.nil?
        status = true

        if ip.nil?
          thread = Thread.new do
            File.delete path do |path|
              Util::Logger::info path

              path
            end
          end

          thread.join

          if not thread.value
            status = false
          end

          if not callback.nil?
            sleep 1

            if DistributeCommand::Callback::respond_to? callback
              thread = Thread.new do
                string = "DistributeCommand::Callback::#{callback}"

                CommandLine::function string, true, nil, @args.merge({'status' => status}) do |line, stdin, wait_thr|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
                status = false
              end
            else
              Util::Logger::exception 'No found function @ command_delete - DistributeCommand::Callback::%s' % callback

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect ip
            thread = Thread.new do
              drb.delete path do |path|
                Util::Logger::info path

                path
              end
            end

            thread.join

            if not thread.value
              status = false
            end

            if not callback.nil?
              sleep 1

              thread = Thread.new do
                drb.callback callback, true, @args.merge({'status' => status}) do |line|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
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
        false
      end
    end

    def command_mkdir ip = nil
      path = @args['path'].to_s.nil
      callback = @args['callback'].to_s.nil

      if not path.nil?
        status = true

        if ip.nil?
          thread = Thread.new do
            File.mkdir path do |path|
              Util::Logger::info path

              path
            end
          end

          thread.join

          if not thread.value
            status = false
          end

          if not callback.nil?
            sleep 1

            if DistributeCommand::Callback::respond_to? callback
              thread = Thread.new do
                string = "DistributeCommand::Callback::#{callback}"

                CommandLine::function string, true, nil, @args.merge({'status' => status}) do |line, stdin, wait_thr|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
                status = false
              end
            else
              Util::Logger::exception 'No found function @ command_mkdir - DistributeCommand::Callback::%s' % callback

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect ip
            thread = Thread.new do
              drb.mkdir path do |path|
                Util::Logger::info path

                path
              end
            end

            thread.join

            if not thread.value
              status = false
            end

            if not callback.nil?
              sleep 1

              thread = Thread.new do
                drb.callback callback, true, @args.merge({'status' => status}) do |line|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
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
        false
      end
    end

    def command_cmdline ip = nil
      cmdline = @args['cmdline'].to_s.nil
      home = @args['home'].to_s.nil || '.'
      callback = @args['callback'].to_s.nil
      callback_finish = @args['callback_finish'].to_s.nil

      status = true

      if ip.nil?
        lines = []

        if not cmdline.nil?
          if File.directory? home
            thread = Thread.new do
              thread_status = true

              string = "Dir.chdir '#{home}' do; system '#{cmdline}'; end"

              if not CommandLine::function string do |line, stdin, wait_thr|
                  Util::Logger::info line

                  lines << line

                  if not callback.nil?
                    args = {
                      'line'    => line,
                      'stdin'   => stdin,
                      'wait_thr'=> wait_thr
                    }

                    if DistributeCommand::Callback::respond_to? callback
                      if not DistributeCommand::Callback::__send__ callback, @args.merge(args) do |line|
                          Util::Logger::puts line
                        end

                        thread_status = false
                      end
                    else
                      Util::Logger::exception 'No found function @ command_cmdline - DistributeCommand::Callback::%s' % callback

                      thread_status = false
                    end
                  end
                end

                thread_status = false
              end

              thread_status
            end

            thread.join

            if not thread.value
              status = false
            end
          end
        end

        if not callback_finish.nil?
          sleep 1

          if DistributeCommand::Callback::respond_to? callback_finish
            thread = Thread.new do
              string = "DistributeCommand::Callback::#{callback_finish}"

              CommandLine::function string, true, nil, @args.merge({'lines' => lines, 'status' => status}) do |line, stdin, wait_thr|
                Util::Logger::puts line
              end
            end

            thread.join

            if not thread.value
              status = false
            end
          else
            Util::Logger::exception 'No found function @ command_cmdline - DistributeCommand::Callback::%s' % callback_finish

            status = false
          end
        end
      else
        drb = DRb::Object.new

        if drb.connect ip
          lines = []

          if not cmdline.nil?
            thread = Thread.new do
              thread_status = true

              if not drb.cmdline cmdline, @args do |line, stdin, wait_thr|
                  Util::Logger::info line

                  lines << line

                  if not callback.nil?
                    args = {
                      'line'    => line,
                      'stdin'   => stdin,
                      'wait_thr'=> wait_thr
                    }

                    if not drb.callback callback, false, @args.merge(args) do |line|
                        Util::Logger::puts line
                      end

                      thread_status = false
                    end
                  end
                end

                thread_status = false
              end

              thread_status
            end

            thread.join

            if not thread.value
              status = false
            end
          end

          if not callback_finish.nil?
            sleep 1

            thread = Thread.new do
              drb.callback callback_finish, true, @args.merge({'lines' => lines, 'status' => status}) do |line|
                Util::Logger::puts line
              end
            end

            thread.join

            if not thread.value
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
    end

    def command_function ip = nil
      function = @args['function'].to_s.nil
      callback = @args['callback'].to_s.nil

      if not function.nil?
        status = true

        if ip.nil?
          thread = Thread.new do
            DistributeCommand::Function::__send__ function, @args do |line|
              Util::Logger::puts line
            end
          end

          thread.join

          if not thread.value
            status = false
          end

          if not callback.nil?
            sleep 1

            if DistributeCommand::Callback::respond_to? callback
              thread = Thread.new do
                string = "DistributeCommand::Callback::#{callback}"

                CommandLine::function string, true, nil, @args.merge({'status' => status}) do |line, stdin, wait_thr|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
                status = false
              end
            else
              Util::Logger::exception 'No found function @ command_function - DistributeCommand::Callback::%s' % callback

              status = false
            end
          end
        else
          drb = DRb::Object.new

          if drb.connect ip
            thread = Thread.new do
              drb.function function, true, @args do |line|
                Util::Logger::puts line
              end
            end

            thread.join

            if not thread.value
              status = false
            end

            if not callback.nil?
              sleep 1

              thread = Thread.new do
                drb.callback callback, true, @args.merge({'status' => status}) do |line|
                  Util::Logger::puts line
                end
              end

              thread.join

              if not thread.value
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
        false
      end
    end
  end
end