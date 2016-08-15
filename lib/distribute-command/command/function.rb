module DistributeCommand
  module Function
    module_function

    COMPARE_INDEX_FILE = 'index.yml'
    INDEX_HTML_FILE = 'index.html'

    def netnumen_sptn_settings args = nil
      args ||= {}

      home = File.expand_path args['home'].nil || '.'

      if File.directory? home
        if args.has_key? 'main_ip'
          file = File.join home, 'ums-server/works/global/deploy/deploy-usf.properties'

          if File.file? file
            lines = []

            IO.readlines(file).each do |line|
              line.strip!

              case
              when line =~ /^odl\.IsDController\s*=/
                lines << 'odl.IsDController=true'
              when line =~ /^usf\.system\.pmf\s*=/
                lines << 'usf.system.pmf=true'
              when line =~ /^usf\.pmf\.main\.ip\s*=/
                lines << 'usf.pmf.main.ip=%s' % args['main_ip']
              when line =~ /^usf\.env\.pmf\.nonjava\.sendmsg\s*=/
                lines << 'usf.env.pmf.nonjava.sendmsg=true'
              when line =~ /^\/ems\/encryptable\/peerUserPassword\s*=/
                lines << '/ems/encryptable/peerUserPassword=3A2939C038F001272249CCF12AF74F48'
              else
                lines << line
              end
            end

            File.open file, 'w' do |f|
              f.puts lines
            end
          end
        end

        true
      else
        $errors ||= []
        $errors << 'no such directory - %s' % home

        false
      end
    end

    def netnumen_database_restart args = nil
      database_name, database_home = System::database_info

      if not database_name.nil?
        if OS::windows?
          CommandLine::cmdline 'sc stop %s' % database_name do |line, stdin, wait_thr|
            if block_given?
              yield line
            end
          end

          30.times do |i|
            if 'STOPPED' == System::service_state(database_name)
              break
            end

            sleep 10
          end

          CommandLine::cmdline 'sc start %s' % database_name do |line, stdin, wait_thr|
            if block_given?
              yield line
            end
          end

          30.times do |i|
            if 'RUNNING' == System::service_state(database_name)
              break
            end

            sleep 10
          end
        end
      end

      true
    end

    def quicktest_table_external_editors args = nil
      args ||= {}

      if args.has_key? 'table_external_editors'
        list = args['table_external_editors'].split(',').map {|x| x.strip}

        quicktest = QuickTest.new

        if not quicktest.table_external_editors list
          return false
        end
      end

      true
    end

    def quicktest_create args = nil
      args ||= {}

      path = File.expand_path File.join(args['home'].nil || '.', args['path'])

      if not File.mkdir path
        return false
      end

      if File.directory? path
        quicktest = QuickTest.new

        if not quicktest.create path
          return false
        end
      end

      true
    end

    def quicktest args = nil
      args ||= {}

      home = File.expand_path args['home'].nil || '.'

      if File.directory? home
        opt = {}

        if args.has_key? 'addins'
          opt[:addins] = args['addins'].split(',').map {|x| x.strip}
        end

        if not args['results_location'].nil?
          opt[:results_location] = File.join home, args['results_location']
        end

        if args.has_key? 'resources_libraries'
          opt[:resources_libraries] = args['resources_libraries'].split(',').map {|x| File.join home, x.strip}
        end

        if args.has_key? 'recovery'
          opt[:recovery] = {}

          args['recovery'].split(',').map {|x| x.strip}.each do |scenario|
            scenario_file, scenario_name = scenario.split(':', 2).map {|x| x.strip}

            opt[:recovery][File.join(home, scenario_file)] = scenario_name
          end
        end

        if args.has_key? 'run_settings_iteration_mode'
          opt[:run_settings] ||= {}
          opt[:run_settings][:iteration_mode] = args['run_settings_iteration_mode']
        end

        if args.has_key? 'run_settings_start_iteration'
          opt[:run_settings] ||= {}
          opt[:run_settings][:start_iteration] = args['run_settings_start_iteration'].to_i
        end

        if args.has_key? 'run_settings_end_iteration'
          opt[:run_settings] ||= {}
          opt[:run_settings][:end_iteration] = args['run_settings_end_iteration'].to_i
        end

        if args.has_key? 'run_settings_on_error'
          opt[:run_settings] ||= {}
          opt[:run_settings][:on_error] = args['run_settings_on_error']
        end

        if args.has_key? 'path'
          path = File.expand_path File.join(home, args['path'])
          expired = args['expired'].to_i

          if File.directory? path
            quicktest = QuickTest.new opt

            begin
              if not quicktest.open
                return false
              end

              drb = nil
              info = nil
              lineno = 0

              if File.file? File.join(path, QUICKTEST_FILENAME_CHECK)
                if File.file? QUICKTEST_FILENAME_TESTLOG
                  lineno = IO.readlines(QUICKTEST_FILENAME_TESTLOG).size
                end
              end

              if File.file? File.join(path, QUICKTEST_FILENAME_QX)
                if args.has_key? 'server_ip' and args.has_key? 'ems_home'
                  drb = DRb::Object.new

                  if drb.connect args['server_ip']
                    info = drb.netnumen_quicktest args['ems_home']
                  else
                    drb.close
                    drb = nil
                  end
                end
              end

              status = quicktest.exec path, expired

              quicktest.last_run_results.each do |line|
                if block_given?
                  yield line
                end
              end

              if File.file? File.join(path, QUICKTEST_FILENAME_QX)
                if not drb.nil? and not info.nil?
                  map = drb.netnumen_quicktest_finish args['ems_home'], info

                  drb.close
                  drb = nil

                  if not map.nil?
                    File.open File.join(path, QUICKTEST_FILENAME_MSG), 'w' do |f|
                      map.each do |k, v|
                        f.puts v.last.locale
                        f.puts
                      end
                    end
                  end
                end
              end

              if File.file? File.join(path, QUICKTEST_FILENAME_CHECK)
                if File.file? QUICKTEST_FILENAME_TESTLOG
                  lines = IO.readlines(QUICKTEST_FILENAME_TESTLOG)[lineno..-1]

                  File.open File.join(path, QUICKTEST_FILENAME_LOG), 'w' do |f|
                    f.puts lines
                  end
                end
              end

              if not status
                return false
              end
            ensure
              quicktest.close
            end

            true
          else
            $errors ||= []
            $errors << 'no such directory - %s' % path

            false
          end
        else
          false
        end
      else
        $errors ||= []
        $errors << 'no such directory - %s' % home

        false
      end
    end

    def quicktest_report args = nil
      args ||= {}

      status = true

      home = File.expand_path File.join(args['log_home'] || File.join(Dir.pwd, Time.now.strftime('%Y%m%d')), args['client_ip'].to_s)

      info = {}
      index_file = File.join home, COMPARE_INDEX_FILE

      if File.file? index_file
        begin
          info = YAML.load_file index_file

          if not info.kind_of? Hash
            info = {}
          end
        rescue
          info = {}
        end
      end

      File.lock index_file, 'w:utf-8' do |file|
        path = args['path']

        quicktest_results_file = File.join home, path, QUICKTEST_FILENAME_RESULTS
        quicktest_results = nil

        if args.has_key? 'client_ip' and args.has_key? 'autotest_home'
          drb = DRb::Object.new

          if drb.connect args['client_ip']
            if not drb.copy_remote File.join(home, path), File.join(args['autotest_home'], path), '*.{log,yml}'
              status = false
            else
              File.mkdir File.join(home, path)
            end

            if File.file? quicktest_results_file
              begin
                quicktest_results = YAML.load_file quicktest_results_file

                if not quicktest_results.kind_of? Hash
                  quicktest_results = nil
                end
              rescue
                quicktest_results = nil
              end
            end

            if not quicktest_results.nil?
              if not quicktest_results['execute']
                if not drb.copy_remote File.join(home, path), File.join(args['autotest_home'], path), quicktest_results['location']
                  status = false
                end
              end
            end
          else
            status = false
          end

          drb.close
          drb = nil
        end

        if status
          if File.glob(File.join(home, 'asn1/*.jar')).empty?
            if args.has_key? 'server_ip' and args.has_key? 'ems_home'
              drb = DRb::Object.new

              if drb.connect args['server_ip']
                if not drb.copy_remote File.join(home, 'asn1'), args['ems_home'], 'ums-server/procs/ppus/bnplatform.ppu/platform-api.pmu/bn_finterface_api.par/*.jar' do |name|
                    File.basename(name)
                  end

                  status = false
                end

                if not drb.copy_remote File.join(home, 'asn1'), args['ems_home'], 'ums-server/procs/ppus/bn.ppu/bn-commonservice.pmu/bn-qxinterface-api.par/**/*.jar' do |name|
                    File.basename(name)
                  end

                  status = false
                end
              else
                status = false
              end

              drb.close
              drb = nil
            end

            if not status
              File.delete File.join(home, 'asn1')
            end
          end
        end

        if File.directory? File.join(home, 'asn1')
          ASN1::Asn1::import File.glob(File.join(home, 'asn1/**/*.jar')), true
        end

        if quicktest_results.nil?
          if File.file? quicktest_results_file
            begin
              quicktest_results = YAML.load_file quicktest_results_file

              if not quicktest_results.kind_of? Hash
                quicktest_results = nil
              end
            rescue
              quicktest_results = nil
            end
          end
        end

        compare = ASN1::Compare.new
        compare.name = path
        compare.compare_html File.join(home, path)

        info[path] = {
          'index'   => info.size + 1,
          'execute' => nil,
          'compare' => compare.compare_results[path]
        }

        if not quicktest_results.nil?
          info[path]['execute'] = quicktest_results['execute']

          quicktest_results['index'] = info[path]['index']
          quicktest_results['compare'] = info[path]['compare']

          File.open quicktest_results_file, 'w:utf-8' do |f|
            f.puts quicktest_results.to_yaml
          end
        end

        puts quicktest_results.to_string
        puts info.to_string

        file.puts info.to_yaml
      end

      status
    end

    def compare_index_client args = nil
      args ||= {}

      home = File.expand_path File.join(args['home'] || File.join(Dir.pwd, Time.now.strftime('%Y%m%d')), args['client_ip'].to_s)

      if File.directory? home
        Dir.chdir home do
          File.open INDEX_HTML_FILE, 'w' do |f|
          end
        end
      end

      true
    end

    def compare_index args = nil
      args ||= {}

      home = File.expand_path args['home'] || File.join(Dir.pwd, Time.now.strftime('%Y%m%d'))

      if File.directory? home
        Dir.chdir home do
          File.open INDEX_HTML_FILE, 'w' do |f|
          end
        end
      end

      true
    end
  end
end