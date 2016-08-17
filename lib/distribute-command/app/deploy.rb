module Deploy
  module_function

  def thirdparty path, groupid, version
    if version.nil?
      return false
    end

    if not version.include? '-SNAPSHOT'
      version += '-SNAPSHOT'
    end

    if File.directory? path
      Dir.chdir path do
        status = true

        File.glob('**/*.jar').each do |file|
          if file.start_with? 'nodepend/'
            next
          end

          cmdline = 'mvn deploy:deploy-file -Dfile=%s -DgroupId=%s -DartifactId=%s -Dversion=%s -Durl=http://10.8.9.81:8081/nexus/content/repositories/snapshots -DrepositoryId=snapshots' % [file, groupid, File.basename(file, '.*'), version]

          if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              Util::Logger::puts line
            end

            status = false

            next
          end
        end

        status
      end
    else
      Util::Logger::error 'no such directory @thirdparty - %s' % path

      false
    end
  end

  def nfm home, version, xpath = nil
    if version.nil?
      return false
    end

    if not version.include? '-SNAPSHOT'
      version += '-SNAPSHOT'
    end

    xpath ||= 'ZENAP*SDNA*'

    if File.directory? File.join(home, 'installation')
      nfm = 'nfm'

      if not File.mkdir nfm
        return false
      end

      list = []

      Dir.chdir File.join(home, 'installation') do
        list += File.glob '%s.zip' % xpath
        list += File.glob('patch/%s.zip' % xpath).sort_by {|x| '%s %s' % [File.mtime(x), x]}
      end

      list.each do |file|
        zip = ZipFile.new File.join(home, 'installation', file)

        paths = ['ums-server/procs-nfm/system']

        if not zip.unzip nfm, paths
          File.delete nfm

          return false
        end
      end

      status = true

      Dir.chdir nfm do
        map = {}

        [
          'ums-server/procs-nfm/system'
        ].each do |dir|
          if File.directory? dir
            Dir.chdir dir do
              File.glob('**/*.jar').each do |x|
                name = File.dirname(File.dirname(x)).gsub '/', '.'
                map[name] = File.join dir, x
              end
            end
          end
        end

        map.each do |k, v|
          cmdline = 'mvn deploy:deploy-file -Dfile=%s -DgroupId=%s -DartifactId=%s -Dversion=%s -Durl=http://10.8.9.81:8081/nexus/content/repositories/snapshots -DrepositoryId=snapshots' % [v, 'com.zte.uep-nfm', k, version]

          if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              Util::Logger::puts line
            end

            status = false
          end
        end
      end

      File.delete nfm

      status
    else
      Util::Logger::error 'no such directory @nfm - %s' % File.join(home, 'installation')

      false
    end
  end

  def uep_bn home, version
    if version.nil?
      return false
    end

    if not version.include? '-SNAPSHOT'
      version += '-SNAPSHOT'
    end

    if File.directory? File.join(home, 'installation')
      uep = 'uep'

      if not File.mkdir uep
        return false
      end

      list = []

      Dir.chdir File.join(home, 'installation') do
        list += File.glob '{uca,usf,install,pmservice}*.zip'
        list += File.glob('patch/{uca,usf,pmservice}*.zip').sort_by {|x| '%s %s' % [File.mtime(x), x]}
      end

      list.each do |file|
        zip = ZipFile.new File.join(home, 'installation', file)

        paths = ['ums-client/procs', 'ums-client/utils', 'ums-server/procs', 'ums-server/utils', 'uuf/lib', 'uifSetup.jar']

        if not zip.unzip uep, paths
          File.delete uep

          return false
        end
      end

      status = true

      Dir.chdir uep do
        map = {}

        File.glob('**/*.jar').each do |file|
          name = File.basename file, '.*'
          sha1 = Digest::SHA1.file(file).hexdigest

          map[name] ||= {}
          map[name][sha1] ||= []
          map[name][sha1] << file
        end

        map.each do |name, sha1_info|
          if sha1_info.size > 1
            info = {}

            sha1_info.each do |sha1, list|
              zip = ZipFile.new list.first
              zip.unzip File.join('sha1', sha1)

              Dir.chdir File.join('sha1', sha1) do
                info[sha1] = File.glob('**/*.class').sort
              end
            end

            info.each do |sha1, klass|
              if not sha1_info.has_key? sha1
                next
              end

              info.each do |k, v|
                if not sha1_info.has_key? k
                  next
                end

                if sha1 == k
                  next
                end

                if klass == v
                  sha1_info[sha1] += sha1_info[k]
                  sha1_info.delete k
                end
              end
            end
          end

          info = {}

          sha1_info.each do |sha1, list|
            client = false
            server = false

            list.each do |x|
              if x.include? 'ums-client'
                client = true
              end

              if x.include? 'ums-server'
                server = true
              end
            end

            if client and server
              if info.has_key? 'com.zte.uep'
                if list.size > info['com.zte.uep'].first
                  info['com.zte.uep'] = [list.size, list.first]
                end
              else
                info['com.zte.uep'] = [list.size, list.first]
              end

              next
            end

            if client
              if info.has_key? 'com.zte.uep.ums-client'
                if list.size > info['com.zte.uep.ums-client'].first
                  info['com.zte.uep.ums-client'] = [list.size, list.first]
                end
              else
                info['com.zte.uep.ums-client'] = [list.size, list.first]
              end

              next
            end

            if server
              if info.has_key? 'com.zte.uep.ums-server'
                if list.size > info['com.zte.uep.ums-server'].first
                  info['com.zte.uep.ums-server'] = [list.size, list.first]
                end
              else
                info['com.zte.uep.ums-server'] = [list.size, list.first]
              end

              next
            end

            if info.has_key? 'com.zte.uep'
              if list.size > info['com.zte.uep'].first
                info['com.zte.uep'] = [list.size, list.first]
              end
            else
              info['com.zte.uep'] = [list.size, list.first]
            end
          end

          info.each do |k, v|
            if version.end_with? '-SNAPSHOT'
              cmdline = 'mvn deploy:deploy-file -Dfile=%s -DgroupId=%s -DartifactId=%s -Dversion=%s -Durl=http://10.8.9.81:8081/nexus/content/repositories/snapshots -DrepositoryId=snapshots' % [v.last, k, name, version]
            else
              cmdline = 'mvn deploy:deploy-file -Dfile=%s -DgroupId=%s -DartifactId=%s -Dversion=%s -Durl=http://10.8.9.81:8081/nexus/content/repositories/releases -DrepositoryId=releases' % [v.last, k, name, version]
            end

            if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              status = false

              next
            end
          end
        end
      end

      File.delete uep

      status
    else
      Util::Logger::error 'no such directory @uep_bn - %s' % File.join(home, 'installation')

      false
    end
  end

  def uep_stn home, version
    if version.nil?
      return false
    end

    if not version.include? '-SNAPSHOT'
      version += '-SNAPSHOT'
    end

    if File.directory? File.join(home, 'installation')
      uep = 'uep'

      if not File.mkdir uep
        return false
      end

      list = []

      Dir.chdir File.join(home, 'installation') do
        list += File.glob 'uepi-pro*.zip'
        list += File.glob('patch/uepi-pro*.zip').sort_by {|x| '%s %s' % [File.mtime(x), x]}
        list += File.glob 'install*.zip'
      end

      list.each do |file|
        zip = ZipFile.new File.join(home, 'installation', file)

        paths = ['ums-server/procs', 'uifSetup.jar']

        if not zip.unzip uep, paths
          File.delete uep

          return false
        end
      end

      status = true

      Dir.chdir uep do
        File.glob('**/*.pack').each do |file|
          if not File.file? File.join(File.dirname(file), '%s.jar' % File.basename(file, '.*'))
            if not unpack file
              status = false
            end
          end
        end

        map = {}

        [
          'ums-server/procs'
        ].each do |dir|
          if File.directory? dir
            File.glob(File.join(dir, '**/*.jar')).each do |x|
              name = File.basename x, '.jar'

              if name =~ /-(SNAPSHOT|Helium|Beryllium)$/
                name = $`
              end

              if name =~ /\.(RELEASE|Final)$/
                name = $`
              end

              if name =~ /-RC\d+$/
                name = $`
              end

              if name =~ /(-|_)([-.vI\d]+|[.\d]+\.\w+)$/
                name = $`
              end

              if map[name].nil?
                map[name] = x
              else
                if File.size(x) > File.size(map[name])
                  map[name] = x
                end
              end
            end
          end
        end

        if File.file? 'uifSetup.jar'
          map['uifSetup'] = 'uifSetup.jar'
        end

        map.each do |k, v|
          cmdline = 'mvn deploy:deploy-file -Dfile=%s -DgroupId=%s -DartifactId=%s -Dversion=%s -Durl=http://10.8.9.81:8081/nexus/content/repositories/snapshots -DrepositoryId=snapshots' % [v, 'com.zte.uep-ict', k, version]

          if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              Util::Logger::puts line
            end

            status = false
          end
        end
      end

      File.delete uep

      status
    else
      Util::Logger::error 'no such directory @uep_stn - %s' % File.join(home, 'installation')

      false
    end
  end

  def unpack file
    unpacker = File.join gem_dir('distribute-command'), 'doc/stn/unpacker.jar'

    cmdline = 'java -jar %s %s' % [File.cmdline(unpacker), File.cmdline(File.join(File.dirname(file), File.basename(file, '.*')))]

    if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        Util::Logger::puts line
      end

      true
    else
      false
    end
  end
end