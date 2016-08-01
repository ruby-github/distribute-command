module Install
  module_function

  def install home, dirname, installation_home, version, display_version, type = nil
    if not File.directory? home
      Util::Logger::error 'no such directory - %s' % home

      return false
    end

    path = installation installation_home, version, type

    if ['sdn'].include? type
      installdisk_file = 'installdisk_sdn.xml'
    else
      installdisk_file = 'installdisk.xml'
    end

    if dirname.nil?
      xpath = File.join '*/trunk/installdisk', installdisk_file
    else
      xpath = File.join dirname, 'installdisk', installdisk_file
    end

    map = installdisk home, xpath, version, display_version, type

    if not map.nil?
      File.tmpdir do |tmpdir|
        zip home, map, tmpdir, nil, nil, type, nil do |name, ver|
          File.join path, 'packages', '%s %s.zip' % [name, ver]
        end
      end
    else
      false
    end
  end

  def install_uep home, installation_uep, installation_home, version, type = nil
    if not File.directory? File.join(installation_uep, 'installation')
      Util::Logger::error 'no such directory - %s' % File.join(installation_uep, 'installation')

      return false
    end

    type ||= 'ems'

    path = installation installation_home, version, type

    if not File.delete path do |file|
        Util::Logger::info file

        file
      end

      return false
    end

    if not File.copy File.join(installation_uep, 'installation'), path do |src, dest|
        Util::Logger::info src

        [src, dest]
      end

      File.delete path

      return false
    end

    if File.directory? File.join(installation_uep, 'extends', type.to_s)
      if not File.copy File.join(installation_uep, 'extends', type.to_s), path do |src, dest|
          name = File.basename src

          if name.start_with? 'os-'
            if not name.include? OS::name.to_s
              src = nil
            end
          end

          if not src.nil?
            Util::Logger::info src
          end

          [src, dest]
        end

        File.delete path

        return false
      end
    end

    if ['upgrade'].include? type
      File.tmpdir do |tmpdir|
        if not cut_installation_upgrade installation, tmpdir
          status = false
        end
      end
    end

    if block_given?
      if not yield home, path, type
        return false
      end
    end

    true
  end

  def installation home, version, type = nil
    type ||= 'ems'

    if $x64
      osname = "#{OS::name}-x64"
    else
      osname = OS::name.to_s
    end

    if not ['ems', 'sdn'].include? type.to_s
      osname += "(#{type})"
    end

    File.join home, version, 'installation', osname
  end

  # map
  #   name
  #     :opt
  #       path
  #         k: v
  #     :info
  #       package
  #         :version
  #         :display_version
  #         :zip
  #           src: dest
  #         :ignore
  #           - path
  def installdisk home, xpath, version, display_version, type = nil
    type ||= 'ems'

    Dir.chdir home do
      map = {}

      File.glob(xpath).each do |file|
        begin
          doc = REXML::Document.file file
        rescue
          Util::Logger::exception $!

          return nil
        end

        name = nil

        if file =~ /\/trunk\//
          name = File.basename $`
        end

        if name.nil?
          return nil
        end

        REXML::XPath.each(doc.root, type.to_s) do |e|
          map[name] ||= {
            :opt  => {
              '.' => {
                'os'  => OS::name.to_s
              }
            },
            :info => {}
          }

          REXML::XPath.each(e, 'opts/attr') do |element|
            opt_name = element.attributes['name'].to_s.strip
            opt_value = ''

            value_element = REXML::XPath.first element, 'value'

            if not value_element.nil?
              if value_element.cdatas.empty?
                opt_value = value_element.text.strip
              else
                opt_value = value_element.cdatas.first.to_s.strip
              end
            end

            list = []

            REXML::XPath.each(element, 'files/file') do |file_element|
              path = file_element.attributes['name'].to_s.strip

              if path == '.'
                list << '.'
              else
                list += File.glob File.join(name, 'trunk', path)
              end
            end

            if list.empty?
              list << '.'
            end

            list.uniq.each do |path|
              map[name][:opt][path] ||= {}
              map[name][:opt][path][opt_name] = opt_value
            end
          end

          opt = map[name][:opt]['.'] || {}

          REXML::XPath.each(e, 'packages/package') do |element|
            package = element.attributes['name'].to_s.strip.vars opt
            _version = (element.attributes['version'] || version).to_s.strip.vars opt
            _display_version = (element.attributes['display_version'] || display_version).to_s.strip.vars opt

            package_info = {
              :zip    => {},
              :ignore => []
            }

            dirname = File.normalize File.join(name, 'trunk', element.attributes['dirname'].to_s.strip.vars(opt))

            REXML::XPath.each(element, 'file') do |file_element|
              file_dirname, filename = File.pattern_split file_element.attributes['name'].to_s.strip.vars(opt)

              if file_dirname.nil? or file_dirname == '.'
                cur_dirname = dirname
              else
                cur_dirname = File.join dirname, file_dirname
              end

              list = []

              Dir.chdir cur_dirname do
                list += File.glob filename
              end

              list.each do |path|
                src = File.join cur_dirname, path

                if file_element.attributes['dest'].nil?
                  if file_dirname.nil? or file_dirname == '.'
                    dest = path
                  else
                    dest = File.join file_dirname, path
                  end
                else
                  dest = file_element.attributes['dest'].to_s.strip.vars opt

                  if not file_dirname.nil? and file_dirname != '.'
                    dest = File.join dest, path
                  end
                end

                package_info[:zip][File.normalize(src)] = File.normalize dest.gsub('ums-%s' % type.to_s, 'ums-client')
              end
            end

            REXML::XPath.each(element, 'ignore') do |ignore_element|
              ignore_path = ignore_element.attributes['name'].to_s.strip.vars opt

              Dir.chdir dirname do
                File.glob(ignore_path).each do |path|
                  package_info[:ignore] << File.join(dirname, path)
                end
              end
            end

            if not package_info[:zip].empty?
              map[name][:info][package] ||= {
                :version          => _version,
                :display_version  => _display_version,
                :zip              => {},
                :ignore           => []
              }

              package_info[:zip].each do |k, v|
                map[name][:info][package][:zip][k] = v
              end

              map[name][:info][package][:ignore] += package_info[:ignore]
            end
          end
        end
      end

      map.delete_if do |name, info|
        info[:info].empty?
      end

      map
    end
  end

  def expandname name, dirname, tmpdir, version, display_version, type = nil, opt = nil
    type ||= 'ems'

    if not opt.nil?
      tmpname = File.join tmpdir, dirname, '__opt__', File.tmpname, File.basename(name)

      File.open tmpname, 'w' do |file|
        IO.readlines(name).each do |line|
          encoding = line.encoding
          line = line.utf8.rstrip

          file.puts line.vars(opt).encode(encoding)
        end
      end

      name = tmpname
    end

    if File.symlink? name
      cur_name = File.join tmpdir, dirname, File.tmpname, File.basename(name)

      if File.copy name, cur_name do |src, dest|
          Util::Logger::info src

          [src, dest]
        end

        name = cur_name
      else
        return nil
      end
    end

    if ['ppuinfo.xml', 'pmuinfo.xml', 'u3backup.xml', 'u3backupme.xml', 'dbtool-config.xml'].include? File.basename(name).downcase
      cur_name = File.join tmpdir, dirname, File.tmpname, File.basename(name)

      begin
        doc = REXML::Document.file name

        case File.basename(name).downcase
        when 'ppuinfo.xml', 'pmuinfo.xml'
          if not name.include? '/procs/ppus/uca.ppu'
            REXML::XPath.each(doc, '/ppu/info | /pmu/info') do |e|
              e.attributes['version'] = version.to_s
              e.attributes['display-version'] = display_version.to_s
            end
          end
        when 'u3backup.xml', 'u3backupme.xml'
          REXML::XPath.each(doc, '/T3UpdateConfig/version') do |e|
            e.text = version.to_s
          end
        when 'dbtool-config.xml'
          REXML::XPath.each(doc, '/dbtool/ems_type') do |e|
            e.text = type.to_s
          end
        end

        doc.to_file cur_name
        name = cur_name
      rescue
        Util::Logger::exception $!

        return nil
      end
    end

    if type.to_s == 'upgrade'
      case
      when name =~ /ums-server\/procs\/ppus\/bn\.ppu\/bn-ptn\.pmu\/.*\/ican-adaptercmdcode-config.*\.xml$/
        cur_name = File.join tmpdir, dirname, File.tmpname, File.basename(name)

        begin
          doc = REXML::Document.file name

          REXML::XPath.each doc, '/cmdCodeConfig/commandCode' do |e|
            if e.attributes['cmdCode'] == '88224'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'

              process_node_element = REXML::Element.new 'processNode'
              process_name_element = REXML::Element.new 'processName'
              process_name_element.text = 'com.zte.ican.emf.subnet.process.TDoNothingProcess'
              process_node_element << process_name_element

              element << process_node_element
              e << element
            end

            if e.attributes['cmdCode'] == '80724'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'needMutex'
              element.text = false
              e << element

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'

              process_node_element = REXML::Element.new 'processNode'
              process_name_element = REXML::Element.new 'processName'
              process_name_element.text = 'com.zte.ican.emf.subnet.process.TCreateMEProcess'
              process_node_element << process_name_element

              element << process_node_element
              e << element
            end

            if e.attributes['cmdCode'] == '84205'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'
              e << element
            end

            if e.attributes['cmdCode'] == '81300'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'cmdType'
              element.attributes['overTime'] = '30'
              element.text = 'S'
              e << element

              element = REXML::Element.new 'needMutex'
              element.text = false
              e << element

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'
              e << element
            end

            if e.attributes['cmdCode'] == '80702'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'needMutex'
              element.text = false
              e << element

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'

              element_node = REXML::Element.new 'processNode'
              element_name = REXML::Element.new 'processName'
              element_name.text = 'com.zte.ums.bn.mecopy.emf.process.BeginCopyMEDataProcess'
              element_node << element_name
              element << element_node

              element_node = REXML::Element.new 'processNode'
              element_name = REXML::Element.new 'processName'
              element_name.text = 'com.zte.ums.bn.mecopy.emf.process.EndCopyMEDataProcess'
              element_node << element_name
              element << element_node

              e << element
            end

            if e.attributes['cmdCode'] == '80703'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'needMutex'
              element.text = true
              e << element

              element = REXML::Element.new 'supportOffline'
              element.text = true
              e << element

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'

              element_node = REXML::Element.new 'processNode'
              element_name = REXML::Element.new 'processName'
              element_name.text = 'com.zte.ums.bn.ne.emf.uploadDownload.ptn9000.process.TMESetPreCheckProcess'
              element_node << element_name
              element << element_node

              element_node = REXML::Element.new 'processNode'
              element_name = REXML::Element.new 'processName'
              element_name.text = 'com.zte.ican.emf.subnet.process.TModifyMEProcess'
              element_node << element_name
              element << element_node

              element_node = REXML::Element.new 'processNode'
              element_name = REXML::Element.new 'processName'
              element_name.text = 'com.zte.ican.emf.subnet.process.TPublishModifyMEProcess'
              element_node << element_name
              element << element_node

              e << element
            end
          end

          doc.to_file cur_name
          name = cur_name
        rescue
          Util::Logger::exception $!

          return nil
        end
      when name =~ /ums-server\/procs\/ppus\/bn\.ppu\/(bn-mstp|bn-wdm)\.pmu\/.*\/ican-adaptercmdcode-config.*\.xml$/
        cur_name = File.join tmpdir, dirname, File.tmpname, File.basename(name)

        begin
          doc = REXML::Document.file name

          REXML::XPath.each doc, '/cmdCodeConfig/commandCode' do |e|
            if e.attributes['cmdCode'] == '80724'
              e.children.each do |x|
                e.delete x
              end

              element = REXML::Element.new 'needMutex'
              element.text = true
              e << element

              element = REXML::Element.new 'prcessMgr'
              element.attributes['mgrName'] = 'ProcessMgr'

              process_node_element = REXML::Element.new 'processNode'
              process_name_element = REXML::Element.new 'processName'
              process_name_element.text = 'CCreateMEProcess'
              process_node_element << process_name_element

              element << process_node_element
              e << element
            end
          end

          doc.to_file cur_name
          name = cur_name
        rescue
          Util::Logger::exception $!

          return nil
        end
      else
      end
    end

    name
  end

  def ignore? name, ignores = nil, home = nil
    home ||= '.'

    if not ignores.nil?
      ignores.each do |x|
        if File.include? File.join(home, x), name
          return true
        end
      end
    end

    if File.file? name
      extname = File.extname(name).downcase

      if OS::windows?
        if name.include? 'ums-server/utils/icp/windows'
          false
        else
          ['.so', '.pdb', '.exp', '.lib'].include? extname
        end
      else
        ['.dll', '.debuginfo'].include? extname
      end
    else
      false
    end
  end

  def zip home, map, tmpdir, file = nil, scripts_path = nil, type = nil, append = nil
    home = File.normalize home

    if not file.nil?
      zip = ZipFile.new file, ZipFile::CREATE
    else
      zip = nil
    end

    map.each do |module_name, info|
      opt = info[:opt] || {}

      info[:info].each do |package, zipinfo|
        version = zipinfo[:version]
        display_version = zipinfo[:display_version]

        if file.nil?
          if block_given?
            name = yield package, version
          else
            name = '%s %s.zip' % [package, version]
          end

          zip = ZipFile.new name, ZipFile::CREATE
        end

        zipinfo[:zip].each do |src, dest|
          if File.exist? src
            ignores = zipinfo[:ignore]
          else
            src = File.join home, src
            ignores = zipinfo[:ignore].map { |x| File.join(home, x) }
          end

          if File.basename(src) == 'dbscript-patch' and not scripts_path.nil?
            dest = scripts_path
          end

          if zip.add src, dest do |src_file, dest_file|
              if ignore? src_file, ignores
                src_file = nil
              else
                if File.file? src_file
                  src_file = expandname src_file, package, tmpdir, version, display_version, type, opt[File.relative_path(src_file, home)]
                end

                if src_file.nil?
                  return false
                end
              end

              [src_file, dest_file]
            end
          else
            return false
          end
        end

        if not append.nil?
          append.each do |src, dest|
            if not zip.add src, dest
              return false
            end
          end
        end

        if file.nil?
          if not zip.save
            return false
          end
        end
      end
    end

    if not file.nil?
      if not zip.save
        return false
      end

      File.chmod 0755, file
    end

    true
  end

  def cut_installation_upgrade installation_home, tmpdir
    if File.directory? installation_home
      Dir.chdir installation_home do
        list = File.glob '{uca,usf}*.zip'
        list += File.glob 'patch/{uca,usf}*.zip'

        uep_deletes = [
          'ums-client/procs/ppus/uca.ppu/uca-backup.pmu/uca-wsf-backup.par/conf/uca-wsf-backup-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-bo-report.pmu/uca-wsf-bo-report.par/conf/bo-report-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-ertwrapper.pmu/uca-wsf-ertwrapper.par/conf/ertwrapper-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-css-srm.pmu/uca-wsf-css-srm.par/conf/uca-wsf-srm-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-css-ssm.pmu/uca-wsf-css-ssm.par/conf/uca-wsf-ssm-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-fm.pmu/uca-wsf-fm.par/conf/uca-fm-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-inner.pmu/uca-wsf-inner.par/conf/uca-wsf-inner-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-license.pmu/uca-wsf-license.par/conf/uca-wsf-license-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-log.pmu/uca-wsf-log.par/conf/uca-wsf-log-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-mml.pmu/uca-wsf-mml-clis.par/conf/uca-wsf-mml-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-monitor.pmu/uca-wsf-monitor.par/conf/uca-wsf-monitor-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-pm.pmu/uca-wsf-pm.par/conf/uca-wsf-pm-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-poll.pmu/uca-wsf-poll.par/conf/uca-wsf-poll-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-role.pmu/uca-wsf-role.par/conf/uca-wsf-role-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-task.pmu/uca-wsf-task.par/conf/uca-wsf-task-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-unitsm.pmu/uca-wsf-unitsm.par/conf/uca-wsf-unitsm-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-user.pmu/uca-wsf-user.par/conf/uca-wsf-user-menutool.xml',
          'ums-client/procs/ppus/uca.ppu/uca-user.pmu/uca-wsf-user.par/conf/uca-wsf-user-sys-menutool.xml',

          'ums-client/procs/ppus/uca.ppu/uca-fm.pmu/uca-wsf-fm.par/conf/uca-fm-extensionimpl.xml',
          'ums-client/procs/ppus/uca.ppu/uca-pm.pmu/uca-wsf-pm.par/conf/uca-wsf-pm-extensionimpl.xml',
          'ums-client/procs/ppus/bnplatform.ppu/platform-api.pmu/bn-searcher-wsf.par/conf/bn-searcher-wsf-menutool.xml'
        ]

        list.each do |x|
          zip = ZipFile.new x

          dirname = File.join tmpdir, File.dirname(x), File.basename(x, '.zip')

          if not zip.unzip dirname
            return false
          end

          if File.directory? dirname
            Dir.chdir dirname do
              delete_files = []

              File.glob('**/*').each do |name|
                case
                when name =~ /^ums-server\/works\/.*\/deploy-.*(fm|pm|hmf|e2e).*\.xml$/
                  delete_files << name
                when ['deploy-uep-main-main.xml', 'deploy-uep-mmlndf-mmlndf.xml', 'deploy-uep-umdproc-umdproc.xml', 'deploy-uep-web-web.xml'].include?(File.basename(name))
                  delete_files << name
                else
                  if uep_deletes.include? name
                    delete_files << name
                  end
                end
              end

              delete_files.uniq!

              if delete_files.empty?
                next
              end

              if not File.delete delete_files do |file|
                Util::Logger::info file

                file
              end
                return false
              end

              zip = ZipFile.new x, ZipFile::CREATE

              File.glob('*').each do |name|
                if not zip.add name, name
                  return false
                end
              end

              if not zip.save
                return false
              end
            end

            if File.file? File.join(dirname, x)
              if not File.copy File.join(dirname, x), x do |src, dest|
                  Util::Logger::info src

                  [src, dest]
                end

                return false
              end
            end
          end
        end

        list = File.glob 'install*.zip'
        list += File.glob 'patch/install*.zip'

        list.each do |x|
          zip = ZipFile.new x
          dirname = File.join tmpdir, File.dirname(x), File.basename(x, '.zip')

          if not zip.unzip dirname
            return false
          end

          if File.directory? dirname
            Dir.chdir dirname do
              if File.file? 'conf/internalconfig.xml'
                begin
                  doc = REXML::Document.file 'conf/internalconfig.xml'

                  REXML::XPath.each doc, '/configs/config' do |e|
                    key = e.attributes['key'].to_s.strip

                    if key == 'usf.components.ftpserver.session.max'
                      REXML::XPath.each e, 'processes/process/network' do |element|
                        if element.attributes['scale'].to_s.strip == 'uep1'
                          element.text = '110'
                        end
                      end
                    end

                    if key == 'usf.components.ftpserver.dataport'
                      REXML::XPath.each e, 'processes/process/network' do |element|
                        if element.attributes['scale'].to_s.strip == 'uep1'
                          element.text = '20870-20979'
                        end
                      end
                    end
                  end

                  doc.to_file 'conf/internalconfig.xml'
                rescue
                end
              end

              zip = ZipFile.new x, ZipFile::CREATE

              File.glob('*').each do |name|
                if not zip.add name, name
                  return false
                end
              end

              if not zip.save
                return false
              end
            end

            if File.file? File.join(dirname, x)
              if not File.copy File.join(dirname, x), x do |src, dest|
                  Util::Logger::info src

                  [src, dest]
                end

                return false
              end
            end
          end
        end

        if not File.delete File.glob('itmp*.zip') do |file|
            Util::Logger::info file

            file
          end

          return false
        end

        if not File.delete File.glob('patch/itmp*.zip') do |file|
            Util::Logger::info file

            file
          end

          return false
        end

        if not File.delete File.glob('pmservice*.zip') do |file|
            Util::Logger::info file

            file
          end

          return false
        end

        if not File.delete File.glob('patch/pmservice*.zip') do |file|
            Util::Logger::info file

            file
          end

          return false
        end
      end
    end

    true
  end

  class << self
    private :installation, :installdisk, :expandname, :ignore?, :zip, :cut_installation_upgrade
  end
end