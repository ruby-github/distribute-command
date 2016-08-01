require 'rake'

STN_PATHS = {
  'u3_interface'=> 'u3_interface/trunk',
  'interface'   => 'sdn_interface/trunk',
  'framework'   => 'sdn_framework/trunk',
  'application' => 'sdn_application/trunk',
  'nesc'        => 'sdn_nesc/trunk',
  'tunnel'      => 'sdn_tunnel/trunk',
  'ict'         => 'CTR-ICT/trunk',
  'e2e'         => 'SPTN-E2E/trunk',
  'installation'=> 'sdn_installation/trunk'
}

STN_REPOS = {
  'u3_interface'=> 'https://10.5.72.55:8443/svn/Interface',
  'interface'   => 'http://10.5.64.19/git/sdn_interface',
  'framework'   => 'http://10.5.64.19/git/sdn_framework',
  'application' => 'http://10.5.64.19/git/sdn_application',
  'nesc'        => 'http://10.5.64.19/git/sdn_nesc',
  'tunnel'      => 'http://10.5.64.19/git/sdn_tunnel',
  'ict'         => 'http://10.5.64.19/git/CTR-ICT',
  'e2e'         => 'http://10.5.64.19/git/SPTN-E2E',
  'installation'=> 'http://10.5.64.19/git/sdn_installation'
}

namespace :stn do
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

      defaults = STN_REPOS

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
          Util::Logger::error 'no such module @stn:update:update - %s' % module_name
          status = false

          next
        end

        if module_name == 'u3_interface'
          update_home = File.join 'u3_interface', 'trunk'
        else
          update_home = File.join File.basename(defaults[module_name]), 'trunk'
        end

        File.lock File.join(home, File.dirname(update_home), 'create.id') do
          if module_name == 'u3_interface'
            if not SVN::update File.join(home, update_home), File.join(http, branch || 'trunk'), nil, username, password
              status = false
            end
          else
            args = nil

            if not File.directory? File.join(home, update_home)
              if not branch.nil?
                args = '-b %s' % File.basename(branch)
              end
            end

            if not GIT::update File.join(home, update_home), http, args, username, password
              status = false
            end
          end
        end
      end

      status.exit
    end
  end

  namespace :deploy do
    task :base, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      version = args[:version].to_s.nil || (ENV['POM_VERSION'] || '1.0')

      status = true

      [
        'sdn_interface/trunk/pom/version',
        'sdn_interface/trunk/pom/testframework',
        'sdn_interface/trunk/pom/bnxtn',
        'sdn_interface/trunk/pom/bundle'
      ].each do |path|
        if not Compile::mvn File.join(home, path), 'mvn deploy'
          status = false
        end
      end

      status.exit
    end

    task :thirdparty, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      version = args[:version].to_s.nil || (ENV['POM_VERSION'] || '1.0')

      status = true

      if not Deploy::thirdparty File.join(home, 'sdn_interface/trunk/code/thirdparty'), 'com.zte.sdn.thirdparty', version
        status = false
      end

      status.exit
    end

    task :uep, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || $installation_uep
      version = args[:version].to_s.nil || ENV['POM_ICT_VERSION']

      status = true

      if not Deploy::uep_stn home, version
        status = false
      end

      status.exit
    end

    task :nfm, [:home, :version, :xpath] do |t, args|
      home = args[:home].to_s.nil || $installation_uep
      version = args[:version].to_s.nil || ($nfm_version || ENV['POM_NFM_VERSION'])
      xpath = args[:xpath].to_s.nil

      status = true

      if not Deploy::nfm home, version, xpath
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

      defaults = STN_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @stn:compile:mvn - %s' % module_name
          status = false

          next
        end

        if module_name == 'u3_interface'
          path = File.join home, defaults[module_name], 'sdn', dir
        else
          path = File.join home, defaults[module_name], 'code', dir
        end

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
    task :uep, [:home, :installation_uep, :installation_home, :version] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      installation_uep = args[:installation_uep].to_s.nil || $installation_uep
      installation_home = args[:installation_home].to_s.nil || $installation_home
      version = args[:version].to_s.nil || $version

      status = true

      if not Install::install_uep home, installation_uep, installation_home, version, 'sdn' do |home, installation, type|
          [
            [File.join(home, 'sdn_installation/trunk/installdisk/documents'), File.join(installation, '../../documents'), true],
            [File.join(installation, '../../../license'), File.join(installation, '../../license'), true],
            [File.join(home, 'sdn_installation/trunk/installdisk/configure'), installation, false]
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

    task :install, [:name, :home, :installation_home, :version, :display_version] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')
      installation_home = args[:installation_home].to_s.nil || $installation_home
      version = args[:version].to_s.nil || $version
      display_version = args[:display_version].to_s.nil || ($display_version || version)

      defaults = STN_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @stn:install:install - %s' % module_name
          status = false

          next
        end

        if not Install::install home, defaults[module_name], installation_home, version, display_version, 'sdn'
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
          if lang == :java
            'dashboard_stn'
          else
            nil
          end
        end

        status = false
      end

      status.exit
    end

    task :compile, [:home, :list, :username, :password] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      list = args[:list].to_s.nil
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      paths = []

      if list.nil?
        if File.directory? home
          Dir.chdir home do
            File.glob('*/trunk/code/build').each do |x|
              if x.include? STN_PATHS['u3_interface']
                paths << File.join(STN_PATHS['u3_interface'], 'sdn/build')
              else
                paths << x
              end
            end
          end
        end
      else
        list.split(';').each do |x|
          paths << x.strip
        end
      end

      paths += Jenkins::dashboard_load 'compile'
      paths.uniq!

      status = true

      updates_home = []

      paths.each do |path|
        if path =~ /\/trunk\//
          updates_home << File.join($`, 'trunk')
        end
      end

      updates_home.uniq!

      updates_home.each do |update_home|
        File.lock File.join(home, File.dirname(update_home), 'create.id') do
          repo = nil

          STN_PATHS.each do |k, v|
            if update_home == v
              repo = STN_REPOS[k]

              break
            end
          end

          if update_home.include? 'u3_interface'
            if not SVN::update File.join(home, update_home), repo, nil, username, password
              status = false
            end
          else
            if not GIT::update File.join(home, update_home), repo, nil, username, password
              status = false
            end
          end
        end
      end

      errors = []

      paths.each do |path|
        if not File.directory? File.join(home, path)
          Util::Logger::error 'no such directory @stn:dashboard:compile - %s' % File.join(home, path)
          status = false

          next
        end

        Compile::mvn File.join(home, path), 'mvn clean -fn'

        if not Compile::mvn File.join(home, path), 'mvn install -fn -U -Dmaven.test.skip=true'
          errors << path

          status = false
        end
      end

      Jenkins::dashboard_dump 'compile', errors

      status.exit
    end

    task :test, [:home, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      list = args[:list].to_s.nil

      paths = []

      if list.nil?
        if File.directory? home
          Dir.chdir home do
            File.glob('*/trunk/code/build').each do |x|
              if x.include? STN_PATHS['u3_interface']
                paths << File.join(STN_PATHS['u3_interface'], 'sdn/build')
              else
                paths << x
              end
            end
          end
        end
      else
        list.split(';').each do |x|
          paths << x.strip
        end
      end

      paths += Jenkins::dashboard_load 'test'
      paths.uniq!

      status = true

      errors = []

      paths.each do |path|
        if not File.directory? File.join(home, path)
          Util::Logger::error 'no such directory @stn:dashboard:test - %s' % File.join(home, path)
          status = false

          next
        end

        if not Compile::mvn File.join(home, path), 'mvn test -fn -U'
          errors << path

          status = false
        end
      end

      Jenkins::dashboard_dump 'test', errors

      status.exit
    end

    task :check, [:home, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      list = args[:list].to_s.nil

      paths = []

      if list.nil?
        if File.directory? home
          Dir.chdir home do
            File.glob('*/trunk/code/build').each do |x|
              if x.include? STN_PATHS['u3_interface']
                paths << File.join(STN_PATHS['u3_interface'], 'sdn/build')
              else
                paths << x
              end
            end
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
          Util::Logger::error 'no such directory @stn:dashboard:check - %s' % File.join(home, path)
          status = false

          next
        end

        # if not Compile::mvn File.join(home, path), 'mvn findbugs:findbugs -fn -U'
        #   errors << path
        #
        #   status = false
        # end

        if not Jenkins::check_xml File.join(home, path)
          errors << path

          status = false
        end
      end

      Jenkins::dashboard_dump 'check', errors

      status.exit
    end

    task :deploy, [:home, :list] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      list = args[:list].to_s.nil

      paths = []

      if list.nil?
        if File.directory? home
          Dir.chdir home do
            File.glob('*/trunk/code/build').each do |x|
              if x.include? STN_PATHS['u3_interface']
                paths << File.join(STN_PATHS['u3_interface'], 'sdn/build')
              else
                paths << x
              end
            end
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
          Util::Logger::error 'no such directory @stn:dashboard:deploy - %s' % File.join(home, path)
          status = false

          next
        end

        if not Compile::mvn File.join(home, path), 'mvn deploy -fn -U'
          errors << path

          status = false
        end
      end

      Jenkins::dashboard_dump 'deploy', errors

      status.exit
    end
  end

  namespace :patch do
    task :patch do |t, args|
    end
  end
end