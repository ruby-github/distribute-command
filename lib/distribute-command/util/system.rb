require 'socket'

module System
  module_function

  def ip_list local = false
    list = []

    Socket.ip_address_list.each do |address|
      if address.ipv4_private?
        list << address.ip_address
      end
    end

    if list.empty? or local
      list << '127.0.0.1'
    end

    list.sort!
    list.uniq!

    list
  end

  def ip ignores = nil
    ips = ip_list
    first = ips.first

    if ips.size > 1
      ignores ||= '192.'

      ips.delete_if do |ip_address|
        del = false

        ignores.to_array.each do |ignore|
          if ip_address.start_with? ignore
            del = true
          end
        end

        del
      end
    end

    ips.first || first
  end

  def database_info
    database_name = nil
    database_home = nil

    if OS::windows?
      start = false
      tmp = nil

      CommandLine::cmdline 'sc query state= all' do |line, stdin, wait_thr|
        line = line.strip

        if line =~ /^SERVICE_NAME\s*:\s*(.*MSSQLSERVER|.*SQLEXPRESS)/
          start = true

          if database_name.nil?
            database_name = '%s%s' % [$1, $']
          else
            tmp = '%s%s' % [$1, $']
          end
        else
          start = false

          tmp = nil
        end

        if start and not tmp.nil? and line =~ /^STATE\s*:\s*RUNNING$/
          database_name = tmp
        end
      end

      if not database_name.nil?
        CommandLine::cmdline 'sc qc %s' % database_name do |line, stdin, wait_thr|
          line = line.strip

          if line =~ /^BINARY_PATH_NAME\s*:\s*\"*(.*)\\Binn\\/
            database_home = '%s\\DATA\\' % $1.strip
          end
        end
      end
    else
      if not ENV['ORACLE_HOME'].nil?
        database_home = File.join ENV['ORACLE_HOME'], '../../../oradata/uep'
      else
        database_home = '/opt/oracle/oradata/uep'
      end
    end

    [database_name, database_home]
  end

  def service_state name
    if OS::windows?
      state = nil

      CommandLine::cmdline 'sc query %s' % name do |line, stdin, wait_thr|
        line = line.strip

        if line =~ /^STATE\s*:\s*\d+\s+/
          state = $'
        end
      end

      state
    else
      nil
    end
  end

  def update_windows_gem ip, file = nil
    file ||= 'd:/git/distribute-command/distribute-command-0.0.1.gem'

    status = true

    if ip.nil?
      cmds = []

      cmds << 'gem install "%s" --local -f' % file
      cmds << 'gem cl'

      cmds.each do |cmdline|
        if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            Util::Logger::puts line
          end

          status = false
        end
      end
    else
      name = File.join 'd:', File.basename(file)

      cmds = []

      cmds << 'gem install "%s" --local -f' % name
      cmds << 'gem cl'

      drb = DRb::Object.new

      if drb.connect ip
        if not drb.copy file, name do |src, dest|
            Util::Logger::puts src

            [src, dest]
          end

          status = false
        end

        if status
          cmds.each do |cmdline|
            if not drb.cmdline cmdline do |line|
                Util::Logger::puts line
              end

              status = false
            end
          end
        end

        drb.delete name do |path|
          Util::Logger::puts path

          path
        end
      else
        if not File.copy file, File.join('//', ip, 'd$', File.basename(name)) do |src, dest|
            Util::Logger::puts src

            [src, dest]
          end

          status = false
        end

        if status
          begin
            telnet = Net::Telnet::new 'Host' => ip, 'windows' => true

            telnet.login 'administrator', $password || 'admin!1234' do |c|
              print c
            end

            cmds.each do |cmdline|
              telnet.cmd cmdline do |c|
                print c
              end
            end

            telnet.cmd 'exit' do |c|
              print c
            end

            telnet.close
          rescue
            status = false
          end
        end

        File.delete File.join('//', ip, 'd$', File.basename(name)) do |path|
          Util::Logger::puts path

          path
        end
      end

      if status
        drb.reboot_drb
      else
        drb.close
      end
    end

    status
  end

  def update_windows_hostname ip, name, new_name
    cmdline = 'wmic computersystem where name="%s" call rename "%s"' % [name, new_name]

    status = true

    if ip.nil?
      if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          Util::Logger::puts line
        end

        status = false
      end
    else
      drb = DRb::Object.new

      if drb.connect ip
        if not drb.cmdline cmdline do |line|
            Util::Logger::puts line
          end

          status = false
        end
      else
        begin
          telnet = Net::Telnet::new 'Host' => ip, 'windows' => true

          telnet.login 'administrator', $password || 'admin!1234' do |c|
            print c
          end

          telnet.cmd cmdline do |c|
            print c
          end

          telnet.cmd 'exit' do |c|
            print c
          end

          telnet.close
        rescue
          status = false
        end
      end

      drb.close
    end

    status
  end

  def update_windows_dns ip, dns1, dns2 = nil, name = nil
    name ||= '本地连接'

    cmds = []
    cmds << 'netsh interface ip set dns name="%s" source=static addr=none' % name
    cmds << 'netsh interface ip set dns name="%s" source=static addr=%s' % [name, dns1]

    if not dns2.nil?
      cmds << 'netsh interface ip add dnsservers name="%s" address=%s index=2' % [name, dns2]
    end

    status = true

    if ip.nil?
      cmds.each do |cmdline|
        if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            Util::Logger::puts line
          end

          status = false
        end
      end
    else
      drb = DRb::Object.new

      if drb.connect ip
        cmds.each do |cmdline|
          if not drb.cmdline cmdline do |line|
              Util::Logger::puts line
            end

            status = false
          end
        end
      else
        begin
          telnet = Net::Telnet::new 'Host' => ip, 'windows' => true

          telnet.login 'administrator', $password || 'admin!1234' do |c|
            print c
          end

          cmds.each do |cmdline|
            telnet.cmd cmdline do |c|
              print c
            end
          end

          telnet.cmd 'exit' do |c|
            print c
          end

          telnet.close
        rescue
          status = false
        end
      end

      drb.close
    end

    status
  end

  def update_windows_ip ip, new_ip, mask = nil, gateway = nil, name=nil
    mask ||= '255.255.252.0'
    gateway ||= '10.8.8.3'
    name ||= '本地连接'

    cmdline = 'start netsh interface ip set address name="%s" source=static addr=%s mask=%s gateway=%s' % [name, new_ip, mask, gateway]

    status = true

    if ip.nil?
      if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          Util::Logger::puts line
        end

        status = false
      end
    else
      drb = DRb::Object.new

      if drb.connect ip
        Util::Logger::cmdline cmdline

        if not drb.system cmdline
          status = false
        end
      else
        begin
          telnet = Net::Telnet::new 'Host' => ip, 'windows' => true

          telnet.login 'administrator', $password || 'admin!1234' do |c|
            print c
          end

          telnet.cmd cmdline do |c|
            print c
          end

          telnet.cmd 'exit' do |c|
            print c
          end

          telnet.close
        rescue
          status = false
        end
      end

      drb.close
    end

    status
  end
end