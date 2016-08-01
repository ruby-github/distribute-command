module Jenkins
  module_function

  DASHBOARD_FILE = 'dashboard.yml'
  VERSION_INFO_FILE = 'version_info.yml'

  JENKINS_BUILD = 'build --username admin --password admin-1234'

  def build_metric project, night = true
    http = 'http://10.41.213.28/WebService/ZTE.Wireline.WebService/BuildAPI.ashx'

    if night
      buildtype = 'night'
    else
      buildtype = 'CI'
    end

    cmdline = 'curl --data "action=buildstart&project=%s&buildtype=%s" %s' % [project, buildtype, http]

    Util::Logger::puts cmdline

    id = nil

    begin
      id = `#{cmdline}`
    rescue
      id = nil
    end

    status = yield

    if status
      success = 'success'
    else
      success = 'failed'
    end

    if not id.nil?
      cmdline = 'curl --data "action=buildend&buildid=%s&buildresult=%s" %s' % [id, success, http]

      Util::Logger::puts cmdline

      system cmdline
    end

    status
  end

  def check_xml home
    true
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

                dir = pom_dirname File.join(File.dirname(dirname), path)

                if not dir.nil?
                  if dir.include? 'trunk/code/'
                    map[:java] ||= {}
                    map[:java][dir] ||= []
                    map[:java][dir] << x[:author]
                  end

                  if dir.include? 'trunk/sdn/'
                    map[:java] ||= {}
                    map[:java][dir] ||= []
                    map[:java][dir] << x[:author]
                  end

                  if dir.include? 'trunk/code_c/'
                    if dir.include? 'trunk/code_c/database/'
                      if File.file? File.join(dirname, 'code_c/database/dbscript/pom.xml')
                        dir_dbscript = File.join dirname, 'code_c/database/dbscript'

                        if File.file? File.join(dir, 'xml/daobuilder.xml')
                          map[:cpp] ||= {}
                          map[:cpp][dir_dbscript] ||= []
                          map[:cpp][dir_dbscript] << x[:author]
                        end

                        if not File.directory? File.join(dir_dbscript, 'install')
                          map[:cpp] ||= {}
                          map[:cpp][dir_dbscript] ||= []
                          map[:cpp][dir_dbscript] << x[:author]
                        end
                      end
                    end

                    map[:cpp] ||= {}
                    map[:cpp][dir] ||= []
                    map[:cpp][dir] << x[:author]
                  end

                  next
                end

                case dirname
                when 'Interface/trunk'
                  if path.include? 'trunk/code/asn/'
                    map[:java] ||= {}
                    map[:java]['Interface/trunk/code/finterface'] ||= []
                    map[:java]['Interface/trunk/code/finterface'] << x[:author]

                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/finterface'] ||= []
                    map[:cpp]['Interface/trunk/code_c/finterface'] << x[:author]
                  end

                  if path.include? 'trunk/code_c/asn/sdh-wdm/qx-interface/asn/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxinterface'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxinterface'] << x[:author]
                  end

                  if path.include? 'trunk/code_c/asn/sdh-wdm/qx-interface/asn5800/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qx5800'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qx5800'] << x[:author]
                  end

                  if path.include? 'trunk/code_c/asn/sdh-wdm/qx-interface/asnwdm721/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxwdm721'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxwdm721'] << x[:author]
                  end

                  if path.include? 'trunk/code_c/asn/otntlvqx/'
                    map[:cpp] ||= {}
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxotntlv'] ||= []
                    map[:cpp]['Interface/trunk/code_c/qxinterface/qxotntlv'] << x[:author]
                  end
                when 'u3_interface/trunk'
                  if path.include? 'trunk/code/asn/'
                    map[:java] ||= {}
                    map[:java]['u3_interface/trunk/sdn/finterface'] ||= []
                    map[:java]['u3_interface/trunk/sdn/finterface'] << x[:author]
                  end
                when 'BN_NAF/trunk'
                  if path.include? 'trunk/code_c/adapters/xtncorba/corbaidl/'
                    map[:cpp] ||= {}

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl'] << x[:author]

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl2'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtncorba/corbaidl/corbaidl2'] << x[:author]
                  end

                  if path.include? 'trunk/code_c/adapters/xtntmfcorba/corbaidl/'
                    map[:cpp] ||= {}

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl'] << x[:author]

                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl2'] ||= []
                    map[:cpp]['BN_NAF/trunk/code_c/adapters/xtntmfcorba/corbaidl/corbaidl2'] << x[:author]
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

              pom_modules(File.dirname(file)).each do |pom_path|
                lang_info.each do |path, authors|
                  if path == pom_path
                    changes[lang] ||= {}
                    changes[lang][group] ||= {
                      :paths  => [],
                      :authors=> []
                    }

                    changes[lang][group][:paths] << dir
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

      puts changes.to_string

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

  def pom_dirname path
    path = File.normalize path

    if File.file? path
      dirname = File.dirname path
    else
      dirname = path
    end

    size = dirname.split('/').size

    size.times do |i|
      if File.file? File.join(dirname, 'pom.xml')
        return dirname
      end

      dirname = File.dirname dirname
    end

    nil
  end

  def pom_modules path
    path = File.normalize path

    if not File.file? File.join(path, 'pom.xml')
      return []
    end

    modules = []

    begin
      doc = REXML::Document.file File.join(path, 'pom.xml')

      REXML::XPath.each doc, '//modules/module' do |e|
        module_name = e.text.to_s.nil

        if not module_name.nil?
          modules += pom_modules File.join(path, module_name)
        end
      end
    rescue
    end

    if modules.empty?
      modules << path
    end

    modules.uniq
  end
end