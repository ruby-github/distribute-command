module DistributeCommand
  module Template
    module_function

    # args
    #   name, ip, path, to_path, ip_list
    #   callback
    def copy_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      callback = args['callback'].to_s.nil

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = args['name']
        copy_e.attributes['ip'] = ip
        copy_e.attributes['path'] = args['path']
        copy_e.attributes['to_path'] = args['to_path']

        if not callback.nil?
          copy_e.attributes['callback'] = callback
        end

        args.each do |name, value|
          if ['name', 'ip', 'path', 'to_path', 'callback'].include? name
            next
          end

          if not name.is_a? String
            next
          end

          copy_e.attributes[name] = value
        end

        element << copy_e
      end

      element
    end

    # args
    #   name, ip, path, ip_list
    #   callback
    def delete_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      callback = args['callback'].to_s.nil

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = args['name']
        delete_e.attributes['ip'] = ip
        delete_e.attributes['path'] = args['path']

        if not callback.nil?
          delete_e.attributes['callback'] = callback
        end

        args.each do |name, value|
          if ['name', 'ip', 'path', 'callback'].include? name
            next
          end

          if not name.is_a? String
            next
          end

          delete_e.attributes[name] = value
        end

        element << delete_e
      end

      element
    end

    # args
    #   name, ip, path, ip_list
    #   callback
    def mkdir_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      callback = args['callback'].to_s.nil

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        mkdir_e = REXML::Element.new 'mkdir'

        mkdir_e.attributes['name'] = args['name']
        mkdir_e.attributes['ip'] = ip
        mkdir_e.attributes['path'] = args['path']

        if not callback.nil?
          mkdir_e.attributes['callback'] = callback
        end

        args.each do |name, value|
          if ['name', 'ip', 'path', 'callback'].include? name
            next
          end

          if not name.is_a? String
            next
          end

          mkdir_e.attributes[name] = value
        end

        element << mkdir_e
      end

      element
    end

    # args
    #   name, ip, home, cmdline, ip_list
    #   callback, callback_finish
    def cmdline_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      callback = args['callback'].to_s.nil
      callback_finish = args['callback_finish'].to_s.nil

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        cmdline_e = REXML::Element.new 'cmdline'

        cmdline_e.attributes['name'] = args['name']
        cmdline_e.attributes['ip'] = ip
        cmdline_e.attributes['home'] = args['home']
        cmdline_e.attributes['cmdline'] = args['cmdline']

        if not callback.nil?
          cmdline_e.attributes['callback'] = callback
        end

        if not callback_finish.nil?
          cmdline_e.attributes['callback_finish'] = callback_finish
        end

        args.each do |name, value|
          if ['name', 'ip', 'home', 'cmdline', 'callback', 'callback_finish'].include? name
            next
          end

          if not name.is_a? String
            next
          end

          cmdline_e.attributes[name] = value
        end

        element << cmdline_e
      end

      element
    end

    # args
    #   name, ip, function, ip_list
    #   callback
    def function_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      callback = args['callback'].to_s.nil

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = args['name']
        function_e.attributes['ip'] = ip
        function_e.attributes['function'] = args['function']

        if not callback.nil?
          function_e.attributes['callback'] = callback
        end

        args.each do |name, value|
          if ['name', 'ip', 'function', 'callback'].include? name
            next
          end

          if not name.is_a? String
            next
          end

          function_e.attributes[name] = value
        end

        element << function_e
      end

      element
    end
  end

  module Template
    module_function

    # args
    #   file
    def import_xml args = nil
      args ||= {}

      file = args['file'].to_s.nil

      if not file.nil?
        if File.file? file
          begin
            doc = REXML::Document.file file
            doc.root
          rescue
            Util::Logger::exception $!

            nil
          end
        else
          Util::Logger::error 'no such file - %s' % file

          nil
        end
      else
        nil
      end
    end

    # args
    #   name, ip, home, bat
    #   cmdline, tmpdir
    def batch args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']

      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/batch_%s' % Time.now.timestamp_day

      # 拷贝文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝文件'
      copy_e.attributes['path'] = '${home}'
      copy_e.attributes['to_path'] = '${tmpdir}'

      element << copy_e

      # 执行批处理

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:执行批处理'
      cmdline_e.attributes['home'] = '${tmpdir}'
      cmdline_e.attributes['cmdline'] = args['cmdline'].to_s.nil || args['bat']

      element << cmdline_e

      # 清除临时文件

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除临时文件'
      delete_e.attributes['path'] = '${tmpdir}'
      delete_e.attributes['ensure'] = true
      delete_e.attributes['skipfail'] = true

      element << delete_e

      element
    end

    # args
    #   ip_list
    def batch_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << batch(args)
      end

      element
    end

    # args
    #   name, ip_list, sec
    def reboot args = nil
      args ||= {}

      # 重启机器

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = args['name']
      function_e.attributes['function'] = 'reboot'
      function_e.attributes['ip_list'] = args['ip_list'].to_s.nil
      function_e.attributes['sec'] = args['sec'].to_s.nil

      function_e
    end
  end

  module Template
    module_function

    # args
    #   name, ip, home, installation_home, silencefile, license
    #   cmdline, uninstall_cmdline, tmpdir, skip, installation_home_patch, ems_locale
    #   client, server, deletes
    #   db(type:ip:port:sid:user:password)
    def installation_iptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']
      element.attributes['installation_home'] = args['installation_home']
      element.attributes['silencefile'] = args['silencefile']

      if args.has_key? 'license'
        element.attributes['license'] = args['license']
      end

      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/installation_%s' % Time.now.timestamp_day

      if args.has_key? 'skip'
        element.attributes['skip'] = args['skip']
      end

      # 卸载网管

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:卸载网管'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = args['uninstall_cmdline'] || 'shutdown-console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_uninstall'
      cmdline_e.attributes['skipfail'] = true

      element << cmdline_e

      # 拷贝安装文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝安装文件'
      copy_e.attributes['path'] = args['installation_home']
      copy_e.attributes['to_path'] = '${tmpdir}'

      element << copy_e

      # 删除安装文件
      if args.has_key? 'deletes'
        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = '${name}:删除安装文件'
        delete_e.attributes['path'] = File.join '${tmpdir}', args['deletes']
        delete_e.attributes['ensure'] = true
        delete_e.attributes['skipfail'] = true

        element << delete_e
      end

      # 拷贝补丁文件

      if args.has_key? 'installation_home_patch'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝补丁文件'
        copy_e.attributes['path'] = args['installation_home_patch']
        copy_e.attributes['to_path'] = '${tmpdir}'

        element << copy_e
      end

      # 拷贝静默安装文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝静默安装文件'
      copy_e.attributes['path'] = args['silencefile']
      copy_e.attributes['to_path'] = '${tmpdir}/conf/silenceinstall-for-localhost.xml'
      copy_e.attributes['callback'] = 'netnumen_update_silenceinstall'

      copy_e.attributes['install_home'] = '${home}'
      copy_e.attributes['db'] = args['db'].to_s.nil

      if args.has_key? 'ems_locale'
        copy_e.attributes['ems_locale'] = args['ems_locale']
      end

      if args.has_key? 'client'
        copy_e.attributes['client'] = args['client']
      end

      if args.has_key? 'server'
        copy_e.attributes['server'] = args['server']
      end

      element << copy_e

      # 重启数据库
      if args['client'].to_s.boolean false
        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:重启数据库'
        function_e.attributes['home'] = '${home}'
        function_e.attributes['db'] = args['db'].to_s.nil
        function_e.attributes['function'] = 'netnumen_database_restart'

        element << function_e
      end

      # 安装网管

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:安装网管'
      cmdline_e.attributes['home'] = '${tmpdir}'
      cmdline_e.attributes['cmdline'] = args['cmdline'] || 'setup.bat d: silenceinstall-for-localhost.xml false'
      cmdline_e.attributes['callback_finish'] = 'netnumen_install'

      element << cmdline_e

      # 拷贝license

      if args.has_key? 'license'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝license'
        copy_e.attributes['path'] = args['license']
        copy_e.attributes['to_path'] = '${home}/ums-server/works/main/deploy/ums-license.LCS'

        element << copy_e
      end

      # 清除临时文件

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除临时安装文件'
      delete_e.attributes['path'] = '${tmpdir}/../install_tmp*'
      delete_e.attributes['ensure'] = true
      delete_e.attributes['skipfail'] = true

      element << delete_e

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除临时文件'
      delete_e.attributes['path'] = '${tmpdir}'
      delete_e.attributes['ensure'] = true
      delete_e.attributes['skipfail'] = true

      element << delete_e

      element
    end

    # args
    #   ip_list
    def installation_iptn_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << installation_iptn(args)
      end

      element
    end

    # args
    #   name, ip, home, installation_home, silencefile, license
    #   cmdline, uninstall_cmdline, tmpdir, skip, installation_home_patch, main_ip, ems_locale
    #   db(type:ip:port:sid:user:password)
    def installation_sptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']
      element.attributes['installation_home'] = args['installation_home']
      element.attributes['silencefile'] = args['silencefile']

      if args.has_key? 'license'
        element.attributes['license'] = args['license']
      end

      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/installation_%s' % Time.now.timestamp_day

      if args.has_key? 'skip'
        element.attributes['skip'] = args['skip']
      end

      # 卸载控制器

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:卸载控制器'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = args['uninstall_cmdline'] || 'shutdown-console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_uninstall'
      cmdline_e.attributes['skipfail'] = true

      element << cmdline_e

      # 拷贝安装文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝安装文件'
      copy_e.attributes['path'] = args['installation_home']
      copy_e.attributes['to_path'] = '${tmpdir}'

      element << copy_e

      # 拷贝补丁文件

      if args.has_key? 'installation_home_patch'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝补丁文件'
        copy_e.attributes['path'] = args['installation_home_patch']
        copy_e.attributes['to_path'] = '${tmpdir}'

        element << copy_e
      end

      # 拷贝静默安装文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝静默安装文件'
      copy_e.attributes['path'] = args['silencefile']
      copy_e.attributes['to_path'] = '${tmpdir}/conf/silenceinstall-for-localhost.xml'
      copy_e.attributes['callback'] = 'netnumen_update_silenceinstall'

      copy_e.attributes['install_home'] = '${home}'
      copy_e.attributes['db'] = args['db'].to_s.nil

      if args.has_key? 'ems_locale'
        copy_e.attributes['ems_locale'] = args['ems_locale']
      end

      copy_e.attributes['server'] = true

      element << copy_e

      # 重启数据库

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:重启数据库'
      function_e.attributes['home'] = '${home}'
      function_e.attributes['db'] = args['db'].to_s.nil
      function_e.attributes['function'] = 'netnumen_database_restart'

      element << function_e

      # 安装控制器

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:安装控制器'
      cmdline_e.attributes['home'] = '${tmpdir}'
      cmdline_e.attributes['cmdline'] = args['cmdline'] || 'setup.bat d: silenceinstall-for-localhost.xml false'
      cmdline_e.attributes['callback_finish'] = 'netnumen_install'

      element << cmdline_e

      # 拷贝license

      if args.has_key? 'license'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝license'
        copy_e.attributes['path'] = '${license}'
        copy_e.attributes['to_path'] = '${home}/ums-server/works/main/deploy/ums-license.LCS'

        element << copy_e
      end

      # 配置控制器

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:控制器'
      function_e.attributes['home'] = '${home}'
      function_e.attributes['function'] = 'netnumen_sptn_settings'

      if args.has_key? 'main_ip'
        function_e.attributes['main_ip'] = args['main_ip']
      end

      element << function_e

      # 清除临时文件

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除临时安装文件'
      delete_e.attributes['path'] = '${tmpdir}/../install_tmp*'
      delete_e.attributes['ensure'] = true
      delete_e.attributes['skipfail'] = true

      element << delete_e

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除临时文件'
      delete_e.attributes['path'] = '${tmpdir}'
      delete_e.attributes['ensure'] = true
      delete_e.attributes['skipfail'] = true

      element << delete_e

      element
    end

    # args
    #   ip_list
    def installation_sptn_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args.delete 'main_ip'

        if ip.to_s.include? ':'
          ip, main_ip = ip.to_s.split(':', 2).map {|x| x.strip}

          args['ip'] = ip
          args['main_ip'] = main_ip
        else
          args['ip'] = ip
        end

        element << installation_sptn(args)
      end

      element
    end

    # args
    #   name, ip, home, database
    #   shutdown_cmdline, tmpdir, database_name, restore_database_cmdline
    #   db(type:ip:port:sid:user:password)
    def restore_iptn_database args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']
      element.attributes['database'] = args['database']

      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/database_%s' % Time.now.timestamp_day

      # 关闭网管

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭网管'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = args['shutdown_cmdline'] || 'shutdown-console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['skipfail'] = true

      element << cmdline_e

      # 重启数据库

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:重启数据库'
      function_e.attributes['home'] = '${home}'
      function_e.attributes['db'] = args['db'].to_s.nil
      function_e.attributes['function'] = 'netnumen_database_restart'

      element << function_e

      # 拷贝数据文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝数据文件'
      copy_e.attributes['path'] = args['database']
      copy_e.attributes['to_path'] = File.join '${tmpdir}', args['database_name'] || 'database_backup.zip'

      element << copy_e

      # 恢复数据

      default_cmdline = 'dbtool.bat -dbms:mssql -ip:${ip} -port:1433 -user:sa -pwd:sa -restoreems:%s' % File.join('${tmpdir}', args['database_name'] || 'database_backup.zip')

      if args['db'].to_s.nil.nil?
        list = args['db'].to_s.split(':').map {|x| x.strip.nil}

        db_type     = list[0]
        db_ip       = list[1]
        db_port     = list[2]
        db_sid      = list[3]
        db_user     = list[4]
        db_password = list[5]

        default_cmdline = 'dbtool.bat -dbms:%s -ip:%s -port:%s -user:%s -pwd:%s -restoreems:%s' % [db_type, db_ip, db_port, db_user, db_password, File.join('${tmpdir}', args['database_name'] || 'database_backup.zip')]
      end

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:恢复数据'
      cmdline_e.attributes['home'] = '${home}/ums-server/utils/dbtool'
      cmdline_e.attributes['cmdline'] = args['restore_database_cmdline'] || default_cmdline
      cmdline_e.attributes['callback'] = 'netnumen_restore_database'

      element << cmdline_e

      # 清除临时文件

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除临时文件'
      delete_e.attributes['path'] = '${tmpdir}'
      delete_e.attributes['ensure'] = true
      delete_e.attributes['skipfail'] = true

      element << delete_e

      element
    end

    # args
    #   ip_list
    def restore_iptn_database_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << restore_iptn_database(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   shutdown_cmdline, tmpdir, database, database_name, restore_database_cmdline
    #   db(type:ip:port:sid:user:password)
    def restore_sptn_database args = nil
      restore_iptn_database args
    end

    # args
    #   ip_list
    def restore_sptn_database_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << restore_sptn_database(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   cmdline, shutdown_cmdline
    def start_iptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']

      # 关闭网管

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭网管'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = args['shutdown_cmdline'] || 'shutdown-console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['skipfail'] = true

      element << cmdline_e

      # 重启数据库

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:重启数据库'
      function_e.attributes['home'] = '${home}'
      function_e.attributes['function'] = 'netnumen_database_restart'

      element << function_e

      # 启动网管

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:启动网管'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = args['cmdline'] || 'console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_start_server'
      cmdline_e.attributes['expired'] = '1800'
      cmdline_e.attributes['async'] = 'All processes started'

      element << cmdline_e

      element
    end

    # args
    #   ip_list
    def start_iptn_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << start_iptn(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   cmdline, shutdown_cmdline
    def start_sptn args = nil
      start_iptn args
    end

    # args
    #   ip_list
    def start_sptn_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << start_sptn(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   server_ip, cmdline
    def start_iptn_client args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']

      # 关闭客户端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭客户端'
      cmdline_e.attributes['home'] = '${home}/ums-client'
      cmdline_e.attributes['cmdline'] = nil
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_client'
      cmdline_e.attributes['skipfail'] = true

      element << cmdline_e

      # 启动客户端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:启动客户端'
      cmdline_e.attributes['home'] = '${home}/ums-client/procs/bsf/core/bin'
      cmdline_e.attributes['cmdline'] = args['cmdline'] || ('run.bat -serverip %s -username admin -password ""' % (args['server_ip'] || '127.0.0.1'))
      cmdline_e.attributes['callback_finish'] = 'netnumen_start_client'
      cmdline_e.attributes['expired'] = '1800'
      cmdline_e.attributes['async'] = 'EMB Started'

      element << cmdline_e

      element
    end

    # args
    #   ip_list
    def start_iptn_client_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << start_iptn_client(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   cmdline
    def close_iptn args = nil
      args ||= {}

      # 关闭服务端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = args['name']
      cmdline_e.attributes['ip'] = args['ip']
      cmdline_e.attributes['home'] = File.join args['home'], 'ums-server'

      cmdline_e.attributes['cmdline'] = args['cmdline'] || 'shutdown-console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['ensure'] = true
      cmdline_e.attributes['skipfail'] = true

      cmdline_e
    end

    # args
    #   ip_list
    def close_iptn_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << close_iptn(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   cmdline
    def close_sptn args = nil
      args ||= {}

      # 关闭控制器

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = args['name']
      cmdline_e.attributes['ip'] = args['ip']
      cmdline_e.attributes['home'] = File.join args['home'], 'ums-server'

      cmdline_e.attributes['cmdline'] = args['cmdline'] || 'shutdown-console.bat'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['ensure'] = true
      cmdline_e.attributes['skipfail'] = true

      cmdline_e
    end

    # args
    #   ip_list
    def close_sptn_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << close_sptn(args)
      end

      element
    end

    # args
    #   name, ip, home
    def close_iptn_client args = nil
      args ||= {}

      # 关闭客户端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = args['name']
      cmdline_e.attributes['ip'] = args['ip']
      cmdline_e.attributes['home'] = File.join args['home'], 'ums-client'

      cmdline_e.attributes['cmdline'] = nil
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_client'
      cmdline_e.attributes['ensure'] = true
      cmdline_e.attributes['skipfail'] = true

      cmdline_e
    end

    # args
    #   ip_list
    def close_iptn_client_list args = nil
      args ||= {}

      ip_list = args['ip_list'].to_s.nil
      args.delete 'ip_list'

      if not ip_list.nil?
        ip_list = ip_list.split(',').map {|x| x.nil}.uniq
      end

      element = REXML::Element.new 'parallel'

      ip_list.to_array.each do |ip|
        args['ip'] = ip

        element << close_iptn_client(args)
      end

      element
    end

    # args
    #   name, ip, home
    #   table_external_editors, common_vbs, tmpdir, clean
    #   addins, results_location, resources_libraries, recovery
    #   run_settings_iteration_mode, run_settings_start_iteration, run_settings_end_iteration, run_settings_on_error
    #   path, expired
    #
    #   server_ip, ems_home, log_home
    def quicktest args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip'].to_s.nil
      element.attributes['home'] = args['home']
      element.attributes['skipfail'] = true

      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/autotest_%s' % Time.now.timestamp_day

      paths = {}

      REXML::XPath.each args[:__element__], 'path' do |e|
        file = e.attributes['name'].to_s.strip

        if Excel::Application.excel? file
          home = e.attributes['home'].to_s.nil

          begin
            application = Excel::Application.new
            workbook = application.open File.join(args['home'], file)

            if not workbook.nil?
              sht = workbook.worksheet 1
              data = sht.data

              workbook.close

              if data.size > 3
                if home.nil?
                  home = data[1][0]
                end

                dirname = ''

                data.each_with_index do |x, index|
                  if index < 2
                    next
                  end

                  if not x[1].empty?
                    dirname = x[1]

                    next
                  end

                  if x[3].to_i == 1 and not x[2].empty?
                    paths[File.join(home, dirname, x[2])] = x[4]
                  end
                end
              end
            end

            application.quit
          rescue
          end
        else
          paths[file] = e.attributes['expired']
        end
      end

      # 设置测试环境

      if args.has_key? 'table_external_editors'
        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:设置测试环境'
        function_e.attributes['home'] = '${tmpdir}'
        function_e.attributes['table_external_editors'] = args['table_external_editors']
        function_e.attributes['function'] = 'quicktest_table_external_editors'

        element << function_e
      end

      # 拷贝测试用例基础文件

      libs = nil

      if args.has_key? 'common_vbs'
        args['common_vbs'].to_s.strip.split(',').each do |dirname|
          copy_e = REXML::Element.new 'copy'

          copy_e.attributes['name'] = '${name}:拷贝测试用例基础文件:%s' % dirname
          copy_e.attributes['path'] = File.join '${home}', dirname
          copy_e.attributes['to_path'] = File.join '${tmpdir}', dirname

          element << copy_e

          libs ||= []
          libs << File.join(dirname, '**/*.vbs')
        end
      end

      list_sequence = REXML::Element.new 'list_sequence'
      list_sequence.attributes['name'] = '${name}:测试用例'

      paths.each do |path, expired|
        # 创建测试用例

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:创建:%s' % path
        function_e.attributes['home'] = '${tmpdir}'
        function_e.attributes['path'] = path

        function_e.attributes['function'] = 'quicktest_create'

        list_sequence << function_e

        # 拷贝测试用例

        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝:%s' % path
        copy_e.attributes['path'] = File.join '${home}', path
        copy_e.attributes['to_path'] = File.join '${tmpdir}', path

        list_sequence << copy_e

        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝:%s' % File.join(File.dirname(path), '*.{xls,xlsx}')
        copy_e.attributes['path'] = File.join '${home}', File.join(File.dirname(path), '*.{xls,xlsx}')
        copy_e.attributes['to_path'] = File.join '${tmpdir}', File.dirname(path)

        list_sequence << copy_e

        # 执行测试用例

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:执行:%s' % path
        function_e.attributes['home'] = '${tmpdir}'
        function_e.attributes['path'] = path
        function_e.attributes['expired'] = expired

        if args.has_key? 'addins'
          function_e.attributes['addins'] = args['addins']
        end

        if args.has_key? 'results_location'
          function_e.attributes['results_location'] = args['results_location']
        end

        if args.has_key? 'resources_libraries'
          function_e.attributes['resources_libraries'] = args['resources_libraries']
        else
          if not libs.nil?
            function_e.attributes['resources_libraries'] = libs.join ','
          end
        end

        if args.has_key? 'recovery'
          function_e.attributes['recovery'] = args['recovery']
        end

        if args.has_key? 'run_settings_iteration_mode'
          function_e.attributes['run_settings_iteration_mode'] = args['run_settings_iteration_mode']
        end

        if args.has_key? 'run_settings_start_iteration'
          function_e.attributes['run_settings_start_iteration'] = args['run_settings_start_iteration']
        end

        if args.has_key? 'run_settings_end_iteration'
          function_e.attributes['run_settings_end_iteration'] = args['run_settings_end_iteration']
        end

        if args.has_key? 'run_settings_on_error'
          function_e.attributes['run_settings][:on_error'] = args['run_settings_on_error']
        end

        function_e.attributes['function'] = 'quicktest'

        if args.has_key? 'server_ip' and args.has_key? 'ems_home'
          function_e.attributes['server_ip'] = args['server_ip']
          function_e.attributes['ems_home'] = args['ems_home']
        end

        list_sequence << function_e

        # 生成测试报告

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:生成测试报告:%s' % path
        function_e.attributes['home'] = '.'
        function_e.attributes['path'] = path
        function_e.attributes['autotest_home'] = '${tmpdir}'
        function_e.attributes['localhost'] = true

        function_e.attributes['client_ip'] = '${ip}'

        if args.has_key? 'server_ip' and args.has_key? 'ems_home'
          function_e.attributes['server_ip'] = args['server_ip']
          function_e.attributes['ems_home'] = args['ems_home']
        end

        function_e.attributes['log_home'] = args['log_home']
        function_e.attributes['function'] = 'quicktest_report'
        function_e.attributes['ensure'] = true

        list_sequence << function_e
      end

      element << list_sequence

      if args['clean'].to_s.boolean(false)
        # 清除测试用例

        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = '${name}:清除测试用例'
        delete_e.attributes['path'] = '${tmpdir}'
        delete_e.attributes['ensure'] = true
        delete_e.attributes['skipfail'] = true

        element << delete_e

        # 清除测试日志

        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = '${name}:清除测试日志'
        delete_e.attributes['path'] = File.dirname QUICKTEST_FILENAME_TESTLOG
        delete_e.attributes['ensure'] = true
        delete_e.attributes['skipfail'] = true

        element << delete_e

        # 重置测试日志文件

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:重置测试日志文件'
        function_e.attributes['filename'] = QUICKTEST_FILENAME_TESTLOG
        function_e.attributes['function'] = 'reset_file'
        function_e.attributes['ensure'] = true
        function_e.attributes['skipfail'] = true

        element << function_e
      end

      # 汇总测试报告

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:汇总测试报告 - ${ip}'
      function_e.attributes['home'] = args['log_home']
      function_e.attributes['localhost'] = true

      function_e.attributes['client_ip'] = '${ip}'
      function_e.attributes['function'] = 'compare_index_client'
      function_e.attributes['ensure'] = true

      element << function_e

      element
    end

    # args
    #   name, home
    def compare_index args = nil
      args ||= {}

      # 汇总测试报告

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = args['name']
      function_e.attributes['home'] = args['home']
      function_e.attributes['function'] = 'compare_index'
      function_e.attributes['ensure'] = true

      function_e
    end

    # args
    #   name, home, anodes, cnodes
    def cluster_settings args = nil
      args ||= {}

      anodes = args['anodes'].to_s.split(',').map {|x| x.strip}.sort.uniq
      cnodes = args['cnodes'].to_s.split(',').map {|x| x.strip}.sort.uniq

      # 配置集群信息

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['home'] = args['home']

      anodes.each do |ip|
        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:%s' % ip
        function_e.attributes['home'] = '${home}'
        function_e.attributes['ip'] = ip
        function_e.attributes['anodes'] = anodes.join ','
        function_e.attributes['cnodes'] = cnodes.join ','
        function_e.attributes['function'] = 'netnumen_sptn_cluster_settings'

        element << function_e
      end

      cnodes.each do |ip|
        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:%s' % ip
        function_e.attributes['home'] = '${home}'
        function_e.attributes['ip'] = ip
        function_e.attributes['anodes'] = anodes.join ','
        function_e.attributes['cnodes'] = cnodes.join ','
        function_e.attributes['function'] = 'netnumen_sptn_cluster_settings'

        element << function_e
      end

      element
    end
  end
end