module Util
  module Logger
    module_function

    DEBUG     = 1
    INFO      = 2
    CMDLINE   = 3
    WARN      = 4
    ERROR     = 5
    EXCEPTION = 6
    FATAL     = 7

    @@lock = Monitor.new
    @@level = INFO

    def set_level level
      @@level = level
    end

    def puts string, io = STDOUT
      @@lock.synchronize do
        line = string.to_s.utf8

        if not io.nil?
          if $logging
            $loggers ||= []
            $loggers << line
          end

          if $drb.nil?
            io.puts line
          end
        else
          line
        end
      end
    end

    def debug string, io = STDOUT
      @@lock.synchronize do
        if @@level <= DEBUG
          line = '[DEBUG] ' + string.to_s.utf8

          if not io.nil?
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          else
            line
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def info string, io = STDOUT
      @@lock.synchronize do
        if @@level <= INFO
          line = '[INFO] ' + string.to_s.utf8

          if not io.nil?
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          else
            line
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def cmdline string, io = STDOUT
      @@lock.synchronize do
        if @@level <= CMDLINE
          lines = []

          lines << '$ %s' % string.to_s.utf8
          lines << '  (in %s)' % Dir.pwd.utf8

          if not io.nil?
            lines.each do |line|
              if $logging
                $loggers ||= []
                $loggers << line
              end

              if $drb.nil?
                io.puts line
              end
            end
          else
            lines.join "\n"
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def warn string, io = STDOUT
      @@lock.synchronize do
        if @@level <= WARN
          line = '[WARN] ' + string.to_s.utf8

          if not io.nil?
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          else
            line
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def error string, io = STDOUT
      @@lock.synchronize do
        if @@level <= ERROR
          line = '[ERROR] ' + string.to_s.utf8

          if not io.nil?
            if $logging
              $loggers ||= []
              $loggers << line
            end

            $errors ||= []
            $errors << line

            if $drb.nil?
              io.puts line
            end
          else
            line
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def exception exception, backtrace = false, io = STDOUT
      backtrace = true

      @@lock.synchronize do
        if @@level <= EXCEPTION
          lines = []

          lines << '[EXCEPTION] ' + exception.to_s.utf8

          if exception.is_a? Exception
            if backtrace
              exception.backtrace.each do |line|
                lines << line.utf8
              end
            end
          end

          if not io.nil?
            lines.each do |line|
              if $logging
                $loggers ||= []
                $loggers << line
              end

              $errors ||= []
              $errors << line

              if $drb.nil?
                io.puts line
              end
            end
          else
            lines.join "\n"
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def fatal string, io = STDOUT
      @@lock.synchronize do
        if @@level <= FATAL
          line = '[FATAL] ' + string.to_s.utf8

          if not io.nil?
            if $logging
              $loggers ||= []
              $loggers << line
            end

            $errors ||= []
            $errors << line

            if $drb.nil?
              io.puts line
            end
          else
            line
          end
        else
          if io.nil?
            nil
          end
        end
      end
    end

    def head string, io = STDOUT
      @@lock.synchronize do
        lines = []

        lines << '[INFO]'
        lines << headline
        lines << '[INFO] %s' % string.to_s.utf8
        lines << headline
        lines << '[INFO]'

        if not io.nil?
          lines.each do |line|
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          end
        else
          lines.join "\n"
        end
      end
    end

    def tail io = STDOUT
      @@lock.synchronize do
        lines = []

        lines << headline
        lines << '[INFO]'

        if not io.nil?
          lines.each do |line|
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          end
        else
          lines.join "\n"
        end
      end
    end

    def summary command_list, total_time, io = STDOUT
      @@lock.synchronize do
        lines = []

        lines << headline
        lines << '[INFO] Command Summary:'
        lines << '[INFO]'

        size = 48

        command_list.each do |name, status, time|
          if [STDOUT, STDERR].include? io
            if name.to_s.locale.bytesize > size
              size = name.to_s.locale.bytesize
            end
          else
            if name.to_s.utf8.bytesize > size
              size = name.to_s.utf8.bytesize
            end
          end
        end

        if size > 78
          width = 78
        else
          width = size
        end

        success = 'SUCCESS'

        command_list.each do |name, status, time|
          if [STDOUT, STDERR].include? io
            name = name.to_s.locale
          else
            name = name.to_s.utf8
          end

          if name.bytesize > width
            wrap_lines = name.wrap(width).utf8

            lines << '[INFO] ' + wrap_lines.shift
            name = wrap_lines.pop

            wrap_lines.each do |x|
              lines << '       ' + x
            end

            line = '       ' + name.utf8 + ' ' + '.' * (width - name.bytesize + 2)
          else
            line = '[INFO] ' + name.utf8 + ' ' + '.' * (width - name.bytesize + 2)
          end

          case status
          when false
            if time.nil?
              lines << '%s FAILURE' % line
            else
              lines << '%s FAILURE [ %10s]' % [line, format_time(time)]
            end
          when nil
            lines << '%s SKIPPED' % line
          else
            if time.nil?
              lines << '%s SUCCESS' % line
            else
              lines << '%s SUCCESS [ %10s]' % [line, format_time(time)]
            end
          end

          if status == false
            success = 'FAILURE'
          end
        end

        lines << headline
        lines << '[INFO] EXECUTE %s' % success
        lines << headline
        lines << '[INFO] Total time: %s' % format_time(total_time)
        lines << '[INFO] Finished at: ' + Time.now.to_s
        lines << headline

        if not io.nil?
          lines.each do |line|
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          end
        else
          lines.join "\n"
        end
      end
    end

    def summary_error command_errors, io = STDOUT
      @@lock.synchronize do
        lines = []

        lines << headline
        lines << '[INFO] Command Errors Summary:'

        command_errors.each do |name, _lines|
          lines << '[INFO]'
          lines << '[INFO] ' + name.to_s.utf8 + ':'

          _lines.each do |line|
            if not line.nil?
              lines << '[INFO] ' + INDENT + line.to_s.utf8
            end
          end
        end

        lines << headline

        if not io.nil?
          lines.each do |line|
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          end
        else
          lines.join "\n"
        end
      end
    end

    def should status, a, b, io = STDOUT
      @@lock.synchronize do
        success = 'SUCCESS'

        if not status
          success = 'FAILURE'
        end

        lines = []

        lines << headline
        lines << '[INFO] 校验结果: %s' % success
        lines << headline
        lines << '[INFO]'

        lines << '[INFO] 预期值:'

        a.to_string.lines.each do |line|
          lines << INDENT * 3 + ' ' + line.rstrip.utf8
        end

        lines << '[INFO] 当前值:'

        b.to_string.lines.each do |line|
          lines << INDENT * 3 + ' ' + line.rstrip.utf8
        end

        lines << '[INFO]'
        lines << headline

        if not io.nil?
          lines.each do |line|
            if $logging
              $loggers ||= []
              $loggers << line
            end

            if $drb.nil?
              io.puts line
            end
          end
        else
          lines.join "\n"
        end
      end
    end

    def format_time sec
      list = [nil, nil, nil]
      unit = 's'

      ['s', 'min', 'h'].each_with_index do |name, index|
        if index >= 2
          if sec > 0
            list[index] = sec
            unit = name
          end

          break
        end

        value = sec % 60

        if value > 0
          list[index] = value
          unit = name
        end

        sec = sec.to_i / 60
      end

      index = -1

      list.reverse.each do |x|
        if not x.nil?
          break
        end

        index -= 1
      end

      if list.size <= 1
        '%s s' % list.first.to_i
      else
        '%s %s' % [list[0..index].reverse.map {|x| '%02d' % x.to_i}.join(':'), unit]
      end
    end

    def headline
      '[INFO] ------------------------------------------------------------------------'
    end
  end
end