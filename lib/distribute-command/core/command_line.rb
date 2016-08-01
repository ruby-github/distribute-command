require 'open3'

module CommandLine
  module_function

  @@lock = Monitor.new

  def cmdline cmdline, args = nil
    args ||= {}

    if not args.has_key? :cmdline
      args[:cmdline] = true
    end

    if block_given?
      if args[:cmdline]
        string = Util::Logger::cmdline cmdline, nil

        yield string, nil, nil
      end
    end

    begin
      stdin, stdout_and_stderr, wait_thr = Open3.popen2e cmdline.locale
    rescue
      if block_given?
        string = Util::Logger::exception $!, false, nil

        yield string, nil, nil
      end

      return false
    end

    wait_thr[:async] = (args[:async] || args['async']).to_s.boolean false
    wait_thr[:expired] = (args[:expired] || args['expired']).to_i
    wait_thr[:exitstatus] = (args[:exitstatus] || args['exitstatus']).to_i.to_array

    cmdline_exec stdin, stdout_and_stderr, wait_thr do |line, io|
      if block_given?
        yield line, stdin, wait_thr
      end
    end
  end

  def function string, yield_line = false, require_name = nil, args = nil
    string = string.strip.gsub '"', '\\"'
    tmpname = nil

    lines = ['begin']

    if args.nil?
      string.lines.each do |line|
        lines << line.rstrip
      end

      if yield_line
        lines[-1] += ' do |line|'
        lines << 'puts line'
        lines << 'end'
      end
    else
      tmpname = YAML::dump_tmpfile args

      if yield_line
        "#{string} YAML::load_tmpfile('#{tmpname}') do |line|".lines.each do |line|
          lines << line.rstrip
        end

        lines << 'puts line'
        lines << 'end'
      else
        "#{string} YAML::load_tmpfile('#{tmpname}')".lines.each do |line|
          lines << line.rstrip
        end
      end
    end

    lines << 'end'

    if OS::windows?
      ruby = File.join RbConfig::CONFIG["bindir"], 'ruby.exe'
    else
      ruby = File.join RbConfig::CONFIG["bindir"], 'ruby'
    end

    cmd = File.cmdline(ruby)
    cmd += ' -e "YAML::Output::puts(%s)"' % lines.join('; ')

    if require_name.nil?
      cmd += ' -r "distribute-command"'
    else
      cmd += ' -r "%s"' % require_name
    end

    lines = []
    start = false

    if not cmdline cmd, cmdline: false do |line, stdin, wait_thr|
        if line.include? 'YAML OUTPUT STRING'
          lines << line
          start = true

          next
        end

        if line.include? 'YAML OUTPUT FINISH'
          lines << line
          start = false

          next
        end

        if start
          lines << line
        else
          if block_given?
            yield line, stdin, wait_thr
          end
        end
      end

      return false
    end

    if not tmpname.nil?
      File.delete File.join(Dir.tmpdir, tmpname)
    end

    YAML::Output::load lines
  end

  def cmdline_exec stdin, ios, wait_thr
    status = true

    expired = false

    begin
      threads = []

      ios.to_array.each do |io|
        threads << Thread.new do
          str = ''

          loop do
            if wait_thr[:async]
              break
            end

            eof = false

            thread = Thread.new do
              if io.eof?
                if not str.empty?
                  str = str.utf8.rstrip

                  if block_given?
                    begin
                      yield str, io
                    rescue Errno::EPIPE => e
                    end
                  end

                  str = ''
                end

                eof = true
              end
            end

            if thread.join(1).nil?
              if not str.empty?
                str = str.utf8.rstrip

                if block_given?
                  begin
                    yield str, io
                  rescue Errno::EPIPE => e
                  end
                end

                str = ''
              end
            end

            thread.join

            if eof
              break
            end

            str << io.readpartial(4096)
            lines = str.lines

            if lines.last =~ /[\r\n]$/
              str = ''
            else
              str = lines.pop.to_s
            end

            lines.each do |line|
              line = line.utf8.rstrip

              if block_given?
                begin
                  yield line, io
                rescue Errno::EPIPE => e
                end
              end
            end
          end
        end
      end

      time = Time.now

      loop do
        alive = false

        threads.each do |thread|
          thread.join 5

          if not wait_thr.alive?
            thread.exit
          end

          if wait_thr[:expired] > 0
            if Time.now - time > wait_thr[:expired]
              thread.exit

              status = false
              expired = true
            end
          end

          if thread.alive?
            alive = true
          end
        end

        if not alive
          break
        end
      end

      if not wait_thr[:async]
        begin
          if not wait_thr[:exitstatus].include? wait_thr.value.exitstatus
            status = false
          end
        rescue
          status = false
        end
      else
      end
    ensure
      if not wait_thr.nil? and not wait_thr[:async]
        ([stdin] + ios.to_array).each do |io|
          if not io.closed?
            io.close
          end
        end

        wait_thr.join
      end
    end

    if expired
      if block_given?
        string = Util::Logger::exception 'cmdline execute expired - %s' % wait_thr[:expired], false, nil

        yield string, nil
      end
    end

    status
  end

  class << self
    private :cmdline_exec
  end
end