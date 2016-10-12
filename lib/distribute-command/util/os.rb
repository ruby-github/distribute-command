module OS
  module_function

  def name
    case RbConfig::CONFIG['host_os']
    when /mswin|mingw|cygwin/
      :windows
    when /linux/
      :linux
    when /solaris/
      :solaris
    when /freebsd|openbsd|netbsd/
      :bsd
    when /darwin/
      :mac
    when /aix/
      :aix
    when /hpux/
      :hpux
    else
      RbConfig::CONFIG['host_os']
    end
  end

  def windows?
    name == :windows
  end

  def java?
    RUBY_PLATFORM =~ /java/
  end

  def x64?
    case RbConfig::CONFIG['host_cpu']
    when /_64$/
      true
    when /(i386|i686)/
      false
    else
      if java? and ENV_JAVA['sun.arch.data.model']
        ENV_JAVA['sun.arch.data.model'].to_i == 64
      else
        1.size == 8
      end
    end
  end
end

module OS
  module_function

  def processes
    info = {}

    case name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'

      wmi.ExecQuery('select * from win32_process').each do |process|
        info[process.ProcessId] = {
          name:             process.Name.to_s.utf8.strip,
          pid:              process.ProcessId,
          parent_pid:       process.ParentProcessId,
          command_line:     process.CommandLine.to_s.utf8.strip,
          working_set_size: process.WorkingSetSize,
          creation_date:    process.CreationDate.to_s.utf8.strip,
          __process__:      process
        }
      end
    when :linux
      lines = `ps -eo pid,ppid,m_size,start_time,command`.lines
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, ppid, size, start, command = line.split /\s+/, 5

        info[pid.to_i] = {
          name:             File.basename(command.to_s.split(/\s/).first),
          pid:              pid.to_i,
          parent_pid:       ppid.to_i,
          command_line:     command.to_s,
          working_set_size: size.to_i,
          creation_date:    start.to_s,
          __process__:      nil
        }
      end

      lines = `ps -e`.lines.to_array
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, tty, time, command = line.split /\s+/, 4

        if info[pid.to_i].nil?
          next
        end

        info[pid.to_i][:name] = command.to_s
      end
    when :solaris
      lines = `ps -eo pid,ppid,rss,stime,args`.lines
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, ppid, size, start, command = line.split /\s+/, 5

        info[pid.to_i] = {
          name:             File.basename(command.to_s.split(/\s/).first),
          pid:              pid.to_i,
          parent_pid:       ppid.to_i,
          command_line:     command.to_s,
          working_set_size: size.to_i,
          creation_date:    start.to_s,
          __process__:      nil
        }
      end

      lines = `ps -e`.lines.to_array
      lines.shift

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        pid, tty, time, command = line.split /\s+/, 4

        if info[pid.to_i].nil?
          next
        end

        info[pid.to_i][:name] = command.to_s
      end
    end

    info
  end

  def process process_name, pid = nil
    if pid.nil?
      process_name = process_name.utf8.strip

      processes.each do |process_id, process_info|
        if process_info[:name] == process_name
          return process_info
        end
      end

      nil
    else
      processes[pid]
    end
  end

  def os_info
    info = {}

    case name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'

      wmi.ExecQuery('select * from win32_operatingsystem').each do |x|
        [
          'Caption',
          'CodeSet',
          'CountryCode',
          'CSDVersion',
          'CSName',
          'Name',
          'OSArchitecture',
          'OSLanguage',
          'RegisteredUser',
          'SerialNumber',
          'ServicePackMajorVersion',
          'ServicePackMinorVersion',
          'Version',
          'WindowsDirectory'
        ].each do |method_name|
          begin
            info[method_name.downcase.to_sym] = x.__send__(method_name).to_s.utf8.strip
          rescue
            info[method_name.downcase.to_sym] = nil
          end
        end

        info[:__os__] = x

        break
      end
    when :linux
    when :solaris
    end

    info
  end

  def cpu_info
    info = {
      size:       1,
      speed:      nil,
      max_speed:  nil,
      usage:      nil
    }

    case name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'
      first = nil

      wmi.ExecQuery('select * from Win32_Processor').each do |x|
        if first.nil?
          if x.ole_respond_to? :NumberOfLogicalProcessors
            info[:size] = x.NumberOfLogicalProcessors.to_i
          end

          info[:speed] = x.CurrentClockSpeed.to_i
          info[:max_speed] = x.MaxClockSpeed.to_i

          first = x
        end

        info[:usage] ||= []
        info[:usage] << x.LoadPercentage.to_i
      end

      if not first.ole_respond_to? :NumberOfLogicalProcessors
        info[:size] = wmi.ExecQuery('select NumberOfProcessors from Win32_ComputerSystem')
          .to_enum.first.NumberOfProcessors.to_i
      end
    when :linux
      info[:size] = `grep -c processor /proc/cpuinfo`.to_i
    when :solaris
      info[:size] = `psrinfo -p`.to_i
    when :bsd
      info[:size] = `sysctl -n hw.ncpu`.to_i
    when :mac
      if RbConfig::CONFIG['host_os'] =~ /darwin9/
        info[:size] = `hwprefs cpu_count`.to_i
      else
        if `which hwprefs` != ''
          info[:size] = `hwprefs thread_count`.to_i
        else
          info[:size] = `sysctl -n hw.ncpu`.to_i
        end
      end
    end

    if info[:usage].is_a? Array
      usage = 0

      info[:usage].each do |x|
        usage += x
      end

      if usage > 0
        usage = (usage.to_f / info[:usage].size).round
      end

      info[:usage] = usage
    end

    info
  end

  def memory_info
    info = {
      memory: 1,
      usage:  nil
    }

    case name
    when :windows
      wmi = WIN32OLE.connect 'winmgmts://'

      info[:memory] = wmi.ExecQuery('select Capacity from Win32_PhysicalMemory')
        .to_enum.first.Capacity.to_i / (1024 * 1024)
    when :linux
      info[:memory] = `grep -c MemTotal /proc/meminfo`.to_i / (1024 * 1024)
    when :solaris
    when :bsd
    when :mac
    end

    info
  end

  def kill all = false, opt = nil
    opt ||= {}

    all = false

    status = true

    processes.each do |pid, info|
      process_name = info[:name]

      if block_given?
        if not yield pid, info
          next
        end
      else
        if opt.has_key? :pid and opt[:pid] != pid
          next
        end

        if opt.has_key? :name and opt[:name] != process_name
          next
        end
      end

      if not all
        if [Process::pid, Process::ppid].include? pid
          next
        end

        if ['ruby', 'ruby.exe'].include? info[:name]
          next
        end
      end

      begin
        Process.kill :KILL, pid
      rescue
        if windows?
          if not CommandLine::cmdline 'TASKKILL /F /T /PID %s' % pid
            status = false
          end
        else
          status = false
        end
      end
    end

    status
  end

  def remote_reboot ips, windows = nil, sec = nil
    status = true

    sec = (sec || 600).to_i

    if not ips.nil?
      map = {}

      ips.to_array.each do |ip|
        ip, password = ip.split ':'

        map[ip] = password
      end

      if not map.empty?
        Util::Logger::puts '重启计算机: %s' % map.keys.join(', ')

        windows_ips = {}
        unix_ips = {}

        if windows.nil?
          map.each do |ip, password|
            drb = DRb::Object.new

            begin
              if drb.connect ip
                if drb.osname == 'windows'
                  windows_ips[ip] = password
                else
                  unix_ips[ip] = password
                end
              end
            rescue
              begin
                Net::SSH::start ip, 'root', :password => (password || 'admin-cgs') do |ssh|
                end

                unix_ips[ip] = password
              rescue
                windows_ips[ip] = password
              end
            end
          end
        else
          if windows
            windows_ips = map
          else
            unix_ips = map
          end
        end

        threads = []

        windows_ips.each do |ip, password|
          threads << Thread.new do
            Util::Logger::cmdline 'reboot %s' % ip

            begin
              telnet = Net::Telnet::new 'Host' => ip, 'windows' => true

              telnet.login 'administrator', password || 'admin!1234' do |c|
                print c
              end

              telnet.cmd "start shutdown -f -r -t 0" do |c|
                print c
              end

              sleep 1

              telnet.cmd "start shutdown -f -r -t 0" do |c|
                print c
              end

              telnet.cmd 'exit' do |c|
                print c
              end

              telnet.close

              sleep 120

              true
            rescue
              false
            end
          end
        end

        unix_ips.each do |ip, password|
          threads << Thread.new do
            Util::Logger::cmdline 'reboot %s' % ip

            begin
              Net::SSH::start ip, 'root', :password => (password || 'admin-cgs') do |ssh|
                ssh.exec 'init 6'

                sleep 1

                ssh.exec 'init 6'
              end

              sleep 60

              true
            rescue
              false
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

        sleep sec
      end
    end

    status
  end

  def remote_reboot_drb ips, sec = nil
    status = true

    sec = (sec || 60).to_i

    if not ips.nil?
      ips = ips.to_array

      if not ips.empty?
        Util::Logger::puts '重启计算机DRB服务: %s' % ips.join(', ')

        ips.each do |ip|
          drb = DRb::Object.new

          begin
            if drb.connect ip
              drb.reboot_drb
            end
          rescue
            status = false
          end
        end

        sleep sec
      end
    end

    status
  end
end

module Colorize
  COLORS = {
    black:      30,
    red:        31,
    green:      32,
    yellow:     33,
    blue:       34,
    magenta:    35,
    cyan:       36,
    white:      37
  }

  EXTRAS = {
    clear:      0,
    highlight:  1,
    underline:  4,
    shine:      5,
    reversed:   7,
    invisible:  8
  }

  def colorize string, fore = nil, back = nil, extras = nil
    colorize = []

    if fore
      if COLORS.has_key? fore.to_sym
        colorize << COLORS[fore.to_sym]
      end
    end

    if back
      if COLORS.has_key? back.to_sym
        colorize << COLORS[back.to_sym] + 10
      end
    end

    if extras
      extras.split(',').each do |x|
        if EXTRAS.has_key? x.to_sym
          colorize << EXTRAS[x.to_sym]
        end
      end
    end

    if not string.empty? and not colorize.empty?
      "\e[%sm%s\e[0m" % [colorize.join(';'), string]
    else
      string
    end
  end

  def uncolorize string
    string.gsub /\e\[[\d;]+m/, ''
  end

  def write string
    strs = []
    string = string.to_s

    while not string.empty?
      if string =~ /<\s*font\s*(.*?)\s*>(.*?)<\/\s*font\s*>/
        if not $`.empty?
          strs << [$`, nil]
        end

        strs << [$2, $1]
      else
        strs << [string, nil]

        break
      end

      string = $'
    end

    size = 0

    strs.each do |str, args|
      fore = nil
      back = nil
      extras = []

      if args
        args.split(';').each do |x|
          name, params = x.split ':', 2

          if params
            case name
            when 'color'
              fore = params
            when 'bgcolor'
              back = params
            end
          else
            extras << name
          end
        end
      end

      __write__ colorize(str, fore, back, extras.join(',')).locale
      size += str.size
    end

    size
  end
end

class << STDOUT
  alias __write__ write

  include Colorize
end

class << STDERR
  alias __write__ write

  include Colorize
end

autoload :WIN32OLE, 'win32ole'