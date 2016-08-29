module DistributeCommand
  module Callback
    module_function

    def netnumen_install args = nil
      args ||= {}

      if args['lines'].is_a? Array
        status = false

        lines = []

        args['lines'].each do |line|
          if line.include? '[LOG_SCANNER_FOR_INSTALL_UPDATE:SUCCESS]'
            status = true
          end
        end

        args['lines'].each do |line|
          if line =~ /(系统初始化.*失败|System\s+initialization.*\s+failed)/
            status = false
          end

          if line =~ /\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2},\d+\s+ERROR/
            lines << line

            next
          end

          if line.downcase =~ /\[log_scanner_for_install_update:script\]\s*(执行数据库脚本.*失败|execute.*failed)/
            lines << line

            next
          end
        end

        if not lines.empty?
          head = Util::Logger::head 'INSTALLATION ERROR', nil

          (head.lines + lines).each do |line|
            line.rstrip!

            if block_given?
              yield Util::Logger::error(line, nil)
            else
              Util::Logger::error line
            end
          end
        end

        file = 'conf/silenceinstall-for-localhost.xml'

        if File.file? file
          install_home = nil

          begin
            doc = REXML::Document.file file

            REXML::XPath.each(doc, '/UserSetValue/InstallPath') do |e|
              install_home = e.text.to_s.nil

              break
            end
          rescue
            Util::Logger::exception $!
          end

          if not install_home.nil?
            db_config = File.join install_home, 'ums-server/utils/dbtool/conf/dbtool-config.xml'

            if File.file? db_config
              begin
                doc = REXML::Document.file db_config

                REXML::XPath.each doc, '/dbtool/allow_other_language' do |e|
                  e.text = 'true'
                end

                doc.to_file db_config
              rescue
                Util::Logger::exception $!
              end
            end
          end
        end

        file = 'ums-server/utils/dbtool/conf/dbtool-config.xml'

        if File.file? file
          begin
            doc = REXML::Document.file file

            REXML::XPath.each doc, '/dbtool/ignoreUcaConflict' do |e|
              e.text = 'true'
            end

            REXML::XPath.each doc, '/dbtool/allow_other_language' do |e|
              e.text = 'true'
            end

            REXML::XPath.each doc, '/dbtool/allow_all_scale' do |e|
              e.text = 'true'
            end

            doc.to_file file
          rescue
            Util::Logger::exception $!
          end
        end

        status
      else
        true
      end
    end

    def netnumen_uninstall args = nil
      args ||= {}

      home = args['home']

      if not home.nil?
        home = File.expand_path home

        if home =~ /\/(ums-server|ums-client)/
          home = File.dirname File.join($`, $1)
        end

        if File.directory? home
          if File.directory? File.join(home, 'ums-server')
            netnumen_close_server do |line|
              if block_given?
                yield line
              end
            end
          end

          if File.directory? File.join(home, 'ums-client')
            netnumen_close_client do |line|
              if block_given?
                yield line
              end
            end
          end

          File.delete home do |path|
            if block_given?
              yield path
            end

            path
          end
        else
          true
        end
      else
        true
      end
    end

    def netnumen_start_server args = nil
      args ||= {}

      home = args['home']
      expired = args['expired'].to_i

      if not home.nil?
        home = File.expand_path home

        if home =~ /\/(ums-server)/
          home = File.join $`, $1
        end

        if File.directory? home
          time = Time.now

          map = {}

          loop do
            sleep 10

            if expired > 0
              if Time.now - time > expired
                `#{File.cmdline File.join(home, 'shutdown-console.bat')}`.to_s.lines.each do |line|
                  if block_given?
                    yield line.rstrip
                  end
                end

                netnumen_close_server do |line|
                  if block_given?
                    yield line
                  end
                end

                Util::Logger::error "start server expired: #{expired}"

                return false
              end
            end

            files = File.glob(File.join(home, 'utils/console/works/console*/log/console-console*.log')).sort do |x, y|
              File.basename(x) <=> File.basename(y)
            end

            if files.empty?
              next
            end

            started = false

            files.each do |file|
              if File.basename(file) =~ /console-console\d+-/
                if $' > time.strftime('%Y%m%d-%H%M')
                  lines = IO.read(file).lines
                  lines.pop

                  lines.each_with_index do |line, index|
                    if block_given?
                      if not map.has_key? file
                        map[file] = -1
                      end

                      if index > map[file]
                        yield line.rstrip
                      end

                      map[file] = index
                    end

                    if line.include? 'All processes started'
                      started = true

                      break
                    end
                  end
                end
              end

              if started
                break
              end
            end

            if started
              break
            end
          end

          sleep 10

          true
        else
          false
        end
      else
        false
      end
    end

    def netnumen_start_client args = nil
      args ||= {}

      home = args['home']
      expired = args['expired'].to_i

      if not home.nil?
        home = File.expand_path home

        if home =~ /\/(ums-client)/
          home = File.join $`, $1
        end

        if File.directory? home
          time = Time.now

          map = {}

          loop do
            sleep 10

            if expired > 0
              if Time.now - time > expired
                netnumen_close_client do |line|
                  if block_given?
                    yield line
                  end
                end

                Util::Logger::error "start client expired: #{expired}"

                return false
              end
            end

            files = {}

            File.glob(File.join(home, 'works/*/log/clnt-*.log')).each do |file|
              if File.basename(file) =~ /clnt-[^\d]*/
                if $' > time.strftime('%Y%m%d-%H%M')
                  files[$&] ||= []
                  files[$&] << file
                end
              end
            end

            started = false

            files.each do |k, v|
              v.sort.each do |file|
                lines = IO.read(file).lines
                lines.pop

                lines.each_with_index do |line, index|
                  if block_given?
                    if not map.has_key? file
                      map[file] = -1
                    end

                    if index > map[file]
                      yield line.rstrip
                    end

                    map[file] = index
                  end

                  if line.include? 'EMB Started'
                    started = true

                    break
                  end
                end

                if started
                  break
                end
              end

              if started
                break
              end
            end

            if started
              break
            end
          end

          sleep 10

          true
        else
          false
        end
      else
        false
      end
    end

    def netnumen_close_server args = nil
      args ||= {}

      OS::kill do |pid, info|
        if info[:command_line].include? 'ums-server' or info[:name].include? 'zte_'
          true
        else
          if OS::windows?
            info[:command_line].include? 'console.bat' or info[:name].include? 'bcp.exe'
          else
            info[:command_line].include? 'console.sh' or info[:name].include? 'sqlldr'
          end
        end
      end

      sleep 10

      true
    end

    def netnumen_close_client args = nil
      args ||= {}

      if OS::windows?
        system 'net stop Launcher'
      end

      OS::kill do |pid, info|
        if info[:command_line].include? 'ums-client'
          true
        else
          if OS::windows?
            info[:command_line].include? '/K run.bat'
          else
            info[:command_line].include? '/K run.sh'
          end
        end
      end

      sleep 10

      true
    end

    def netnumen_restore_database args = nil
      args ||= {}

      if not args['line'].nil?
        status = true

        [
          'restore failed'
        ].each do |x|
          if args['line'].downcase.include? x
            Util::Logger::error args['line']

            status = false
          end
        end

        status
      else
        true
      end
    end

    def netnumen_update_silenceinstall args = nil
      args ||= {}

      file = File.expand_path args['to_path'].to_s

      if File.file? file
        database_name, database_home = System::database_info

        begin
          doc = REXML::Document.file file

          REXML::XPath.each(doc, '/UserSetValue/Locale') do |e|
            if args['ems_locale'] == 'en_US'
              e.text = 'en_US'
            else
              e.text = 'zh_CN'
            end
          end

          REXML::XPath.each(doc, '/UserSetValue/InstallType') do |e|
            e.text = 'ALL'
          end

          if args['client'] == 'true'
            REXML::XPath.each(doc, '/UserSetValue/InstallType') do |e|
              e.text = 'CLIENT'
            end
          end

          if args['server'] == 'true'
            REXML::XPath.each(doc, '/UserSetValue/InstallType') do |e|
              e.text = 'SERVER'
            end
          end

          REXML::XPath.each(doc, '/UserSetValue/InstallPath | /UserSetValue/DataAreaPath') do |e|
            e.text = File.expand_path args['install_home']
          end

          REXML::XPath.each(doc, '/UserSetValue/MainIP | /UserSetValue/Datasources/db/DatabaseContext/IP') do |e|
            e.text = args['ip'].nil || System::ip
          end

          doc.delete_element '/UserSetValue/EMSID'

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/Type') do |e|
            if OS::windows?
              e.text = 'mssql'
            else
              e.text = 'oracle'
            end
          end

          REXML::XPath.each(doc, '/UserSetValue/InstallDBMacro/Property') do |e|
            if not database_home.nil?
              if e.text.to_s.include? 'MSSQL' or e.text.to_s.include? 'oracle'
                e.text = database_home
              end
            end
          end

          doc.to_file file

          true
        rescue
          Util::Logger::exception $!

          if block_given?
            string = Util::Logger::exception $!, false, nil

            string.lines.each do |line|
              yield line.rstrip
            end
          end

          false
        end
      else
        false
      end
    end
  end
end