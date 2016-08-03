require 'rake'

BN_PATHS = {
  'interface' => 'Interface/trunk',
  'platform'  => 'BN_Platform/trunk',
  'e2e'       => 'U31_E2E/trunk',
  'necommon'  => 'BN_NECOMMON/trunk',
  'uca'       => 'BN_UCA/trunk',
  'xmlfile'   => 'NAF_XMLFILE/trunk',
  'naf'       => 'BN_NAF/trunk',
  'sdh'       => 'BN_SDH/trunk',
  'wdm'       => 'BN_WDM/trunk',
  'ptn'       => 'BN_PTN/trunk',
  'ptn2'      => 'BN_PTN2/trunk',
  'ip'        => 'BN_IP/trunk'
}

BN_CPP_PATHS = {
  'interface' => 'Interface/trunk',
  'platform'  => 'BN_Platform/trunk',
  'necommon'  => 'BN_NECOMMON/trunk',
  'uca'       => 'BN_UCA/trunk',
  'e2e'       => 'U31_E2E/trunk',
  'naf'       => 'BN_NAF/trunk',
  'sdh'       => 'BN_SDH/trunk',
  'wdm'       => 'BN_WDM/trunk'
}

BN_REPOS = {
  'interface' => 'https://10.5.72.55:8443/svn/Interface',
  'platform'  => 'https://10.5.72.55:8443/svn/BN_Platform',
  'necommon'  => 'https://10.5.72.55:8443/svn/BN_NECOMMON',
  'uca'       => 'https://10.5.72.55:8443/svn/BN_UCA',
  'xmlfile'   => 'https://10.5.72.55:8443/svn/NBI_XMLFILE',
  'naf'       => 'http://10.30.19.111:8080/tfs/YX/$/NBI',
  'e2e'       => 'http://10.5.64.19/git/U31_E2E',
  'sdh'       => 'https://10.5.72.55:8443/svn/BN_SDH',
  'wdm'       => 'https://10.5.72.55:8443/svn/BN_WDM',
  'ptn'       => 'https://10.5.72.55:8443/svn/BN_PTN',
  'ptn2'      => 'https://10.5.72.55:8443/svn/BN_PTN2',
  'ip'        => 'https://10.5.72.55:8443/svn/BN_IP'
}

BN_REPOS_DEVTOOLS = 'https://10.5.72.55:8443/svn/BN_DEVKIT'

namespace :bn do
  namespace :update do
    task :update, [:name, :branch, :repo, :home, :username, :password] do |t, args|
      name = args[:name].to_s.nil
      branch = args[:branch].to_s.nil || $branch
      repo = args[:repo].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      if not branch.nil?
        if branch == File.basename(branch)
          branch = File.join 'branches', branch
        end
      end

      defaults = BN_REPOS

      if name.nil?
        name = defaults.keys
        repo = nil
      end

      status = true

      name.to_array.each do |module_name|
        http = repo

        if repo.nil?
          http = defaults[module_name]
        end

        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:update:update - %s' % module_name
          status = false

          next
        end

        case module_name
        when 'naf'
          update_home = File.join 'BN_NAF', 'trunk'
        when 'xmlfile'
          update_home = File.join 'NAF_XMLFILE', 'trunk'
        else
          update_home = File.join File.basename(defaults[module_name]), 'trunk'
        end

        File.lock File.join(home, File.dirname(update_home), 'create.id') do
          case module_name
          when 'e2e'
            args = nil

            if not File.directory? File.join(home, update_home)
              if not branch.nil?
                args = '-b %s' % File.basename(branch)
              end
            end

            if not GIT::update File.join(home, update_home), http, args, username, password
              status = false
            end
          when 'naf'
            if not TFS::update File.join(home, update_home), File.join(http, branch || 'trunk'), nil, username, password
              status = false
            end
          else
            if not SVN::update File.join(home, update_home), File.join(http, branch || 'trunk'), nil, username, password
              status = false
            end
          end
        end
      end

      status.exit
    end

    task :devtools, [:branch, :repo, :home, :username, :password] do |t, args|
      branch = args[:branch].to_s.nil || $branch
      repo = args[:repo].to_s.nil
      home = args[:home].to_s.nil || ($devtools_home || 'devtools')
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      defaults = BN_REPOS_DEVTOOLS

      case OS::name
      when :windows
        if $x64
          tag = 'x64/windows/devtools'
        else
          tag = 'windows/devtools'
        end
      when :linux
        tag = 'linux/devtools'
      when :solaris
        tag = 'solaris/devtools'
      else
        tag = nil
      end

      status = true

      if not tag.nil?
        if repo.nil?
          repo = defaults
        end

        File.lock File.join(File.dirname(home), 'create.id') do
          if not SVN::update home, File.join(repo, branch || 'trunk', tag), nil, username, password
            status = false
          end
        end
      else
        status = false
      end

      status.exit
    end
  end

  namespace :deploy do
    task :base, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      version = args[:version].to_s.nil || (ENV['POM_VERSION'] || '2.0')

      status = true

      [
        'BN_Platform/trunk/pom/version',
        'BN_Platform/trunk/code/tools/testframework',
        'BN_Platform/trunk/pom/cpp',
        'BN_Platform/trunk/pom'
      ].each do |path|
        if not Compile::mvn File.join(home, path), 'mvn deploy'
          status = false
        end
      end

      status.exit
    end

    task :thirdparty, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      version = args[:version].to_s.nil || (ENV['POM_VERSION'] || '2.0')

      defaults = {
        BN_PATHS['interface'] => 'interface',
        BN_PATHS['platform']  => 'platform',
        BN_PATHS['e2e']       => 'e2e',
        BN_PATHS['necommon']  => 'necommon',
        BN_PATHS['uca']       => 'uca',
        BN_PATHS['xmlfile']   => 'xmlfile',
        BN_PATHS['naf']       => 'naf',
        BN_PATHS['sdh']       => 'sdh',
        BN_PATHS['wdm']       => 'wdm',
        BN_PATHS['ptn']       => 'ptn',
        BN_PATHS['ptn2']      => 'ptn2',
        BN_PATHS['ip']        => 'ip'
      }

      status = true

      Dir.chdir home do
        File.glob('*/trunk/code/build/thirdparty').each do |path|
          name = nil

          if path =~ /\/trunk\//
            name = defaults[File.join(File.basename($`)), 'trunk']
          end

          if name.nil?
            next
          end

          if not Deploy::thirdparty path, 'com.zte.bn.thirdparty.%s' % name, version
            status = false
          end
        end
      end

      status.exit
    end

    task :uep, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || $installation_uep
      version = args[:version].to_s.nil || ENV['POM_UEP_VERSION']

      status = true

      if not Deploy::uep_bn home, version
        status = false
      end

      status.exit
    end
  end

  namespace :compile do
    task :mvn, [:name, :cmdline, :force, :retry, :home, :dir] do |t, args|
      name = args[:name].to_s.nil
      cmdline = args[:cmdline].to_s.nil
      force = args[:force].to_s.boolean true
      _retry = args[:retry].to_s.boolean true
      home = args[:home].to_s.nil || ($home || 'code')
      dir = args[:dir].to_s.nil || 'build'

      defaults = BN_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:compile:mvn - %s' % module_name
          status = false

          next
        end

        path = File.join home, defaults[module_name], 'code', dir

        if force
          Compile::mvn path, 'mvn clean -fn'
        end

        if not Compile::mvn path, cmdline, _retry
          status = false
        end
      end

      status.exit
    end

    task :mvn_cpp, [:name, :cmdline, :force, :retry, :home, :dir] do |t, args|
      name = args[:name].to_s.nil
      cmdline = args[:cmdline].to_s.nil
      force = args[:force].to_s.boolean true
      _retry = args[:retry].to_s.boolean true
      home = args[:home].to_s.nil || ($home || 'code')
      dir = args[:dir].to_s.nil || 'build'

      defaults = BN_CPP_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:compile:mvn_cpp - %s' % module_name
          status = false

          next
        end

        path = File.join home, defaults[module_name], 'code_c', dir

        if force
          Compile::mvn path, 'mvn clean -fn'
        end

        if not Compile::mvn path, cmdline, _retry
          status = false
        end
      end

      status.exit
    end
  end

  namespace :install do
    task :uep, [:home, :installation_uep, :installation_home, :version, :type] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      installation_uep = args[:installation_uep].to_s.nil || $installation_uep
      installation_home = args[:installation_home].to_s.nil || $installation_home
      version = args[:version].to_s.nil || $version
      type = args[:type].to_s.nil

      status = true

      if not Install::install_uep home, installation_uep, installation_home, version, type do |home, installation, type|
          [
            [File.join(installation_uep, '../documents'), File.join(installation, '../../documents'), true],
            [File.join(installation, '../../../license'), File.join(installation, '../../license'), true],
            [File.join(home, 'BN_Platform/trunk/installdisk/installation/documents', type), '../../documents', true],
            [File.join(home, 'BN_Platform/trunk/installdisk/installation/installation', type), installation, false]
          ].each do |path, to_path, delete|
            if delete
              File.delete to_path do |file|
                Util::Logger::info file

                file
              end
            end

            if File.directory? path
              if not File.copy path, to_path do |src, dest|
                  Util::Logger::info src

                  [src, dest]
                end

                status = false
              end
            end
          end

          status
        end

        status = false
      end

      status.exit
    end

    task :install, [:name, :home, :installation_home, :version, :display_version, :type] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')
      installation_home = args[:installation_home].to_s.nil || $installation_home
      version = args[:version].to_s.nil || $version
      display_version = args[:display_version].to_s.nil || ($display_version || version)
      type = args[:type].to_s.nil

      defaults = BN_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:install:install - %s' % module_name
          status = false

          next
        end

        if not Install::install home, defaults[module_name], installation_home, version, display_version, type
          status = false
        end
      end

      status.exit
    end
  end

  namespace :dashboard do
    task :polling, [:home, :username, :password] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      status = true

      if not Jenkins::dashboard_monitor home, username, password do |lang, group|
          if not group.nil?
            case lang
            when :java
              '%s_dashboard' % group
            when :cpp
              '%s_dashboard_cpp' % group
            else
              nil
            end
          else
            nil
          end
        end

        status = false
      end

      status.exit
    end

    task :compile, [:home, :module_name, :list, :username, :password] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      branch = $branch

      if not branch.nil?
        if branch == File.basename(branch)
          branch = File.join 'branches', branch
        end
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'compile'
        paths.uniq!

        updates_home = []

        paths.each do |path|
          if path =~ /\/trunk\//
            updates_home << File.join($`, 'trunk')
          end
        end

        if updates_home.include?(BN_PATHS['ptn']) or updates_home.include?(BN_PATHS['ptn2'])
          updates_home << BN_PATHS['ptn']
          updates_home << BN_PATHS['ptn2']
        end

        updates_home.uniq!

        updates_home.each do |update_home|
          File.lock File.join(home, File.dirname(update_home), 'create.id') do
            http = nil

            BN_PATHS.each do |k, v|
              if update_home == v
                http = BN_REPOS[k]

                break
              end
            end

            case
            when update_home.include?(BN_PATHS['e2e'])
              args = nil

              if not File.directory? File.join(home, update_home)
                if not branch.nil?
                  args = '-b %s' % File.basename(branch)
                end
              end

              if not GIT::update File.join(home, update_home), http, args, username, password
                status = false
              end
            when update_home.include?(BN_PATHS['naf'])
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not TFS::update File.join(home, update_home), http, nil, username, password
                status = false
              end
            else
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not SVN::update File.join(home, update_home), http, nil, username, password
                status = false
              end
            end
          end
        end

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:compile - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          Compile::mvn File.join(home, path, 'pom', module_name), 'mvn clean -fn'

          if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn install -fn -U -Dmaven.test.skip=true'
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'compile', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end

    task :test, [:home, :module_name, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'test'
        paths.uniq!

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:test - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn test -fn -U'
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'test', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end

    task :check, [:home, :module_name, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'check'
        paths.uniq!

        status = true

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:check - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          # if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn findbugs:findbugs -fn -U'
          #   errors << path
          #
          #   status = false
          # end

          if not Jenkins::check_xml File.join(home, path, 'pom', module_name)
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'check', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end

    task :deploy, [:home, :module_name, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'deploy'
        paths.uniq!

        status = true

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:deploy - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn deploy -fn -U'
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'deploy', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end
  end

  namespace :dashboard_cpp do
    task :compile, [:home, :module_name, :list, :username, :password] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      branch = $branch

      if not branch.nil?
        if branch == File.basename(branch)
          branch = File.join 'branches', branch
        end
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code_c/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'compile'
        paths.uniq!

        updates_home = []

        paths.each do |path|
          if path =~ /\/trunk\//
            updates_home << File.join($`, 'trunk')
          end
        end

        updates_home.uniq!

        updates_home.each do |update_home|
          File.lock File.join(home, File.dirname(update_home), 'create.id') do
            http = nil

            BN_PATHS.each do |k, v|
              if update_home == v
                http = BN_REPOS[k]

                break
              end
            end

            case
            when update_home.include?(BN_PATHS['e2e'])
              args = nil

              if not File.directory? File.join(home, update_home)
                if not branch.nil?
                  args = '-b %s' % File.basename(branch)
                end
              end

              if not GIT::update File.join(home, update_home), http, args, username, password
                status = false
              end
            when update_home.include?(BN_PATHS['naf'])
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not TFS::update File.join(home, update_home), http, nil, username, password
                status = false
              end
            else
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not SVN::update File.join(home, update_home), http, nil, username, password
                status = false
              end
            end
          end
        end

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:compile - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          Compile::mvn File.join(home, path, 'pom', module_name), 'mvn clean -fn'

          if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn install -fn -U -T 5 -Djobs=5 -Dmaven.test.skip=true', true
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'compile', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end

    task :test, [:home, :module_name, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code_c/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'test'
        paths.uniq!

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:test - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn test -fn -U -T 5 -Djobs=5'
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'test', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end

    task :check, [:home, :module_name, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code_c/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'check'
        paths.uniq!

        status = true

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:check - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          # if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn exec:exec -fn -U'
          #   errors << path
          #
          #   status = false
          # end

          if not Jenkins::check_xml File.join(home, path, 'pom', module_name)
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'check', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end

    task :deploy, [:home, :module_name, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      module_name = args[:module_name].to_s.nil
      list = args[:list].to_s.nil

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              paths += File.glob '*/trunk/code_c/build'
            end
          end
        else
          list.split(';').each do |x|
            paths << x.strip
          end
        end

        paths += Jenkins::dashboard_load 'deploy'
        paths.uniq!

        status = true

        errors = []

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:deploy - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path, 'pom', module_name)
            next
          end

          if not Compile::mvn File.join(home, path, 'pom', module_name), 'mvn deploy -fn -U -T 5 -Djobs=5'
            errors << path

            status = false
          end
        end

        Jenkins::dashboard_dump 'deploy', errors
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end
  end

  namespace :patch do
    task :patch, [:name] do |t, args|
    end
  end
end