module Install
  module_function

  def install home, dirname, installation_home, version, display_version, type = nil
    if not File.directory? home
      Util::Logger::error 'no such directory - %s' % home

      return false
    end

    path = installation installation_home, version, type

    if dirname.nil?
      xpath = File.join '*/trunk/installdisk/installdisk.xml'
    else
      xpath = File.join dirname, 'installdisk/installdisk.xml'
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

    if File.directory? path
      Dir.chdir path do
        File.glob('**/*').each do |file|
          begin
            File.chmod 0755, file
          rescue
          end
        end
      end
    end

    true
  end

  # -------------------------------------------------------

  def installation home, version, type = nil
    type ||= 'ems'

    if $x64
      osname = "#{OS::name}-x64"
    else
      osname = OS::name.to_s
    end

    if not ['ems', 'stn'].include? type.to_s
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
              if ignore? src_file, ignores, home
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

          File.chmod 0755, zip.name
        end
      end
    end

    if not file.nil?
      if not zip.save
        return false
      end

      File.chmod 0755, zip.name
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

module Install
  module_function

  def install_update home, dirname, installation_home, version, display_version, type = nil
    if not File.directory? home
      Util::Logger::error 'no such directory - %s' % home

      return false
    end

    path = installation installation_home, version, type

    if dirname.nil?
      xpath = File.join '*/trunk/installdisk/updatedisk.xml'
    else
      xpath = File.join dirname, 'installdisk/updatedisk.xml'
    end

    map = installdisk home, xpath, version, display_version, type

    if not map.nil?
      File.tmpdir do |tmpdir|
        zip home, map, tmpdir, nil, nil, type, nil do |name, ver|
          File.join path, 'update', '%s %s.zip' % [name, ver]
        end
      end
    else
      false
    end
  end

  def install_update_uep home, installation_uep, installation_home, version, type = nil
    if not File.directory? File.join(installation_uep, 'installation')
      Util::Logger::error 'no such directory - %s' % File.join(installation_uep, 'installation')

      return false
    end

    type ||= 'ems'

    path = File.join installation(installation_home, version, type), 'update'

    if not File.delete path do |file|
        Util::Logger::info file

        file
      end

      return false
    end

    if File.directory? File.join(installation_uep, 'extends', type.to_s, 'update')
      if not File.copy File.join(installation_uep, 'extends', type.to_s, 'update'), path do |src, dest|
          Util::Logger::info src

          [src, dest]
        end

        File.delete path

        return false
      end
    end

    true
  end
end

module Install
  module_function

  def install_lct home, installation_uep, installation_home, version, display_version, zh = true,
    fi2cpp_home = nil, license_home = nil
    if not File.directory? home
      Util::Logger::error 'no such directory - %s' % home

      return false
    end

    if not File.directory? installation_uep
      Util::Logger::error 'no such directory - %s' % installation_uep

      return false
    end

    path = installation installation_home, version, 'lct'

    fi2cpp_home ||= File.join path, '../../../fi2cpp'
    license_home ||= File.join path, '../../../license'

    if File.directory? File.join(fi2cpp_home, 'bnmain1')
      fi2cpp = fi2cpp_home
    else
      fi2cpp = File.glob(File.join(fi2cpp_home, '**/fi2cpp')).first
    end

    if fi2cpp.nil?
      Util::Logger::error 'no such directory - %s' % File.join(fi2cpp_home, '**/fi2cpp')

      return false
    end

    if File.file? File.join(license_home, 'ums-license_LCT.LCS')
      license = File.join license_home, 'ums-license_LCT.LCS'
    else
      license = File.glob(File.join(license_home, '**/ums-license_LCT.LCS')).first
    end

    if license.nil?
      Util::Logger::error 'no such file - %s' % File.join(license_home, '**/ums-server/works/uep/deploy/ums-license_LCT.LCS')

      return false
    end

    if zh
      lang = 'zh'
    else
      lang = 'en'
    end

    File.tmpdir do |tmpdir|
      if not File.copy File.join(installation_uep, 'lct-%s' % lang), File.join(tmpdir, lang, 'lct') do |src, dest|
          Util::Logger::info src

          [src, dest]
        end

        return false
      end

      if not File.copy File.join(gem_dir('distribute-command'), 'doc/bn/lct'), File.join(tmpdir, lang) do |src, dest|
          Util::Logger::info src

          [src, dest]
        end

        return false
      end

      xpath = File.join '*/trunk/installdisk/installdisk.xml'
      map = installdisk home, xpath, version, display_version, 'lct'

      if map.nil?
        return false
      end

      map.each do |name, info|
        info[:info].each do |package, zipinfo|
          zipinfo[:zip].each do |src, dest|
            if not File.copy File.join(home, src), File.join(tmpdir, lang, 'lct', dest) do |src_file, dest_file|
                if ignore? src_file, zipinfo[:ignore], home
                  src_file = nil
                end

                Util::Logger::info src_file

                [src_file, dest_file]
              end

              return false
            end
          end
        end
      end

      if not File.copy fi2cpp, File.join(tmpdir, lang, 'lct', 'ums-server/works/global/runtime/fi2cpp') do |src, dest|
          Util::Logger::info src

          [src, dest]
        end

        return false
      end

      if not File.copy license, File.join(tmpdir, lang, 'lct', 'ums-server/works/uep/deploy/ums-license.LCS') do |src, dest|
          Util::Logger::info src

          [src, dest]
        end

        return false
      end

      Dir.chdir File.join(tmpdir, lang, 'lct') do
        deletes = []

        if zh
          File.glob('install/dbscript/dbscript-zh/*').each do |path|
            if File.basename(path) == 'mssql'
              next
            end

            deletes << path
          end

          deletes << 'install/dbscript/dbscript-zh/mssql/e2e'
          deletes << 'install/dbscript/dbscript-en'
        else
          File.glob('install/dbscript/dbscript-en/*').each do |path|
            if File.basename(path) == 'mssql'
              next
            end

            deletes << path
          end

          deletes << 'install/dbscript/dbscript-en/mssql/e2e'
          deletes << 'install/dbscript/dbscript-zh'
        end

        deletes << 'install/plugins/installdb/uep/impl/uif-7-e2esubnet-jdbc.xml'
        deletes << 'install/plugins/installdb/uep/impl/uninstall-7-e2esubnet-jdbc.xml'
        deletes << 'install/plugins/installdb/uep/macro/e2esubnet-macro.properties'
        deletes << 'install/plugins/installdb/uep/macro/e2esubnet-dbpath.xml'
        deletes << 'ums-server/utils/dbtool/U3RestoreE2E.xml'

        File.glob('ums-server/works/*').each do |dirname|
          if ['bnmain', 'bnsubnet', 'bnsubnetptnc', 'cluster', 'global', 'sftpd', 'uca', 'uep'].include? File.basename(dirname)
            next
          end

          deletes << dirname
        end

        deletes << 'ums-server/works/bnsubnetptnc/bnsubnetptnc2'
        deletes << 'ums-server/works/bnsubnetptnc/bnsubnetptnc3'

        if not File.delete deletes do |file|
            Util::Logger::info file

            file
          end

          return false
        end

        map = {
          'ums-server/works/global/deploy/deploy-jca-bn-bnmain.properties'  => {
            /^bn\.core\.serverid\s*=/     => 'bn.core.serverid=49169'
          },
          'ums-server/works/global/deploy/deploy-bn-lct.properties'         => {
            /^bn\.networkType\s*=\s*EMS/  => 'bn.networkType=LCT'
          },
          'ums-server/works/global/deploy/deploy-usf.properties'            => {
            /^ums\.version\.main\s*=/     => 'ums.version.main=%s' % version,
            /^ums\.version\.patch\s*=/    => 'ums.version.patch='
          }
        }

        map.each do |file, info|
          lines = []

          IO.readlines(file).each do |line|
            line.strip!

            info.each do |regexp, value|
              if line =~ regexp
                line = value

                break
              end
            end

            lines << line
          end

          File.open file, 'w' do |f|
            lines.each do |line|
              f.puts line
            end
          end
        end

        File.glob('{ums-server,ums-client}/**/{ppuinfo.xml,pmuinfo.xml}').each do |file|
          begin
            doc = REXML::Document.file file

            REXML::XPath.each(doc, '/ppu/info | /pmu/info') do |e|
              e.attributes['version'] = version
              e.attributes['display-version'] = display_version
            end

            doc.to_file file
          rescue
            Util::Logger::exception $!

            return false
          end
        end

        File.glob('ums-server/utils/dbtool/{U3Backup.xml,U3BackupMe.xml}').each do |file|
          begin
            doc = REXML::Document.file file

            REXML::XPath.each(doc, '/T3UpdateConfig/version') do |e|
              e.text = version
            end

            doc.to_file file
          rescue
            Util::Logger::exception $!

            return false
          end
        end

        File.glob('ums-server/utils/dbtool/conf/dbtool-config.xml').each do |file|
          begin
            doc = REXML::Document.file file

            REXML::XPath.each(doc, '/dbtool/ems_type') do |e|
              e.text = 'lct'
            end

            doc.to_file file
          rescue
            Util::Logger::exception $!

            return false
          end
        end
      end

      Dir.chdir File.join(tmpdir, lang) do
        [
          '7z a -m0=LZMA lct.7z ./lct/*',
          'copy /b 7z.sfx+config.txt+lct.7z lct_setup.exe'
        ].each do |cmdline|
          if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              Util::Logger::puts line
            end

            return false
          end
        end
      end

      if not File.delete File.join(path, 'lct_%s_setup.exe' % lang) do |file|
          Util::Logger::info file

          file
        end

        return false
      end

      if not File.move File.join(tmpdir, lang, 'lct_setup.exe'), File.join(path, 'lct_%s_setup.exe' % lang), true do |file|
          Util::Logger::puts file

          file
        end

        return false
      end
    end

    true
  end
end

module Install
  module_function

  def install_patch build_home, code_home, version, display_version, sp_next = false, type = nil
    build_home = File.normalize build_home
    code_home = File.normalize code_home
    type ||= 'ems'

    installation_home = File.join installation(File.join(build_home, 'patch/installation'), version, type), 'patch'
    patch_home = File.join build_home, 'patch/patch'

    if not File.directory? patch_home
      Util::Logger::error 'no such directory - %s' % patch_home

      return false
    end

    ids = []

    Dir.chdir patch_home do
      File.glob('*/patch').each do |x|
        id = File.dirname x

        if id =~ /^\d{8}_\d{4}$/
          ids << id
        end
      end
    end

    ids.sort!

    if ids.empty?
      return true
    end

    suffix = patchname installation_home, ids.last, version, sp_next, type
    names_suffix = patchset installation_home, version, type
    spname = patch_spname installation_home, version, sp_next, type

    map = {}

    Dir.chdir patch_home do
      ids.each do |id|
        file = File.glob(File.join(id, '*.xml')).first

        if file.nil?
          next
        end

        info = load_patch_file file, type

        if info.nil?
          return false
        end

        if info[:version] == '2.0'
          File.glob(File.join(id, 'patch', '*', type.to_s)).each do |dirname|
            if not File.directory? dirname
              next
            end

            ppuname = File.basename File.dirname(dirname)

            if ppuname == 'ip'
              ppuname = 'bn-ip'
            else
              ppuname = 'bn'
            end

            if type.to_s == 'service'
              ppuname = 'bn-servicetools'
            end

            if type.to_s == 'stn'
              ppuname = 'stn'
            end

            Dir.chdir dirname do
              list = File.glob '*'

              if list.empty?
                map[ppuname] ||= {
                  :zip  => {
                    :zip    => {},
                    :ignore => []
                  },
                  :dbs  => {},
                  :ids  => {},
                  :pmu  => false
                }

                map[ppuname][:ids][id] = info
              else
                list.each do |x|
                  case x
                  when 'ppu'
                    Dir.chdir x do
                      File.glob('*').each do |ppu|
                        map[ppu] ||= {
                          :zip  => {
                            :zip    => {},
                            :ignore => []
                          },
                          :dbs  => {},
                          :ids  => {},
                          :pmu  => false
                        }

                        Dir.chdir ppu do
                          File.glob('*').each do |ppu_x|
                            if ppu_x == 'install'
                              File.glob('install/*').each do |install_file|
                                if File.directory? install_file
                                  if install_file == 'install/dbscript-patch'
                                    File.glob('install/dbscript-patch/**/*').each do |file|
                                      if file =~ /install\/dbscript-patch\/(dbscript[-\w]*)\//
                                        map[ppu][:zip][:zip][File.join('scripts', '%s%s' % [ppu, names_suffix.last], $1, $')] = File.join patch_home, dirname, x, ppu, file
                                      end
                                    end
                                  else
                                    File.glob(File.join(install_file, '**/*')).each do |file|
                                      map[ppu][:zip][:zip][file] = File.join patch_home, dirname, x, ppu, file
                                    end
                                  end
                                else
                                  map[ppu][:zip][:zip][install_file] = File.join patch_home, dirname, x, ppu, install_file
                                end
                              end
                            else
                              File.glob(File.join(ppu_x, '**/*')).each do |file|
                                map[ppu][:zip][:zip][file] = File.join patch_home, dirname, x, ppu, file
                              end
                            end
                          end

                          dbs = load_db_update_info

                          if dbs.nil?
                            return false
                          end

                          dbs.each do |data_source, paths|
                            map[ppu][:dbs][data_source] ||= {}
                            map[ppu][:dbs][data_source].deep_merge! paths
                          end

                          map[ppu][:ids][id] = info
                        end
                      end
                    end
                  when 'pmu'
                    Dir.chdir x do
                      File.glob('*').each do |pmu|
                        map[pmu] ||= {
                          :zip  => {
                            :zip    => {},
                            :ignore => []
                          },
                          :dbs  => {},
                          :ids  => {},
                          :pmu  => true
                        }

                        Dir.chdir pmu do
                          File.glob('*').each do |pmu_x|
                            if pmu_x == 'install'
                              File.glob('install/*').each do |install_file|
                                if File.directory? install_file
                                  if install_file == 'install/dbscript-patch'
                                    File.glob('install/dbscript-patch/**/*').each do |file|
                                      if file =~ /install\/dbscript-patch\/(dbscript[-\w]*)\//
                                        map[pmu][:zip][:zip][File.join('scripts', '%s%s' % [pmu, names_suffix.last], $1, $')] = File.join patch_home, dirname, x, pmu, file
                                      end
                                    end
                                  else
                                    File.glob(File.join(install_file, '**/*')).each do |file|
                                      map[pmu][:zip][:zip][file] = File.join patch_home, dirname, x, pmu, file
                                    end
                                  end
                                else
                                  map[pmu][:zip][:zip][install_file] = File.join patch_home, dirname, x, pmu, install_file
                                end
                              end
                            else
                              File.glob(File.join(pmu_x, '**/*')).each do |file|
                                map[pmu][:zip][:zip][file] = File.join patch_home, dirname, x, pmu, file
                              end
                            end
                          end

                          dbs = load_db_update_info

                          if dbs.nil?
                            return false
                          end

                          dbs.each do |data_source, paths|
                            map[pmu][:dbs][data_source] ||= {}
                            map[pmu][:dbs][data_source].deep_merge! paths
                          end

                          map[pmu][:ids][id] = info
                        end
                      end
                    end
                  else
                    map[ppuname] ||= {
                      :zip  => {
                        :zip    => {},
                        :ignore => []
                      },
                      :dbs  => {},
                      :ids  => {},
                      :pmu  => false
                    }

                    if x == 'install'
                      File.glob('install/*').each do |install_file|
                        if File.directory? install_file
                          if install_file == 'install/dbscript-patch'
                            File.glob('install/dbscript-patch/**/*').each do |file|
                              if file =~ /install\/dbscript-patch\/(dbscript[-\w]*)\//
                                map[ppuname][:zip][:zip][File.join('scripts', '%s%s' % [ppuname, names_suffix.last], $1, $')] = File.join patch_home, dirname, file
                              end
                            end
                          else
                            File.glob(File.join(install_file, '**/*')).each do |file|
                              map[ppuname][:zip][:zip][file] = File.join patch_home, dirname, file
                            end
                          end
                        else
                          map[ppuname][:zip][:zip][install_file] = File.join patch_home, dirname, install_file
                        end
                      end
                    else
                      File.glob(File.join(x, '**/*')).each do |file|
                        map[ppuname][:zip][:zip][file] = File.join patch_home, dirname, file
                      end
                    end

                    dbs = load_db_update_info

                    if dbs.nil?
                      return false
                    end

                    dbs.each do |data_source, paths|
                      map[ppuname][:dbs][data_source] ||= {}
                      map[ppuname][:dbs][data_source].deep_merge! paths
                    end

                    map[ppuname][:ids][id] = info
                  end
                end
              end
            end
          end
        end
      end
    end

    tmpdir = File.tmpdir

    map.each do |k, v|
      name = '%s%s' % [k, suffix]
      names = names_suffix.map { |x| '%s%s' % [k, x] }

      deletes = {}

      v[:ids].sort.each do |id, info|
        info[:delete].each do |x|
          if x =~ /^(install|res|tools|uif|ums|uuf)/
            deletes[x] = id
          end
        end
      end

      deletes.each do |x, id|
        if v[:zip][:zip].has_key? x
          cur_id = File.relative_path(v[:zip][:zip][x], patch_home).split('/').first

          if cur_id =~ /^[0-9_]+$/
            if cur_id < id
              v[:zip][:zip].delete x
            end
          end
        end
      end

      if v[:pmu]
        path = patchset_update_info name, names, tmpdir, version, display_version, deletes.keys.sort, type, k.split('-').first, k
      else
        path = patchset_update_info name, names, tmpdir, version, display_version, deletes.keys.sort, type, k, nil
      end

      v[:zip][:zip][File.basename(path)] = path

      path = ums_db_update_info names.last, v[:dbs], tmpdir
      v[:zip][:zip][File.basename(path)] = path

      path = patchinfo v[:ids], tmpdir, patch_home, type
      v[:zip][:zip][File.basename(path)] = path

      opt = {
        'zipname' => name
      }

      extends_info = patch_extends File.join(build_home, 'code'), '*/trunk/installdisk/extends.xml', type, opt

      if extends_info.nil?
        return false
      end

      extends_info.each do |name, actions|
        actions.each do |action, info|
          info[:zip].each do |src, dest|
            v[:zip][:zip][src] = dest
          end

          v[:zip][:ignore] += info[:ignore]
        end
      end

      if v[:zip][:zip].empty?
        next
      end

      v[:info] = {
        :patch  => {
          :info => {
            name  => {
              :version          => version,
              :display_version  => display_version,
              :zip              => {},
              :ignore           => v[:zip][:ignore]
            }
          }
        }
      }

      v[:zip][:zip].each do |dest, src|
        v[:info][:patch][:info][name][:zip][src] = dest
      end

      if ['ems', 'upgrade'].include? type.to_s and k == 'bn'
        append = ppuinfo version, '%s %s' % [display_version, spname], tmpdir
      else
        append = nil
      end

      status = true

      if not zip '.', v[:info], tmpdir, nil, nil, type, append do |name, ver|
          File.join installation_home, '%s.zip' % name
        end

        status = false
      end

      if status
        changedesc File.join(installation_home, name), v[:ids], patch_home, type
      end

      if not File.delete tmpdir
        return false
      end

      if not status
        return false
      end
    end

    # update info
    update_ids = {}

    Dir.chdir patch_home do
      File.glob('*').each do |id|
        if id =~ /^\d{8}_\d{4}$/
          Dir.chdir id do
            update = true

            File.glob('*').each do |x|
              if File.directory? x
                update = false

                break
              end
            end

            if update
              File.glob('*.xml').each do |x|
                update_ids[id] = load_patch_file x, type

                break
              end
            end
          end
        end
      end
    end

    if not update_ids.empty?
      changedesc File.join(installation_home, 'update%s' % suffix), update_ids
    end

    true
  end

  def install_lct_patch build_home, version, display_version
    build_home = File.normalize build_home

    installation_home = installation File.join(build_home, 'patch/installation'), 'lct'
    patch_home = File.join build_home, 'patch/patch'

    if not File.directory? installation_home
      Util::Logger::error 'no such directory - %s' % installation_home

      return false
    end

    if not File.directory? patch_home
      Util::Logger::error 'no such directory - %s' % patch_home

      return false
    end

    paths = []

    Dir.chdir patch_home do
      File.glob('*/patch/*/lct').each do |x|
        id = x.split('/').first

        if id =~ /^\d{8}_\d{4}$/
          paths << File.join(patch_home, x)
        end
      end
    end

    if paths.empty?
      return true
    end

    tmpdir = File.tmpdir

    Dir.chdir installation_home do
      paths.each do |path|
        if not File.copy path, File.join(tmpdir, 'patch') do |src, dest|
            Util::Logger::info src

            [src, dest]
          end

          File.delete tmpdir

          return false
        end
      end

      File.glob('lct_*_setup.exe').each do |name|
        dirname = File.join tmpdir, File.basename(name)

        cmdline = '7z x %s -o%s' % [name, File.cmdline(File.join(dirname, 'lct'))]

        if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            Util::Logger::puts line
          end

          File.delete tmpdir

          return false
        end

        if not File.copy File.join(tmpdir, 'patch'), File.join(dirname, 'lct') do |src, dest|
            Util::Logger::info src

            [src, dest]
          end

          File.delete tmpdir

          return false
        end

        if not File.copy File.join(gem_dir('distribute-command'), 'doc/bin/lct'), dirname do |src, dest|
            Util::Logger::info src

            [src, dest]
          end

          File.delete tmpdir

          return false
        end

        Dir.chdir dirname do
          [
            '7z a -m0=LZMA lct.7z ./lct/*',
            'copy /b 7z.sfx+config.txt+lct.7z lct_setup.exe'
          ].each do |cmdline|
            if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              File.delete tmpdir

              return false
            end
          end
        end

        if not File.delete name do |file|
            Util::Logger::info file

            file
          end

          return false
        end

        if not File.move File.join(dirname, 'lct_setup.exe'), name, true do |file|
            Util::Logger::puts file

            file
          end

          return false
        end
      end
    end

    File.delete tmpdir

    true
  end

  # -------------------------------------------------------

  def patchname installation_home, id, version, sp_next = false, type = nil
    prefix = '-%s-SP' % version
    last_sp = 0
    last_index = 0

    if File.directory? installation_home
      Dir.chdir installation_home do
        File.glob('*%s*.zip' % prefix).each do |name|
          if name =~ /-SP(\d+)\(001-(\d+)\)/
            last_sp = [last_sp, $1.to_i].max
            last_index = [last_index, $2.to_i].max
          else
            if name =~ /-SP(\d+)\((\d+)\)/
              last_sp = [last_sp, $1.to_i].max
              last_index = [last_index, $2.to_i].max
            end
          end
        end
      end
    end

    if sp_next or last_sp == 0
      last_sp += 1
    end

    '%s%03d(%03d)-%s' % [prefix, last_sp, last_index.next, id]
  end

  def patchset installation_home, version, type = nil
    prefix = '-%s-SP' % version
    last_index = 0

    if File.directory? installation_home
      Dir.chdir installation_home do
        File.glob('*%s*.zip' % prefix).each do |name|
          if name =~ /-SP(\d+)\(001-(\d+)\)/
            last_index = [last_index, $2.to_i].max
          else
            if name =~ /-SP(\d+)\((\d+)\)/
              last_index = [last_index, $2.to_i].max
            end
          end
        end
      end
    end

    last_index += 1

    names = []

    last_index.times do |i|
      names << '-%s-%03d' % [version, i.next]
    end

    names
  end

  def patch_spname installation_home, version, sp_next = false, type = nil
    prefix = '-%s-SP' % version
    last_sp = 0

    if File.directory? installation_home
      Dir.chdir installation_home do
        File.glob('*%s*.zip' % prefix).each do |name|
          if name =~ /-SP(\d+)\(001-(\d+)\)/
            last_sp = [last_sp, $1.to_i].max
          else
            if name =~ /-SP(\d+)\((\d+)\)/
              last_sp = [last_sp, $1.to_i].max
            end
          end
        end
      end
    end

    if sp_next or last_sp == 0
      last_sp += 1
    end

    'SP%03d' % last_sp
  end

  def ppuinfo version, display_version, tmpdir
    # ums-server/procs/ppus/bn.ppu/ppuinfo.xml
    # ums-server/procs/ppus/e2e.ppu/ppuinfo.xml

    doc = REXML::Document.new '<ppu/>'
    display_element = REXML::Element.new 'display-name'
    info_element = REXML::Element.new 'info'
    doc.root << display_element
    doc.root << info_element

    display_element.attributes['en_US'] = 'BN-xTN'
    display_element.attributes['zh_CN'] = 'BN-xTN'

    info_element.attributes['display-version'] = display_version.to_s
    info_element.attributes['en_US'] = 'Bearer Network Transport Common Module'
    info_element.attributes['version'] = version.to_s
    info_element.attributes['zh_CN'] = '承载传输公用组件'

    doc.to_file File.join(tmpdir, 'ppuinfo', 'ums-server/procs/ppus/bn.ppu/ppuinfo.xml'), 'gb2312'
    doc.to_file File.join(tmpdir, 'ppuinfo', 'ums-client/procs/ppus/bn.ppu/ppuinfo.xml'), 'gb2312'

    display_element.attributes['en_US'] = 'E2E'
    display_element.attributes['zh_CN'] = 'E2E'

    info_element.attributes['display-version'] = display_version.to_s
    info_element.attributes['en_US'] = 'End-To-End Module'
    info_element.attributes['version'] = version.to_s
    info_element.attributes['zh_CN'] = '端到端组件'

    doc.to_file File.join(tmpdir, 'ppuinfo', 'ums-server/procs/ppus/e2e.ppu/ppuinfo.xml'), 'gb2312'
    doc.to_file File.join(tmpdir, 'ppuinfo', 'ums-client/procs/ppus/e2e.ppu/ppuinfo.xml'), 'gb2312'

    {
      File.join(tmpdir, 'ppuinfo', 'ums-server/procs/ppus/bn.ppu/ppuinfo.xml') => 'ums-server/procs/ppus/bn.ppu/ppuinfo.xml',
      File.join(tmpdir, 'ppuinfo', 'ums-server/procs/ppus/e2e.ppu/ppuinfo.xml') => 'ums-server/procs/ppus/e2e.ppu/ppuinfo.xml',
      File.join(tmpdir, 'ppuinfo', 'ums-client/procs/ppus/bn.ppu/ppuinfo.xml') => 'ums-client/procs/ppus/bn.ppu/ppuinfo.xml',
      File.join(tmpdir, 'ppuinfo', 'ums-client/procs/ppus/e2e.ppu/ppuinfo.xml') => 'ums-client/procs/ppus/e2e.ppu/ppuinfo.xml'
    }
  end

  def patchset_update_info zipname, names, tmpdir, version, display_version, deletes = nil, type = nil, ppuname = nil, pmuname = nil
    deletes ||= []
    type ||= 'ems'

    doc = REXML::Document.new '<update-info/>'

    ppuname ||= 'bn'

    case ppuname
    when 'bn-ip'
      ppuname = 'bn'
      pmuname = 'bn-ip'
    when 'bn', 'stn'
      if ['ems', 'stn'].include? type.to_s
        ppuname = 'e2e'
      end
    end

    doc.root.attributes['ppuname'] = ppuname

    if not pmuname.nil?
      doc.root.attributes['pmuname'] = pmuname
    end

    if type.to_s == 'service'
      doc.root.attributes['ppuname'] = 'bn'
      doc.root.attributes['pmuname'] = 'bn-servicetools'
      doc.root.attributes['hotpatch'] = 'true'
    end

    element = REXML::Element.new 'description'

    if type.to_s == 'stn'
      e = REXML::Element.new 'zh_cn'
      e.text = 'ICT 管理系统%s' % display_version
      element << e

      e = REXML::Element.new 'en_us'
      e.text = 'ICT Management System %s' % display_version
      element << e
    else
      e = REXML::Element.new 'zh_cn'
      e.text = 'NetNumen U31统一网管系统%s' % display_version
      element << e

      e = REXML::Element.new 'en_us'
      e.text = 'NetNumen U31 Unified Network Management System %s' % display_version
      element << e
    end

    doc.root << element

    if type.to_s == 'service'
      element = REXML::Element.new 'hotpatch'
      element.attributes['restart-client'] = 'true'
      element.attributes['run-operation'] = 'true'

      doc.root << element

      element = REXML::Element.new 'pmus'
      e = REXML::Element.new 'pmu'
      e.attributes['name'] = 'bn-servicetools'
      element << e

      doc.root << element
    end

    element = REXML::Element.new 'src-version'
    e = REXML::Element.new 'version'
    e.attributes['main'] = version
    element << e
    doc.root << element

    element = REXML::Element.new 'patchs'

    names.each do |x|
      e = REXML::Element.new 'patch'
      e.text = x
      element << e
    end

    doc.root << element

    if not deletes.empty?
      element = REXML::Element.new 'delete-file-list'

      deletes.each do |x|
        e = REXML::Element.new 'file-item'
        e.attributes['delfile'] = x
        element << e
      end

      doc.root << element
    end

    doc.to_file File.join(tmpdir, 'update-info', zipname, 'patchset-update-info.xml')

    File.join tmpdir, 'update-info'
  end

  def ums_db_update_info patchname, dbs, tmpdir
    doc = REXML::Document.new '<install-db/>'

    dbs.each do |data_source, xpaths|
      element = REXML::Element.new 'data-source'
      element.attributes['key'] = data_source

      xpaths.each do |xpath, info|
        list = xpath.split '/'
        e = nil
        cur_e = nil

        list.each do |x|
          if e.nil?
            e = REXML::Element.new x
            cur_e = e
          else
            tmp_e = REXML::Element.new x
            cur_e << tmp_e
            cur_e = tmp_e
          end
        end

        if not e.nil?
          info.each do |filename, opt|
            item_element = REXML::Element.new 'item'

            opt.each do |k, v|
              item_element.attributes[k] = v
            end

            cur_e << item_element
          end

          element << e
        end
      end

      doc.root << element
    end

    doc.to_file File.join(tmpdir, 'scripts', patchname, 'ums-db-update-info.xml')

    File.join tmpdir, 'scripts'
  end

  def patchinfo ids, tmpdir, home = nil, type = nil
    doc = REXML::Document.new '<update/>'
    doc_defect = REXML::Document.new '<update/>'

    ids.each do |id, info|
      info_list = []

      if not home.nil? and File.directory? File.join(home, id, 'ids')
        File.glob(File.join(home, id, 'ids', '*.xml')).each do |file|
          ids_info = load_patch_file file, type

          if ids_info.nil?
            next
          end

          info_list << ids_info
        end
      else
        info_list << info
      end

      info_list.each do |x|
        element = REXML::Element.new 'info'
        element.attributes['name'] = id

        ['提交人员', '开发经理', '变更描述'].each do |name|
          e = REXML::Element.new 'attr'
          e.text = x[:info][name]
          e.attributes['name'] = name

          element << e
        end

        if ['故障'].include? x[:info]['变更类型']
          doc_defect.root << element
        else
          doc.root << element
        end
      end
    end

    dirname = File.join tmpdir, 'update', 'patchinfo', Time.now.strftime('%Y%m%d%H%M%S')

    doc.to_file File.join(dirname, 'update.xml')
    doc_defect.to_file File.join(dirname, 'update_defect.xml')

    File.join tmpdir, 'update'
  end

  def changedesc name, ids, home = nil, type = nil
    if OS::windows?
      begin
        application = Excel::Application.new
        wk = application.add File.join(gem_dir('distribute-command'), 'doc/bn/patchinfo_template.xltx')
        sht = wk.worksheet 1

        line = 2

        ids.each do |id, info|
          info_list = []

          if not home.nil? and File.directory? File.join(home, id, 'ids')
            File.glob(File.join(home, id, 'ids', '*.xml')).each do |file|
              ids_info = load_patch_file file, type

              if ids_info.nil?
                next
              end

              info_list << ids_info
            end
          else
            info_list << info
          end

          info_list.each do |x|
            # 变更来源
            sht.set line, 1, x[:info]['变更来源']
            # 变更类型
            sht.set line, 2, x[:info]['变更类型']
            # 开发组
            sht.set line, 3, x[:info]['开发经理']
            # 提交人
            sht.set line, 4, x[:info]['提交人员']
            # 故障ID/需求特征项ID
            sht.set line, 5, x[:info]['关联故障']
            # 变更描述
            sht.set line, 6, x[:info]['变更描述']
            # 变更波及分析及测试建议
            sht.set line, 7, x[:info]['影响分析']
            # 集成测试人
            # 集成测试结果
            # 补丁编号
            sht.set line, 10, id
            # 源文件
            sht.set line, 11, x[:source].join("\n")
            # 补丁文件
            sht.set line, 12, x[:deploy].join("\n")
            # 走查人员
            sht.set line, 16, x[:info]['走查人员']
            # 走查结果
            sht.set line, 17, x[:info]['走查结果']

            line += 1
          end
        end

        sht.worksheet.UsedRange.WrapText = false

        wk.save name
        wk.close

        true
      rescue
        Util::Logger::exception $!

        false
      end
    else
      doc = REXML::Document.new '<patchinfo/>'

      ids.each do |id, info|
        info_list = []

        if not home.nil? and File.directory? File.join(home, id, 'ids')
          File.glob(File.join(home, id, 'ids', '*.xml')).each do |file|
            ids_info = load_patch_file file, type

            if ids_info.nil?
              next
            end

            info_list << ids_info
          end
        else
          info_list << info
        end

        info_list.each do |x|
          element = REXML::Element.new 'info'
          element.attributes['id'] = id

          e = REXML::Element.new 'attr'
          e.text = x[:info]['变更来源']
          e.attributes['name'] = '变更来源'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:info]['变更类型']
          e.attributes['name'] = '变更类型'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:info]['开发经理']
          e.attributes['name'] = '开发组'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:info]['提交人员']
          e.attributes['name'] = '提交人'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:info]['关联故障']
          e.attributes['name'] = '故障ID/需求特征项ID'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:info]['变更描述']
          e.attributes['name'] = '变更描述'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:info]['影响分析']
          e.attributes['name'] = '变更波及分析及测试建议'
          element << e

          e = REXML::Element.new 'attr'
          e.attributes['name'] = '集成测试人'
          element << e

          e = REXML::Element.new 'attr'
          e.attributes['name'] = '集成测试结果'
          element << e

          e = REXML::Element.new 'attr'
          e.text = id
          e.attributes['name'] = '补丁编号'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:source].join("\n")
          e.attributes['name'] = '源文件'
          element << e

          e = REXML::Element.new 'attr'
          e.text = x[:deploy].join("\n")
          e.attributes['name'] = '补丁文件'
          element << e

          doc.root << element
        end
      end

      doc.to_file '%s.xml' % name

      true
    end
  end

  # map
  #   name
  #     action
  #       :zip
  #         src: dest
  #       :ignore
  #         - path
  def patch_extends home, xpath, type = nil, opt = {}
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
          e.each_element do |element|
            action = element.name
            dirname = element.attributes['dirname'].to_s

            map[name] ||= {}
            map[name][action] ||= {
              :zip    => {},
              :ignore => []
            }

            REXML::XPath.each(element, 'file') do |file_element|
              src = file_element.attributes['name']
              dest = file_element.attributes['dest']

              if not src.nil? and not dest.nil?
                map[name][action][:zip][dest.strip.vars(opt)] = File.join home, name, 'trunk', dirname, src.strip.vars(opt)
              end
            end

            REXML::XPath.each(element, 'ignore') do |ignore_element|
              ignore_path = ignore_element.attributes['name'].to_s.strip.vars opt

              Dir.chdir File.join(name, 'trunk', dirname) do
                File.glob(ignore_path).each do |path|
                  map[name][action][:ignore] << File.join(home, name, 'trunk', dirname, path)
                end
              end
            end
          end
        end
      end

      map
    end
  end

  def load_patch_file file, type = nil
    begin
      doc = REXML::Document.file file
    rescue
      Util::Logger::exception $!

      return nil
    end

    map = {
      :version  => doc.root.attributes['version'].to_s,
      :source   => [],
      :deploy   => [],
      :delete   => [],
      :info     => {}
    }

    REXML::XPath.each(doc, '/patches/patch') do |e|
      home = e.attributes['name'].to_s

      REXML::XPath.each(e, 'source/attr') do |element|
        map[:source] << File.join(home, element.attributes['name'].to_s)
      end

      if map[:version] == '2.0'
        REXML::XPath.each(e, 'deploy/deploy/attr') do |element|
          dest = element.text.to_s.nil

          if dest.nil?
            src = element.attributes['name'].to_s

            if src =~ /^(sdn|code|code_c)\/build\/output\//
              dest = $'
            end
          end

          if not dest.nil?
            cur_type = element.attributes['type'].to_s.strip.nil

            if dest =~ /^ums-(\w+)/
              if ['nms', 'lct'].include? $1
                cur_type = $1

                dest.gsub! 'ums-%s' % $1, 'ums-client'
              end
            end

            cur_type ||= 'ems'

            if cur_type == type.to_s
              map[:deploy] << dest
            end
          end
        end

        REXML::XPath.each(e, 'deploy/delete/attr') do |element|
          cur_type = (element.attributes['type'].to_s.strip.nil || 'ems').split(',').map {|x| x.strip}

          if cur_type.include? type.to_s
            map[:delete] << element.attributes['name'].to_s
          end
        end
      end

      REXML::XPath.each(e, 'info/attr') do |element|
        map[:info][element.attributes['name'].to_s] = element.text.to_s
      end
    end

    map
  end

  def load_db_update_info
    file = 'install/dbscript-patch/ums-db-update-info.xml'

    dbs = {}

    if File.file? file
      begin
        doc = REXML::Document.file file
      rescue
        Util::Logger::exception $!

        return nil
      end

      REXML::XPath.each(doc, '/install-db/data-source') do |e|
        data_source = e.attributes['key'].to_s.strip
        dbs[data_source] ||= {}

        REXML::XPath.each(e, '*//item[@filename]') do |element|
          xpath = element.parent.xpath.gsub /\/install-db\/data-source[\[\d\]]*\//, ''
          filename = element.attributes['filename'].to_s.strip

          opt = {}

          element.attributes.each do |k, v|
            opt[k] = v
          end

          if opt['filename'].nil? or opt['rollback'].nil?
            Util::Logger::error '%s[%s] filename or rollback is empty' % [file, element.xpath]

            return nil
          end

          xpath.gsub! /\[\d+\]/, ''

          dbs[data_source][xpath] ||= {}
          dbs[data_source][xpath][filename] = opt
        end
      end
    end

    dbs
  end

  class << self
    private :patchname, :patchset, :patch_spname, :ppuinfo
    private :patchset_update_info, :ums_db_update_info, :patchinfo, :changedesc
    private :patch_extends, :load_patch_file, :load_db_update_info
  end
end