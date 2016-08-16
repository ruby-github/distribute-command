module DistributeCommand
  module Template
    module_function

    # args
    #   name, ip, home, installation_home, silencefile, license
    #   cmdline, uninstall_cmdline, tmpdir, skip, installation_home_patch, ems_locale
    #   client, server
    def installation_iptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']
      element.attributes['installation_home'] = args['installation_home']
      element.attributes['silencefile'] = args['silencefile']

      element.attributes['cmdline'] = args['cmdline'] || 'setup.bat d: silenceinstall-for-localhost.xml false'
      element.attributes['uninstall_cmdline'] = args['uninstall_cmdline'] || 'shutdown-console.bat'
      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/installation'

      if args.has_key? 'license'
        element.attributes['license'] = args['license']
      end

      if args.has_key? 'skip'
        element.attributes['skip'] = args['skip']
      end

      if args.has_key? 'installation_home_patch'
        element.attributes['installation_home_patch'] = args['installation_home_patch']
      end

      # 卸载

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:卸载'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = '${uninstall_cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_uninstall'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

      # 拷贝文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝安装盘'
      copy_e.attributes['path'] = '${installation_home}'
      copy_e.attributes['to_path'] = '${tmpdir}'

      element << copy_e

      if args.has_key? 'installation_home_patch'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝安装盘补丁'
        copy_e.attributes['path'] = '${installation_home_patch}'
        copy_e.attributes['to_path'] = '${tmpdir}'

        element << copy_e
      end

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝静默安装文件'
      copy_e.attributes['path'] = '${silencefile}'
      copy_e.attributes['to_path'] = '${tmpdir}/conf/silenceinstall-for-localhost.xml'
      copy_e.attributes['install_home'] = '${home}'
      copy_e.attributes['callback'] = 'netnumen_update_silenceinstall'

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

      if args['client'] != 'true'
        # 重启数据库

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:重启数据库'
        function_e.attributes['home'] = '${home}'
        function_e.attributes['function'] = 'netnumen_database_restart'

        element << function_e
      end

      # 安装

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:安装'
      cmdline_e.attributes['home'] = '${tmpdir}'
      cmdline_e.attributes['cmdline'] = '${cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_install'

      element << cmdline_e

      if args.has_key? 'license'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝license'
        copy_e.attributes['path'] = '${license}'
        copy_e.attributes['to_path'] = '${home}/ums-server/works/main/deploy/ums-license.LCS'

        element << copy_e
      end

      # 清除

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除'
      delete_e.attributes['path'] = '${tmpdir}'
      delete_e.attributes['ensure'] = 'true'
      delete_e.attributes['skipfail'] = 'true'

      element << delete_e

      element
    end

    # args
    #   name, ip, home, installation_home, silencefile, license
    #   cmdline, uninstall_cmdline, tmpdir, skip, installation_home_patch, main_ip, ems_locale
    def installation_sptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']
      element.attributes['installation_home'] = args['installation_home']
      element.attributes['silencefile'] = args['silencefile']

      element.attributes['cmdline'] = args['cmdline'] || 'setup.bat d: silenceinstall-for-localhost.xml false'
      element.attributes['uninstall_cmdline'] = args['uninstall_cmdline'] || 'shutdown-console.bat'
      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/installation'

      if args.has_key? 'license'
        element.attributes['license'] = args['license']
      end

      if args.has_key? 'skip'
        element.attributes['skip'] = args['skip']
      end

      if args.has_key? 'installation_home_patch'
        element.attributes['installation_home_patch'] = args['installation_home_patch']
      end

      if args.has_key? 'main_ip'
        element.attributes['main_ip'] = args['main_ip']
      end

      # 卸载

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:卸载'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = '${uninstall_cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_uninstall'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

      # 拷贝文件

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝安装盘'
      copy_e.attributes['path'] = '${installation_home}'
      copy_e.attributes['to_path'] = '${tmpdir}'

      element << copy_e

      if args.has_key? 'installation_home_patch'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝安装盘补丁'
        copy_e.attributes['path'] = '${installation_home_patch}'
        copy_e.attributes['to_path'] = '${tmpdir}'

        element << copy_e
      end

      copy_e = REXML::Element.new 'copy'

      copy_e.attributes['name'] = '${name}:拷贝静默安装文件'
      copy_e.attributes['path'] = '${silencefile}'
      copy_e.attributes['to_path'] = '${tmpdir}/conf/silenceinstall-for-localhost.xml'
      copy_e.attributes['install_home'] = '${home}'
      copy_e.attributes['callback'] = 'netnumen_update_silenceinstall'

      if args.has_key? 'ems_locale'
        copy_e.attributes['ems_locale'] = args['ems_locale']
      end

      copy_e.attributes['server'] = 'true'

      element << copy_e

      # 重启数据库

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:重启数据库'
      function_e.attributes['home'] = '${home}'
      function_e.attributes['function'] = 'netnumen_database_restart'

      element << function_e

      # 安装

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:安装'
      cmdline_e.attributes['home'] = '${tmpdir}'
      cmdline_e.attributes['cmdline'] = '${cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_install'

      element << cmdline_e

      if args.has_key? 'license'
        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝license'
        copy_e.attributes['path'] = '${license}'
        copy_e.attributes['to_path'] = '${home}/ums-server/works/main/deploy/ums-license.LCS'

        element << copy_e
      end

      # 配置

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:配置'
      function_e.attributes['home'] = '${home}'
      function_e.attributes['function'] = 'netnumen_sptn_settings'

      if args.has_key? 'main_ip'
        function_e.attributes['main_ip'] = '${main_ip}'
      end

      element << function_e

      # 清除

      delete_e = REXML::Element.new 'delete'

      delete_e.attributes['name'] = '${name}:清除'
      delete_e.attributes['path'] = '${tmpdir}'
      delete_e.attributes['ensure'] = 'true'
      delete_e.attributes['skipfail'] = 'true'

      element << delete_e

      element
    end

    # args
    #   ip_list
    def installation_iptn_list args = nil
      args ||= {}

      element_list = []

      if args.has_key? 'ip_list'
        ip_list = args.delete('ip_list').split(',').map {|x| x.strip}

        ip_list.each do |ip|
          args_dup = args.dup
          args_dup['ip'] = ip

          element_list << installation_iptn(args_dup)
        end
      end

      element_list
    end

    # args
    #   ip_list
    def installation_sptn_list args = nil
      args ||= {}

      element_list = []

      if args.has_key? 'ip_list'
        ip_list = args.delete('ip_list').split(',').map {|x| x.strip}

        ip_list.each do |ip|
          args_dup = args.dup

          if ip.include? ':'
            ip, main_ip = ip.split(':', 2).map {|x| x.strip}

            args_dup['ip'] = ip
            args_dup['main_ip'] = main_ip
          else
            args_dup['ip'] = ip
          end

          element_list << installation_sptn(args_dup)
        end
      end

      element_list
    end

    # args
    #   name, ip, home
    #   cmdline, shutdown_cmdline, tmpdir, database, restore_database_cmdline
    def start_iptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']

      element.attributes['cmdline'] = args['cmdline'] || 'start console.bat'
      element.attributes['shutdown_cmdline'] = args['shutdown_cmdline'] || 'shutdown-console.bat'
      element.attributes['tmpdir'] = args['tmpdir'] || 'd:/installation'

      if args.has_key? 'database'
        element.attributes['install_database'] = args['database']
        element.attributes['database_name'] = args['database_name'] || 'database_backup.zip'
        element.attributes['database'] = '${tmpdir}/${database_name}'
        element.attributes['restore_database_cmdline'] = args['restore_database_cmdline'] || 'dbtool.bat -dbms:mssql -ip:${ip} -port:1433 -user:sa -pwd:sa -restoreems:${database}'
      end

      # 关闭

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = '${shutdown_cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

      if args.has_key? 'database'
        # 重启数据库

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:重启数据库'
        function_e.attributes['home'] = '${home}'
        function_e.attributes['function'] = 'netnumen_database_restart'

        element << function_e

        # 拷贝数据文件

        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝数据文件'
        copy_e.attributes['path'] = '${install_database}'
        copy_e.attributes['to_path'] = '${database}'

        element << copy_e

        # 恢复数据

        cmdline_e = REXML::Element.new 'cmdline'

        cmdline_e.attributes['name'] = '${name}:恢复数据'
        cmdline_e.attributes['home'] = '${home}/ums-server/utils/dbtool'
        cmdline_e.attributes['cmdline'] = '${restore_database_cmdline}'
        cmdline_e.attributes['callback'] = 'netnumen_restore_database'

        element << cmdline_e

        # 清除数据文件

        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = '${name}:清除数据文件'
        delete_e.attributes['path'] = '${tmpdir}'
        delete_e.attributes['ensure'] = 'true'
        delete_e.attributes['skipfail'] = 'true'

        element << delete_e
      end

      # 启动

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:启动'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = '${cmdline}'
      cmdline_e.attributes['expired'] = '1800'
      cmdline_e.attributes['callback_finish'] = 'netnumen_start_server'

      element << cmdline_e

      element
    end

    # args
    #   name, ip, home
    #   cmdline, shutdown_cmdline, tmpdir, database, restore_database_cmdline
    def start_sptn args = nil
      start_iptn args
    end

    # args
    #   name, ip, home, server_ip
    #   cmdline
    def start_iptn_client args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']
      element.attributes['server_ip'] = args['server_ip'] || '127.0.0.1'

      element.attributes['cmdline'] = args['cmdline'] || 'start run.bat -serverip ${server_ip} -username admin -password ""'

      # 关闭客户端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭客户端'
      cmdline_e.attributes['home'] = '${home}/ums-client'
      cmdline_e.attributes['cmdline'] = nil
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_client'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

      # 启动

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:启动'
      cmdline_e.attributes['home'] = '${home}/ums-client/procs/bsf/core/bin'
      cmdline_e.attributes['cmdline'] = '${cmdline}'
      cmdline_e.attributes['expired'] = '1800'
      cmdline_e.attributes['callback_finish'] = 'netnumen_start_client'

      element << cmdline_e

      element
    end

    # args
    #   name, ip, home
    #   cmdline
    def close_iptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']

      element.attributes['cmdline'] = args['cmdline'] || 'shutdown-console.bat'

      # 关闭服务端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭服务端'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = '${cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['ensure'] = 'true'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

      element
    end

    # args
    #   name, ip, home
    #   cmdline
    def close_sptn args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']

      element.attributes['cmdline'] = args['cmdline'] || 'shutdown-console.bat'

      # 关闭

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭'
      cmdline_e.attributes['home'] = '${home}/ums-server'
      cmdline_e.attributes['cmdline'] = '${cmdline}'
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_server'
      cmdline_e.attributes['ensure'] = 'true'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

      element
    end

    # args
    #   name, ip, home
    def close_iptn_client args = nil
      args ||= {}

      element = REXML::Element.new 'sequence'

      element.attributes['name'] = args['name']
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']

      # 关闭客户端

      cmdline_e = REXML::Element.new 'cmdline'

      cmdline_e.attributes['name'] = '${name}:关闭客户端'
      cmdline_e.attributes['home'] = '${home}/ums-client'
      cmdline_e.attributes['cmdline'] = nil
      cmdline_e.attributes['callback_finish'] = 'netnumen_close_client'
      cmdline_e.attributes['ensure'] = 'true'
      cmdline_e.attributes['skipfail'] = 'true'

      element << cmdline_e

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
      element.attributes['ip'] = args['ip']
      element.attributes['home'] = args['home']

      element.attributes['tmpdir'] = args['tmpdir'] || File.join('d:/autotest_home', Time.now.strftime('%Y%m%d'))

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

      list_element = REXML::Element.new 'list'
      list_element.attributes['name'] = '${name}:测试用例'

      paths.each do |path, expired|
        # 创建测试用例

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:创建:%s' % path
        function_e.attributes['home'] = '${tmpdir}'
        function_e.attributes['path'] = path

        function_e.attributes['function'] = 'quicktest_create'

        list_element << function_e

        # 拷贝测试用例

        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝:%s' % path
        copy_e.attributes['path'] = File.join '${home}', path
        copy_e.attributes['to_path'] = File.join '${tmpdir}', path

        list_element << copy_e

        copy_e = REXML::Element.new 'copy'

        copy_e.attributes['name'] = '${name}:拷贝:%s' % File.join(File.dirname(path), '*.{xls,xlsx}')
        copy_e.attributes['path'] = File.join '${home}', File.join(File.dirname(path), '*.{xls,xlsx}')
        copy_e.attributes['to_path'] = File.join '${tmpdir}', File.dirname(path)

        list_element << copy_e

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

        list_element << function_e

        # 生成测试报告

        function_e = REXML::Element.new 'function'

        function_e.attributes['name'] = '${name}:生成测试报告:%s' % path
        function_e.attributes['home'] = '.'
        function_e.attributes['path'] = path
        function_e.attributes['autotest_home'] = '${tmpdir}'

        function_e.attributes['ip'] = '127.0.0.1'
        function_e.attributes['client_ip'] = '${ip}'

        if args.has_key? 'server_ip' and args.has_key? 'ems_home'
          function_e.attributes['server_ip'] = args['server_ip']
          function_e.attributes['ems_home'] = args['ems_home']
        end

        function_e.attributes['log_home'] = args['log_home']
        function_e.attributes['function'] = 'quicktest_report'
        function_e.attributes['ensure'] = 'true'

        list_element << function_e
      end

      element << list_element

      if args['clean'].to_s.boolean(false)
        # 清除测试用例

        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = '${name}:清除测试用例'
        delete_e.attributes['path'] = '${tmpdir}'
        delete_e.attributes['ensure'] = 'true'
        delete_e.attributes['skipfail'] = 'true'

        element << delete_e

        # 清除测试日志

        delete_e = REXML::Element.new 'delete'

        delete_e.attributes['name'] = '${name}:清除测试日志'
        delete_e.attributes['path'] = File.dirname QUICKTEST_FILENAME_TESTLOG
        delete_e.attributes['ensure'] = 'true'
        delete_e.attributes['skipfail'] = 'true'

        element << delete_e
      end

      # 汇总测试报告

      function_e = REXML::Element.new 'function'

      function_e.attributes['name'] = '${name}:汇总测试报告'
      function_e.attributes['home'] = args['log_home']
      function_e.attributes['client_ip'] = '${ip}'
      function_e.attributes['function'] = 'compare_index_client'
      function_e.attributes['ensure'] = 'true'

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
      function_e.attributes['ensure'] = 'true'

      function_e
    end
  end
end