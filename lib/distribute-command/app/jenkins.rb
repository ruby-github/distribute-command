module Jenkins
  module_function

  DASHBOARD_FILE = 'dashboard.yml'
  VERSION_INFO_FILE = 'version_info.yml'

  HTTP_METRIC = 'http://10.41.213.28/WebService/ZTE.Wireline.WebService/BuildAPI.ashx'
  JENKINS_BUILD = 'build --username admin --password admin-1234'

  def buildstart_metric project, night = true
    if $metric
      if night
        buildtype = 'night'
      else
        buildtype = 'CI'
      end

      cmdline = 'curl --data "action=buildstart&project=%s&buildtype=%s" %s' % [project, buildtype, HTTP_METRIC]

      Util::Logger::puts cmdline

      id = nil

      begin
        id = `#{cmdline}`
      rescue
        id = nil
      end

      id
    else
      nil
    end
  end

  def buildend_metric id, status
    if $metric
      if status
        success = 'success'
      else
        success = 'failed'
      end

      if not id.nil?
        cmdline = 'curl --data "action=buildend&buildid=%s&buildresult=%s" %s' % [id, success, HTTP_METRIC]

        Util::Logger::puts cmdline

        system cmdline

        true
      else
        false
      end
    else
      true
    end
  end

  def dashboard_load name
    if File.file? DASHBOARD_FILE
      info = YAML::load_file DASHBOARD_FILE

      if info.is_a? Hash
        info[name] || []
      else
        []
      end
    else
      []
    end
  end

  def dashboard_dump name, list
    info = {}

    if File.file? DASHBOARD_FILE
      info = YAML::load_file DASHBOARD_FILE

      if not info.is_a? Hash
        info = {}
      end
    end

    info[name] = list

    info.each do |k, v|
      v.sort!
      v.uniq!
    end

    File.open DASHBOARD_FILE, 'w:utf-8' do |f|
      f.puts info.to_yaml
    end
  end

  def jenkins_cli cmdline
    jenkins_cli = '/home/user/jenkins/jenkins-cli.jar'

    if not File.file? jenkins_cli
      jenkins_cli = File.join ENV['HOME'].to_s, 'jenkins/jenkins-cli.jar'
    end

    if not File.file? jenkins_cli
      jenkins_cli = File.join ENV['JENKINS_HOME'].to_s, 'jenkins-cli.jar'
    end

    cmd = "java -jar #{File.cmdline(jenkins_cli)} -s http://10.8.9.80:8080 #{cmdline}"

    CommandLine::cmdline cmd do |line, stdin, wait_thr|
      Util::Logger::puts line
    end
  end

  def dashboard_monitor home, username = nil, password = nil
    if not File.directory? home
      Util::Logger::error 'no such directory - %s' % home

      return false
    end

    Dir.chdir home do
      info = {}

      if File.file? VERSION_INFO_FILE
        info = YAML::load_file VERSION_INFO_FILE
      end

      changes = {}
      change_files = {}

      File.glob('*/trunk').each do |dirname|
        version = info[dirname]

        if not SCM::update dirname, nil, nil, username, password
          next
        end

        scm_info = SCM::info dirname, nil, username, password

        if scm_info.nil?
          next
        end

        cur_version = scm_info[:rev].to_s

        if cur_version.nil?
          next
        end

        info[dirname] = cur_version

        if version.nil?
          next
        end

        case SCM::scm(dirname)
        when :svn
          args = '--verbose --quiet --revision %s:HEAD' % version
        when :git
          args = '%s..HEAD' % version.to_s[0..6]
        when :tfs
          args = '%s..HEAD' % version.to_s[0..6]
        else
          args = nil
        end

        map = {}

        logs = SCM::log dirname, args, username, password

        if not logs.nil?
          logs.each do |x|
            if version.to_s == x[:rev].to_s
              next
            end

            x[:change_files].each do |k, v|
              v.each do |path|
                if not path.start_with? 'trunk'
                  path = File.join 'trunk', path
                end

                author = x[:author]

                if author =~ /<(.*)>/
                  author = $`.strip

                  if author.empty?
                    author = $1.strip.gsub "ZTE\\", ''
                  end
                end

                dir = POM::dirname File.join(File.dirname(dirname), path)

                if not dir.nil?
                  if dir.include? 'trunk/code/'
                    map[:java] ||= {}
                    map[:java][dir] ||= []
                    map[:java][dir] << author
                  end

                  if dir.include? 'trunk/sdn/'
                    map[:java] ||= {}
                    map[:java][dir] ||= []
                    map[:java][dir] << author
                  end

                  if dir.include? 'trunk/code_c/'
                    if dir.include? 'trunk/code_c/database/'
                      if File.file? File.join(dirname, 'code_c/database/dbscript/pom.xml')
                        dir_dbscript = File.join dirname, 'code_c/database/dbscript'

                        if File.file? File.join(dir, 'xml/daobuilder.xml')
                          map[:cpp] ||= {}
                          map[:cpp][dir_dbscript] ||= []
                          map[:cpp][dir_dbscript] << author
                        end

                        if not File.directory? File.join(dir_dbscript, 'install')
                          map[:cpp] ||= {}
                          map[:cpp][dir_dbscript] ||= []
                          map[:cpp][dir_dbscript] << author
                        end
                      end
                    end

                    map[:cpp] ||= {}
                    map[:cpp][dir] ||= []
                    map[:cpp][dir] << author
                  end

                  next
                end

                case dirname
                when 'Interface/trunk'
                  if path.include? 'trunk/code/asn/'
                    map[:java] ||= {}
                    map[:java]['Interface/trunk/code/finterface'] ||= []
                    map[:java]['Interface/trunk/code/finterface'] << author

                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/finterface'] ||= []
                    map[:cpp]['Interface/trunk/code_c/finterface'] << author
                  end

                  if path.include? 'trunk/code_c/asn/sdh-wdm/qx-interface/asn/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxinterface'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxinterface'] << author
                  end

                  if path.include? 'trunk/code_c/asn/sdh-wdm/qx-interface/asn5800/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qx5800'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qx5800'] << author
                  end

                  if path.include? 'trunk/code_c/asn/sdh-wdm/qx-interface/asnwdm721/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxwdm721'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxwdm721'] << author
                  end

                  if path.include? 'trunk/code_c/asn/otntlvqx/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxotntlv'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxotntlv'] << author
                  end
                when 'u3_interface/trunk'
                  if path.include? 'trunk/code/asn/'
                    map[:java] ||= {}
                    map[:java]['u3_interface/trunk/sdn/finterface'] ||= []
                    map[:java]['u3_interface/trunk/sdn/finterface'] << author
                  end
                when 'BN_NAF/trunk'
                  if path.include? 'trunk/code_c/adapters/xtncorba/corbaidl/'
                    map[:cpp] ||= {}

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl'] << author

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl2'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl2'] << author
                  end

                  if path.include? 'trunk/code_c/adapters/xtntmfcorba/corbaidl/'
                    map[:cpp] ||= {}

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl'] << author

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl2'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl2'] << author
                  end
                else
                end
              end
            end
          end
        end

        map.each do |lang, lang_info|
          lang_info.each do |path, authors|
            authors.sort!
            authors.uniq!
          end
        end

        if not map.empty?
          change_files[dirname] = map
        end

        map.each do |lang, lang_info|
          dir = nil

          if lang == :java
            if dirname == 'u3_interface/trunk'
              dir = File.join dirname, 'sdn/build'
            else
              dir = File.join dirname, 'code/build'
            end
          end

          if lang == :cpp
            dir = File.join dirname, 'code_c/build'
          end

          if dir.nil? or not File.directory?(dir)
            next
          end

          if File.directory? File.join(dir, 'pom')
            File.glob(File.join(dir, 'pom/*/pom.xml')).each do |file|
              group = File.basename File.dirname(file)

              POM::modules(File.dirname(file)).each do |pom_path|
                lang_info.each do |path, authors|
                  if path.include? 'build/deploy'
                    next
                  end

                  if path == pom_path
                    changes[lang] ||= {}
                    changes[lang][group] ||= {
                      :paths  => [],
                      :authors=> []
                    }

                    if lang == :java
                      changes[lang][group][:paths] << File.join(dir, 'pom', group)
                    else
                      changes[lang][group][:paths] << pom_path
                    end

                    changes[lang][group][:authors] += authors
                  end
                end
              end
            end
          else
            lang_info.each do |path, authors|
              changes[lang] ||= {}
              changes[lang][nil] ||= {
                :paths  => [],
                :authors=> []
              }

              changes[lang][nil][:paths] << dir
              changes[lang][nil][:authors] += authors
            end
          end
        end
      end

      File.open VERSION_INFO_FILE, 'w:utf-8' do |f|
        f.puts info.to_yaml
      end

      changes.each do |lang, group_info|
        group_info.each do |group, path_info|
          path_info[:paths].sort!
          path_info[:paths].uniq!

          path_info[:authors].sort!
          path_info[:authors].uniq!
        end
      end

      Util::Logger::head change_files.to_string
      Util::Logger::head changes.to_string

      changes.each do |lang, group_info|
        group_info.each do |group, path_info|
          if block_given?
            jobname = yield lang, group

            if not jobname.nil?
              params_list = path_info[:paths].join ';'
              params_authors = path_info[:authors].join ';'

              jenkins_cli "#{JENKINS_BUILD} \"#{jobname}\" -p list=\"#{params_list}\" -p authors=\"#{params_authors}\""
            end
          end
        end
      end

      true
    end
  end

  def autopatch_monitor
    home = '/home/workspace/auto/patch'
    os_home = '/home/workspace/jenkins/os'

    if File.directory? home
      Dir.chdir home do
        status = true

        Util::Logger::puts '===== 拷贝补丁申请单 ====='

        File.glob('source/*').each do |dirname|
          if not File.directory? dirname
            File.delete dirname

            next
          end

          name = File.basename dirname

          if name =~ /\((\d+[_\w]*)\)$/
            version = $1

            if version.include? 'stn'
              osnames = ['windows']
            else
              osnames = ['windows', 'windows32', 'linux', 'solaris']
            end

            list = []

            Dir.chdir dirname do
              File.glob('**/*.{xml,zip}').each do |file|
                list << file
              end
            end

            current = true

            list.each do |file|
              osnames.each do |os|
                if not File.copy File.join(dirname, file), File.join('template', version, os, file.downcase) do |src, dest|
                    Util::Logger::info dest

                    [src, dest]
                  end

                  status = false
                  current = false
                end
              end
            end

            if current
              File.delete dirname
            end
          else
            File.delete dirname
          end
        end

        Util::Logger::puts '===== 分发补丁申请单 ====='

        if File.directory? 'template'
          Dir.chdir 'template' do
            File.glob('*/*').each do |dir|
              version = File.dirname dir
              osname = File.basename dir

              xpath = File.join os_home, osname, '{release,dev}', version, 'build/xml'

              File.glob(xpath).each do |path|
                if not File.copy dir, path do |src, dest|
                    Util::Logger::info dest

                    [src, dest]
                  end

                  status = false
                else
                  File.delete dir
                end
              end
            end
          end
        end

        status
      end
    else
      Util::Logger::error 'no such directory - %s' % home

      false
    end
  end

  def scm_change home
    if not File.directory? home
      Util::Logger::error 'no such directory - %s' % home

      return false
    end

    if not OS::windows?
      return true
    end

    Dir.chdir home do
      map = {}

      file = 'BN_NECOMMON/trunk/doc/跨项目代码修改走查/跨项目代码清单.xlsx'

      if not File.file? file
        Util::Logger::error 'no such file - %s' % file

        return false
      end

      begin
        application = Excel::Application.new

        wk = application.open file
        sht = wk.worksheet 1

        data = sht.data
        data.shift
        head = data.shift || []

        data.each do |x|
          x[1].to_s.gsub(';', "\n").lines.each do |line|
            line.strip!

            if line.empty?
              next
            end

            modulename, name = File.normalize(line).split '/', 2

            if name.nil? or not name.start_with? 'trunk'
              Util::Logger::warn 'invalid filename - %s' % line

              next
            end

            map[modulename] ||= {}
            map[modulename][name] = {
              :info   => {
                head[2] => [x[2], x[3], x[4]],
                head[5] => [x[5], x[6], x[7]]
              },
              :change => nil
            }
          end
        end
      rescue
        Util::Logger::exception $!

        return false
      end

      if $start_date
        start_date = '{%s}' % $start_date
      else
        t = Time.now

        if t.day > 15
          start_date = '{%s-%s-%s}' % [t.year, t.month, 1]
        else
          t = t - 31 * 24 * 3600
          start_date = '{%s-%s-%s}' % [t.year, t.month, 16]
        end
      end

      if $finish_date
        finish_date = '{%s}' % $finish_date
      else
        finish_date = 'HEAD'
      end

      map.each do |k, v|
        path = File.join k, 'trunk'

        if SCM::scm(path) == :svn
          args = '--verbose --revision %s:%s' % [start_date, finish_date]
        else
          args = '@%s..@%s' % [start_date, finish_date]
        end

        info = SCM::info path, args

        if info.nil?
          return false
        end

        info.each do |x|
          x[:change_files].each do |action, names|
            names.each do |name|
              v.keys.each do |key|
                if File.include? key, name or File.include? name, key
                  map[k][key][:change] ||= []
                  map[k][key][:change] << x
                end
              end
            end
          end
        end
      end

      map.each do |k, v|
        v.keys.each do |key|
          if v[key][:change].nil?
            v.delete key
          end
        end
      end

      map.keys.each do |k|
        if map[k].empty?
          map.delete k
        end
      end

      if not map.empty?
        Dir.chdir File.dirname(file) do
          begin
            application = Excel::Application.new

            wk = application.add File.join(gem_dir('distribute-command'), 'doc/bn/change_template.xltx')
            sht = wk.worksheets 1
          rescue
            Util::Logger::exception $!

            return false
          end

          index = 3

          account = []

          map.each do |k, v|
            v.each do |name, info|
              sht.set index, 1, File.join(k, name)

              sht.set index, 2, info[:info]['IPTN项目'][0]
              sht.set index, 3, info[:info]['IPTN项目'][1]
              sht.set index, 4, info[:info]['IPTN项目'][2]

              sht.set index, 6, info[:info]['OTN项目'][0]
              sht.set index, 7, info[:info]['OTN项目'][1]
              sht.set index, 8, info[:info]['OTN项目'][2]

              [
                info[:info]['IPTN项目'][1], info[:info]['IPTN项目'][2],
                info[:info]['OTN项目'][1], info[:info]['OTN项目'][2]
              ].each do |x|
                if x =~ /\d+$/
                  account << '%s@zte.com.cn' % $&
                end
              end

              index += 1
            end
          end

          account.uniq!
          account.sort!

          sht.worksheet.UsedRange.WrapText = false

          filename = '跨项目代码修改代码走查跟踪表(%s)' % Time.now.strftime('%Y%m%d')

          wk.save filename
          wk.close

          change_info = {}

          map.each do |k, v|
            v.each do |name, info|
              info[:change].each do |x|
                change_info[k] ||= {}
                change_info[k][x[:rev].to_i] = x
              end
            end
          end

          File.open '%s_变更详细记录.txt' % filename, 'w:utf-8' do |f|
            change_info.each do |k, v|
              f.puts k
              f.puts '=' * 60

              v.keys.sort.each do |rev|
                info = v[rev]

                f.puts INDENT + '版本号: %s' % info[:rev]
                f.puts INDENT + '提交人: %s' % info[:author]
                f.puts INDENT + '提交日期: %s' % info[:date]

                f.puts INDENT + '变更文件:'

                info[:change_files].each do |action, names|
                  case action
                  when :add
                    f.puts INDENT * 2 + '新增:'
                  when :delete
                    f.puts INDENT * 2 + '删除:'
                  else
                    f.puts INDENT * 2 + '修改:'
                  end

                  names.each do |x|
                    f.puts INDENT * 3 + File.join(k, x)
                  end
                end

                f.puts INDENT + '变更说明:'

                info[:comment].each do |line|
                  f.puts INDENT * 2 + line.rstrip
                end

                f.puts
              end

              f.puts
            end
          end

          name = filename

          File.glob('%s*' % filename).each do |x|
            system 'svn add --force .'

            if ['.xls', '.xlsx'].include? File.extname(x)
              name = x
            end
          end

          system 'svn commit . -m "%s"' % ('自动提交%s' % name)

          cc_account = ['10011354@zte.com.cn', '10017591@zte.com.cn', '10008896@zte.com.cn']
          http = 'https://10.5.72.55:8443/svn/BN_NECOMMON/trunk/doc/跨项目代码修改走查/%s' % name

          Net::send_smtp nil, nil, account, logger, cc: cc_account do |mail|
            mail.subject = '%s, 请及时走查' % filename
            mail.html = '<a href="%s">%s</a>' % [http, http]
          end
        end
      end
    end

    true
  end
end