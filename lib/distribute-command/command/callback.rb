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
                  e.text = true
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
              e.text = true
            end

            REXML::XPath.each doc, '/dbtool/allow_other_language' do |e|
              e.text = true
            end

            REXML::XPath.each doc, '/dbtool/allow_all_scale' do |e|
              e.text = true
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

      if args['status']
        sleep 60

        if block_given?
          yield Util::Logger::head('启动成功', nil)
        else
          Util::Logger::head '启动成功'
        end
      end

      true
    end

    def netnumen_start_client args = nil
      args ||= {}

      if args['status']
        sleep 10

        if block_given?
          yield Util::Logger::head('启动成功', nil)
        else
          Util::Logger::head '启动成功'
        end
      end

      true
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
        system 'start net stop Launcher'
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

          if args['client'].to_s.boolean false
            REXML::XPath.each(doc, '/UserSetValue/InstallType') do |e|
              e.text = 'CLIENT'
            end
          end

          if args['server'].to_s.boolean false
            REXML::XPath.each(doc, '/UserSetValue/InstallType') do |e|
              e.text = 'SERVER'
            end
          end

          REXML::XPath.each(doc, '/UserSetValue/InstallPath | /UserSetValue/DataAreaPath') do |e|
            e.text = File.expand_path args['install_home']
          end

          REXML::XPath.each(doc, '/UserSetValue/MainIP') do |e|
            e.text = args['ip'].nil || System::ip
          end

          doc.delete_element '/UserSetValue/EMSID'

          db_type     = nil
          db_ip       = nil
          db_port     = nil
          db_sid      = nil
          db_user     = nil
          db_password = nil

          if not args['db'].to_s.nil.nil?
            list = args['db'].to_s.split(':').map {|x| x.strip.nil}

            db_type     = list[0]
            db_ip       = list[1]
            db_port     = list[2]
            db_sid      = list[3]
            db_user     = list[4]
            db_password = list[5]
          end

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/Type') do |e|
            if db_type.nil?
              db_type = e.text.to_s.nil
            end

            if db_type.nil?
              if OS::windows?
                db_type = 'mssql'
              else
                db_type = 'oracle'
              end
            end

            e.text = db_type
          end

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/IP') do |e|
            if db_ip.nil?
              db_ip = args['ip'].nil || System::ip
            end

            e.text = db_ip
          end

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/Port') do |e|
            if db_port.nil?
              case db_type
              when 'mssql'
                db_port = 1433
              when 'oracle'
                db_port = 1521
              when 'mysql'
                db_port = 3306
              else
              end
            end

            if not db_port.nil?
              e.text = db_port
            end
          end

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/SID') do |e|
            e.text = db_sid
          end

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/SuperUser') do |e|
            if db_user.nil?
              case db_type
              when 'mssql'
                db_user = 'sa'
              when 'oracle'
                db_user = 'system'
              when 'mysql'
                db_user = 'root'
              else
              end
            end

            e.text = db_user
          end

          REXML::XPath.each(doc, '/UserSetValue/Datasources/db/DatabaseContext/SuperUserPassword') do |e|
            if db_password.nil?
              case db_type
              when 'mssql'
                db_password = 'sa'
              when 'oracle'
                db_password = 'oracle'
              when 'mysql'
                db_password = 'mysql'
              else
              end
            end

            e.text = db_password
          end

          database_home = nil

          if ['mssql', 'oracle', nil].include? db_type
            database_name, database_home = System::database_info
          end

          REXML::XPath.each(doc, '/UserSetValue/InstallDBMacro/Property') do |e|
            if not database_home.nil?
              if e.text.to_s.downcase.include? 'mssql' or e.text.to_s.downcase.include? 'oracle'
                e.text = database_home
              end
            end
          end

          doc.to_file file

          true
        rescue
          Util::Logger::exception $!

          if block_given?
            string = Util::Logger::exception $!, nil

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