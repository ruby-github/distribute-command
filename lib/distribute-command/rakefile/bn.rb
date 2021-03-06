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

BN_CPP_KW = {
  'wdm' => {
    'wdm_1' => 'BN_WDM/trunk',
    'wdm_2' => 'BN_WDM/trunk',
    'wdm_3' => 'BN_WDM/trunk',
    'wdm_4' => 'BN_WDM/trunk'
  }
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

$bn_mail_addrs_iptn    ||= ['10017591@zte.com.cn', '10041721@zte.com.cn', '10040195@zte.com.cn', '10045466@zte.com.cn'] # 张曰明117591, 操小明141721, 赖洪水140195, 蒋书轶145466
$bn_mail_addrs_iptn_nj ||= ['10011531@zte.com.cn'] # 赵宇111531
$bn_mail_addrs_naf     ||= ['10033121@zte.com.cn', '10041713@zte.com.cn'] # 吉才颂133121, 吴高科141713
$bn_mail_addrs_e2e     ||= ['10035566@zte.com.cn', '10071997@zte.com.cn'] # 李发献135566,赵永旺171997
$bn_mail_addrs_wdm     ||= ['10008896@zte.com.cn'] # 张新立108896

$bn_metric_id_iptn    ||= '310001125783'
$bn_metric_id_iptn_nj ||= '310001122993'
$bn_metric_id_naf     ||= '310001128834'
$bn_metric_id_e2e     ||= '310001128683'
$bn_metric_id_wdm     ||= '310001128924'

def bn_metric_id module_name
  case module_name
  when 'e2e', 'e2e-1', 'e2e-2', 'e2e-3'
    $bn_metric_id_e2e
  when 'wdm', 'wdm-1', 'wdm-2', 'wdm-3', 'wdm-4', 'wdm-5'
    $bn_metric_id_wdm
  when 'naf', 'xmlfile'
    $bn_metric_id_naf
  when 'ptn2', 'ip', 'nanjing-1', 'nanjing-2', 'nanjing-3', 'nanjing-4'
    $bn_metric_id_iptn_nj
  else
    $bn_metric_id_iptn
  end
end

def bn_mail_addrs module_name
  case module_name
  when 'naf'
    $bn_mail_addrs_naf
  when 'e2e'
    $bn_mail_addrs_e2e
  when 'wdm'
    $bn_mail_addrs_wdm
  when 'ptn2', 'ip'
    $bn_mail_addrs_iptn_nj
  else
    $bn_mail_addrs_iptn
  end
end

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

      updates = {}

      time = Time.now

      name.to_array.each do |module_name|
        updates[module_name] = true

        http = repo

        if repo.nil?
          http = defaults[module_name]
        end

        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:update:update - %s' % module_name
          updates[module_name] = false

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

            if not GIT::update File.join(home, update_home), http, args, username, password, true
              updates[module_name] = false

              status = false
            end
          when 'naf'
            if not TFS::update File.join(home, update_home), File.join(http, branch || 'trunk'), nil, username, password, true
              updates[module_name] = false

              status = false
            end
          else
            if not SVN::update File.join(home, update_home), File.join(http, branch || 'trunk'), nil, username, password, true
              updates[module_name] = false

              status = false
            end
          end
        end
      end

      Util::Logger::summary updates.to_a, ((Time.now - time) * 1000).to_i / 1000.0

      status.exit
    end

    task :devtools, [:branch, :repo, :home, :username, :password] do |t, args|
      branch = args[:branch].to_s.nil || $branch
      repo = args[:repo].to_s.nil
      home = args[:home].to_s.nil || ($devtools_home || 'devtools')
      username = args[:username].to_s.nil || ($username || 'u3build')
      password = args[:password].to_s.nil || ($password || 'u3build')

      if not branch.nil?
        if branch == File.basename(branch)
          branch = File.join 'branches', branch
        end
      end

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
          if not SVN::update home, File.join(repo, branch || 'trunk', tag), nil, username, password, true
            status = false
          end
        end
      else
        status = false
      end

      status.exit
    end

    task :version, [:home] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_PATHS

      status = true

      if File.directory? home
        Dir.chdir home do
          versions = {}

          defaults.each do |k, v|
            info = SCM::info v

            if info.nil?
              status = false

              next
            end

            versions[k] = info[:rev]
          end

          File.open 'version.txt', 'w' do |f|
            versions.each do |name, version|
              f.puts [name, version].join(': ')
            end
          end
        end
      else
        Util::Logger::error 'no such directory @bn:update:version - %s' % File.expand_path(home)

        status = false
      end

      status.exit
    end
  end

  namespace :deploy do
    task :base, [:home, :version] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      version = args[:version].to_s.nil || ENV['POM_VERSION']

      status = true

      [
        'BN_Platform/trunk/pom/version',
        'BN_Platform/trunk/pom/testframework',
        'BN_Platform/trunk/pom/cpp',
        'BN_Platform/trunk/pom/java'
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
            name = defaults[File.join(File.basename($`), 'trunk')]
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if $klocwork_build
        _retry = false
        dir = 'build'
      end

      $mail_threshold = true

      status = true

      errors_list = []

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:compile:mvn - %s' % module_name
          status = false

          next
        end

        path = File.join home, defaults[module_name], 'code', dir

        if $klocwork_build
          if module_name != 'interface'
            outfile = File.join File.dirname(File.expand_path(home)), 'kloc/java', module_name, 'kwinject/kwinject.out'

            if File.file? outfile
              File.delete outfile
            else
              File.mkdir File.dirname(outfile)
            end

            cmdline = 'kwmaven --output %s install' % File.cmdline(outfile)
          else
            cmdline = 'mvn install -fn -U'
          end
        end

        if force
          Compile::mvn path, 'mvn clean -fn'
        end

        metric_id = bn_metric_id module_name

        id = Jenkins::buildstart_metric metric_id, module_name, true

        if Compile::mvn path, cmdline, _retry, true do |errors|
            errors_list << errors

            false
          end

          Jenkins::buildend_metric id, true
        else
          Jenkins::buildend_metric id, false

          status = false
        end
      end

      if not status
        errors_list.each do |errors|
          Compile::errors_puts errors
        end

        errors_list.each do |errors|
          Compile::errors_mail errors
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

      if $klocwork_build
        BN_CPP_KW.each do |k, v|
          defaults.delete k

          v.each do |k1, v1|
            defaults[k1] = v1
          end
        end
      end

      if name.nil?
        name = defaults.keys
      end

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if ENV['INTERFACE_OUTPUT_HOME'].nil?
        ENV['INTERFACE_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['interface'], 'code_c/build/output'
      end

      if ENV['PLATFORM_OUTPUT_HOME'].nil?
        ENV['PLATFORM_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['platform'], 'code_c/build/output'
      end

      if $klocwork_build
        _retry = false
        dir = 'build'

        name = name.to_array

        name.dup.each do |_name|
          if BN_CPP_KW.keys.include? _name
            name += BN_CPP_KW[_name].keys
          end
        end

        name.uniq!
      end

      $mail_threshold = true

      status = true

      errors_list = []

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:compile:mvn_cpp - %s' % module_name
          status = false

          next
        end

        path = File.join home, defaults[module_name], 'code_c', dir

        if $klocwork_build
          if module_name != 'interface'
            if not BN_CPP_PATHS.keys.include? module_name
              path = File.join home, defaults[module_name], 'code_c', dir, 'kw', module_name
            end

            outfile = File.join File.dirname(File.expand_path(home)), 'kloc/cpp', module_name, 'kwinject/kwinject.out'

            if File.file? outfile
              File.delete outfile
            else
              File.mkdir File.dirname(outfile)
            end

            cmdline = 'kwinject --output %s mvn install -fn -U -Djobs=10' % File.cmdline(outfile)
          else
            cmdline = 'mvn install -fn -U -Djobs=10'
          end
        end

        if force
          Compile::mvn path, 'mvn clean -fn'
        end

        metric_id = bn_metric_id module_name

        id = Jenkins::buildstart_metric metric_id, module_name, true

        if Compile::mvn path, cmdline, _retry, true do |errors|
            errors_list << errors

            false
          end

          Jenkins::buildend_metric id, true
        else
          Jenkins::buildend_metric id, false

          status = false
        end
      end

      if not status
        errors_list.each do |errors|
          Compile::errors_puts errors
        end

        errors_list.each do |errors|
          Compile::errors_mail errors
        end
      end

      status.exit
    end

    task :debuginfo, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

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

        if File.directory? File.join('debuginfo', module_name)
          File.delete File.join('debuginfo', module_name)  do |file|
            Util::Logger::info file

            file
          end
        end

        if OS::windows?
          xpath = File.join home, defaults[module_name], 'code_c/build/output/**/*.pdb'
        else
          xpath = File.join home, defaults[module_name], 'code_c/build/output/**/*.so.debuginfo'
        end

        File.glob(xpath).each do |file|
          if not File.copy file, File.join('debuginfo', module_name, File.basename(file)) do |src, dest|
              Util::Logger::info src

              [src, dest]
            end

            status = false
          end
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
            [File.join(installation_uep, 'documents'), File.join(installation, '../../documents'), true],
            [File.join(installation, '../../../license'), File.join(installation, '../../license'), true],
            [File.join(home, 'BN_Platform/trunk/installdisk/installation/documents', type), File.join(installation, '../../documents'), true],
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
                  Util::Logger::info dest

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

    task :uep_update, [:home, :installation_uep, :installation_home, :version, :type] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      installation_uep = args[:installation_uep].to_s.nil || $installation_uep
      installation_home = args[:installation_home].to_s.nil || $installation_home
      version = args[:version].to_s.nil || $version
      type = args[:type].to_s.nil

      status = true

      if not Install::install_update_uep home, installation_uep, installation_home, version, type
        status = false
      end

      status.exit
    end

    task :install_update, [:name, :home, :installation_home, :version, :display_version, :type] do |t, args|
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
          Util::Logger::error 'no such module @bn:install:install_update - %s' % module_name
          status = false

          next
        end

        if not Install::install_update home, defaults[module_name], installation_home, version, display_version, type
          status = false
        end
      end

      status.exit
    end

    task :install_lct, [:home, :installation_uep, :installation_home, :version, :display_version, :zh, :fi2cpp_home, :license_home] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')
      installation_uep = args[:installation_uep].to_s.nil || $installation_lct_uep
      installation_home = args[:installation_home].to_s.nil || $installation_home
      version = args[:version].to_s.nil || $version
      display_version = args[:display_version].to_s.nil || ($display_version || version)
      zh = args[:zh].to_s.boolean true
      fi2cpp_home = args[:fi2cpp_home].to_s.nil || $fi2cpp_home
      license_home = args[:license_home].to_s.nil || $license_home

      status = true

      if not Install::install_lct home, installation_uep, installation_home, version, display_version, zh, fi2cpp_home, license_home
        status = false
      end

      status.exit
    end
  end

  namespace :check do
    task :check, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      ignores = []
      errors_list = []

      IO.readlines(File.join(gem_dir('distribute-command'), 'doc/bn/ignore_check_list.txt')).each do |line|
        line.strip!

        if line.empty?
          next
        end

        ignores << line.utf8
      end

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:check:check - %s' % module_name
          status = false

          next
        end

        addrs = bn_mail_addrs module_name

        if File.directory? home
          Dir.chdir home do
            path = File.join defaults[module_name], 'code/build/output'

            if not Compile::check_size path, true, addrs do |file, errors|
                if not file.nil?
                  not ignores.include? File.join(path, file)
                else
                  errors_list << [errors, addrs]

                  false
                end
              end

              status = false
            end
          end
        end
      end

      if not status
        errors_list.each do |errors, addrs|
          errors.each do |file|
            Util::Logger::error file
          end
        end

        errors_list.each do |errors, addrs|
          subject = '<CHECK 通知>文件名超长(客户端最大%s个字符, 服务端最大%s个字符), 请尽快处理' % [Compile::BN_MAX_SIZE_CLIENT, Compile::BN_MAX_SIZE_SERVER]

          lines = []

          if ENV.has_key? 'BUILD_URL'
            http = File.join ENV['BUILD_URL'], 'console'

            lines <<  'Jenkins日志: <font color = "blue"><a href="%s">%s</a></font><br>' % [http, http]
            lines << '<br>'
          end

          errors.each do |file|
            lines << '%s<br>' % file
          end

          lines << '<br>'

          opt = {
            :subject  => 'Subject: %s' % subject,
            :html     => lines.join("\n")
          }

          Net::send_smtp nil, nil, addrs, opt
        end
      end

      status.exit
    end

    task :check_cpp, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_CPP_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      ignores = []
      errors_list = []

      IO.readlines(File.join(gem_dir('distribute-command'), 'doc/bn/ignore_check_list.txt')).each do |line|
        line.strip!

        if line.empty?
          next
        end

        ignores << line.utf8
      end

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:check:check_cpp - %s' % module_name
          status = false

          next
        end

        addrs = bn_mail_addrs module_name

        if File.directory? home
          Dir.chdir home do
            path = File.join defaults[module_name], 'code_c/build/output'

            if not Compile::check_size path, true, addrs do |file, errors|
                if not file.nil?
                  not ignores.include? File.join(path, file)
                else
                  errors_list << [errors, addrs]

                  false
                end
              end

              status = false
            end
          end
        end
      end

      if not status
        errors_list.each do |errors, addrs|
          errors.each do |file|
            Util::Logger::error file
          end
        end

        errors_list.each do |errors, addrs|
          subject = '<CHECK 通知>文件名超长(客户端最大%s个字符, 服务端最大%s个字符), 请尽快处理' % [Compile::BN_MAX_SIZE_CLIENT, Compile::BN_MAX_SIZE_SERVER]

          lines = []

          if ENV.has_key? 'BUILD_URL'
            http = File.join ENV['BUILD_URL'], 'console'

            lines <<  'Jenkins日志: <font color = "blue"><a href="%s">%s</a></font><br>' % [http, http]
            lines << '<br>'
          end

          errors.each do |file|
            lines << '%s<br>' % file
          end

          lines << '<br>'

          opt = {
            :subject  => 'Subject: %s' % subject,
            :html     => lines.join("\n")
          }

          Net::send_smtp nil, nil, addrs, opt
        end
      end

      status.exit
    end

    task :check_xml, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      errors_list = []

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:check:check_xml - %s' % module_name
          status = false

          next
        end

        path = File.join home, defaults[module_name], 'code/build'

        if not Compile::check_xml path, true do |errors|
            errors_list << errors

            false
          end

          status = false
        end
      end

      if not status
        errors_list.each do |errors|
          errors.each do |file|
            Util::Logger::error file
          end
        end

        errors_list.each do |errors|
          Compile::errors_mail errors, subject: '<CHECK 通知>XML文件格式错误, 请尽快处理'
        end
      end

      status.exit
    end

    task :check_xml_cpp, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_CPP_PATHS

      if name.nil?
        name = defaults.keys
      end

      status = true

      errors_list = []

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:check:check_xml_cpp - %s' % module_name
          status = false

          next
        end

        path = File.join home, defaults[module_name], 'code_c/build'

        if not Compile::check_xml path, true do |errors|
            errors_list << errors

            false
          end

          status = false
        end
      end

      if not status
        errors_list.each do |errors|
          errors.each do |file|
            Util::Logger::error file
          end
        end

        errors_list.each do |errors|
          Compile::errors_mail errors, subject: '<CHECK 通知>XML文件格式错误, 请尽快处理'
        end
      end

      status.exit
    end

    task :kloc, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_PATHS

      if name.nil?
        name = defaults.keys
      end

      http = '--url %s' % ($klocwork_http || 'http://127.0.0.1:8080')

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:check:kloc - %s' % module_name
          status = false

          next
        end

        if ['sdh'].include? module_name
          next
        end

        outfile = File.join File.dirname(File.expand_path(home)), 'kloc/java', module_name, 'kwinject/kwinject.out'

        if File.file? outfile
          Dir.chdir File.dirname(File.dirname(outfile)) do
            kwname = 'bnxtn-%s-java' % module_name.downcase

            found = false

            if not CommandLine::cmdline 'kwadmin %s list-projects' % http do |line, stdin, wait_thr|
                Util::Logger::puts line

                if kwname == line.strip
                  found = true
                end
              end

              status = false

              next
            end

            if not found
              cmdline = 'kwadmin %s create-project %s' % [http, kwname]

              if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                  Util::Logger::puts line
                end

                status = false

                next
              end

              [
                ['auto_delete_threshold', 5],
                ['copy_tables', false],
                ['language', 'java']
              ].each do |k, v|
                cmdline = 'kwadmin %s set-project-property %s %s %s' % [http, kwname, k, v]

                if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                    Util::Logger::puts line
                  end

                  status = false

                  next
                end
              end
            end

            cmdline = 'kwbuildproject %s/%s --tables-directory kwbuild --jobs-num auto %s' % [http, kwname, File.cmdline(outfile)]

            if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              if not File.glob('kwbuild/*.dat').empty?
                status = false

                next
              end
            end

            cmdline = 'kwadmin %s load %s kwbuild' % [http, kwname]

            if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              status = false

              next
            end
          end
        end
      end

      status.exit
    end

    task :kloc_cpp, [:name, :home] do |t, args|
      name = args[:name].to_s.nil
      home = args[:home].to_s.nil || ($home || 'code')

      defaults = BN_CPP_PATHS

      BN_CPP_KW.each do |k, v|
        defaults.delete k

        v.each do |k1, v1|
          defaults[k1] = v1
        end
      end

      if name.nil?
        name = defaults.keys
      end

      name = name.to_array

      name.dup.each do |_name|
        if BN_CPP_KW.keys.include? _name
          name += BN_CPP_KW[_name].keys
        end
      end

      name.uniq!

      http = '--url %s' % ($klocwork_http || 'http://127.0.0.1:8080')

      status = true

      name.to_array.each do |module_name|
        if not defaults.keys.include? module_name
          Util::Logger::error 'no such module @bn:check:kloc_cpp - %s' % module_name
          status = false

          next
        end

        outfile = File.join File.dirname(File.expand_path(home)), 'kloc/cpp', module_name, 'kwinject/kwinject.out'

        if File.file? outfile
          Dir.chdir File.dirname(File.dirname(outfile)) do
            kwname = 'bnxtn-%s-cpp' % module_name.downcase

            found = false

            if not CommandLine::cmdline 'kwadmin %s list-projects' % http do |line, stdin, wait_thr|
                Util::Logger::puts line

                if kwname == line.strip
                  found = true
                end
              end

              status = false

              next
            end

            if not found
              cmdline = 'kwadmin %s create-project %s' % [http, kwname]

              if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                  Util::Logger::puts line
                end

                status = false

                next
              end

              [
                ['auto_delete_threshold', 5],
                ['copy_tables', false],
                ['language', 'c,cxx']
              ].each do |k, v|
                cmdline = 'kwadmin %s set-project-property %s %s %s' % [http, kwname, k, v]

                if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                    Util::Logger::puts line
                  end

                  status = false

                  next
                end
              end
            end

            cmdline = 'kwbuildprojectcpp %s/%s --tables-directory kwbuild --jobs-num auto %s' % [http, kwname, File.cmdline(outfile)]

            if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              if not File.glob('kwbuild/*.dat').empty?
                status = false

                next
              end
            end

            cmdline = 'kwadmin %s load %s kwbuild' % [http, kwname]

            if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                Util::Logger::puts line
              end

              status = false

              next
            end
          end
        end
      end

      status.exit
    end

    task :kloc_ignore, [:home] do |t, args|
      home = args[:home].to_s.nil || ($home || 'code')

      status = true

      map = {
        'BN_PTN/trunk/code/build' => [
          '../dev-mgnt/clock',
          '../dev-mgnt/maintenance/maint',
          '../dev-mgnt/maintenance/overhead',
          '../dev-mgnt/port/e1subport',
          '../dev-mgnt/protect',
          '../dev-mgnt/ptnservice'
        ],
        'BN_PTN2/trunk/code/build'=> [
          '../dev-mgnt/basicmng/routeMap',
          '../dev-mgnt/protocol/bgp',
          '../dev-mgnt/protocol/isis',
          '../dev-mgnt/protocol/ldp',
          '../dev-mgnt/protocol/ospf',
          '../dev-mgnt/qos/classmapng',
          '../dev-mgnt/qos/policymap',
          '../dev-mgnt/protocol/ospfv3'
        ]
      }

      if File.directory? home
        Dir.chdir home do
          map.each do |build, modules|
            file = File.join build, 'pom.xml'

            if File.file? file
              begin
                doc = REXML::Document.file file

                REXML::XPath.each doc, '//modules' do |e|
                  REXML::XPath.each e, 'module' do |element|
                    name = File.normalize element.text.to_s.strip

                    modules.each do |module_name|
                      if name.start_with? module_name
                        e.delete element
                      end
                    end
                  end
                end

                doc.to_file file
              rescue
                Util::Logger::exception $!

                status = false
              end
            end
          end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code/build/pom', module_name)).each do |path|
                paths << path
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

              if not GIT::update File.join(home, update_home), http, args, username, password, true
                status = false
              end
            when update_home.include?(BN_PATHS['naf'])
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not TFS::update File.join(home, update_home), http, nil, username, password, true
                status = false
              end
            else
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not SVN::update File.join(home, update_home), http, nil, username, password, true
                status = false
              end
            end
          end
        end

        errors = []
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:compile - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          Compile::mvn File.join(home, path), 'mvn clean -fn'

          if Compile::mvn File.join(home, path), 'mvn install -fn -U -T 5 -Dmaven.test.skip=true', true, true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'compile', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code/build/pom', module_name)).each do |path|
                paths << path
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

        errors = []
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:test - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          if Compile::mvn File.join(home, path), 'mvn test -fn -U -T 5', true, true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'test', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code/build/pom', module_name)).each do |path|
                paths << path
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
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:check - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          # if not Compile::mvn File.join(home, path), 'mvn findbugs:findbugs -fn -U', false, true do |_errors|
          #     errors_list << _errors
          #
          #     false
          #   end
          #
          #   errors << path
          #
          #   status = false
          # end

          if Compile::check_xml File.join(home, path), true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'check', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors, subject: '<CHECK 通知>XML文件格式错误, 请尽快处理'
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code/build/pom', module_name)).each do |path|
                paths << path
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
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard:deploy - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          if Compile::mvn File.join(home, path), 'mvn deploy -fn -U', false, true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'deploy', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if ENV['INTERFACE_OUTPUT_HOME'].nil?
        ENV['INTERFACE_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['interface'], 'code_c/build/output'
      end

      if ENV['PLATFORM_OUTPUT_HOME'].nil?
        ENV['PLATFORM_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['platform'], 'code_c/build/output'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code_c/build/pom', module_name)).each do |path|
                paths << path
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

            BN_CPP_PATHS.each do |k, v|
              if update_home == v
                http = BN_REPOS[k]

                break
              end
            end

            case
            when update_home.include?(BN_CPP_PATHS['e2e'])
              args = nil

              if not File.directory? File.join(home, update_home)
                if not branch.nil?
                  args = '-b %s' % File.basename(branch)
                end
              end

              if not GIT::update File.join(home, update_home), http, args, username, password, true
                status = false
              end
            when update_home.include?(BN_CPP_PATHS['naf'])
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not TFS::update File.join(home, update_home), http, nil, username, password, true
                status = false
              end
            else
              if not http.nil?
                http = File.join http, branch || 'trunk'
              end

              if not SVN::update File.join(home, update_home), http, nil, username, password, true
                status = false
              end
            end
          end
        end

        errors = []
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:compile - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_CPP_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          Compile::mvn File.join(home, path), 'mvn clean -fn'

          if Compile::mvn File.join(home, path), 'mvn install -fn -U -T 5 -Djobs=5 -Dmaven.test.skip=true', true, true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'compile', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if ENV['INTERFACE_OUTPUT_HOME'].nil?
        ENV['INTERFACE_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['interface'], 'code_c/build/output'
      end

      if ENV['PLATFORM_OUTPUT_HOME'].nil?
        ENV['PLATFORM_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['platform'], 'code_c/build/output'
      end

      if ENV['NECOMMON_OUTPUT_HOME'].nil?
        ENV['NECOMMON_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['necommon'], 'code_c/build/output'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code_c/build/pom', module_name)).each do |path|
                paths << path
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

        errors = []
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:test - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          if path =~ /\/trunk\//
            name = BN_CPP_PATHS.key File.join(File.basename($`), 'trunk')

            if not name.nil?
              if ENV["#{name.upcase}_OUTPUT_HOME"].nil?
                ENV["#{name.upcase}_OUTPUT_HOME"] = File.join File.expand_path(home), BN_CPP_PATHS[name], 'code_c/build/output'
              end
            end
          end

          id = Jenkins::buildstart_metric metric_id, BN_CPP_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          if Compile::mvn File.join(home, path), 'mvn test -fn -U -T 5 -Djobs=5', true, true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'test', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if ENV['INTERFACE_OUTPUT_HOME'].nil?
        ENV['INTERFACE_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['interface'], 'code_c/build/output'
      end

      if ENV['PLATFORM_OUTPUT_HOME'].nil?
        ENV['PLATFORM_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['platform'], 'code_c/build/output'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code_c/build/pom', module_name)).each do |path|
                paths << path
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
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:check - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_CPP_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          # if not Compile::mvn File.join(home, path), 'mvn exec:exec -fn -U', false, true do |_errors|
          #     errors_list << _errors
          #
          #     false
          #   end
          #
          #   errors << path
          #
          #   status = false
          # end

          if Compile::check_xml File.join(home, path), true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'check', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors, subject: '<CHECK 通知>XML文件格式错误, 请尽快处理'
          end
        end
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

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if ENV['INTERFACE_OUTPUT_HOME'].nil?
        ENV['INTERFACE_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['interface'], 'code_c/build/output'
      end

      if ENV['PLATFORM_OUTPUT_HOME'].nil?
        ENV['PLATFORM_OUTPUT_HOME'] = File.join File.expand_path(home), BN_CPP_PATHS['platform'], 'code_c/build/output'
      end

      status = true

      if not module_name.nil?
        paths = []

        if list.nil?
          if File.directory? home
            Dir.chdir home do
              File.glob(File.join('*/trunk/code_c/build/pom', module_name)).each do |path|
                paths << path
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
        errors_list = []

        metric_id = bn_metric_id module_name

        paths.each do |path|
          if not File.directory? File.join(home, path)
            Util::Logger::error 'no such directory @bn:dashboard_cpp:deploy - %s' % File.join(home, path)
            status = false

            next
          end

          if not File.directory? File.join(home, path)
            next
          end

          id = Jenkins::buildstart_metric metric_id, BN_CPP_PATHS.key(File.join(File.paths(path).first, 'trunk')), false

          if Compile::mvn File.join(home, path), 'mvn deploy -fn -U', false, true do |_errors|
              errors_list << _errors

              false
            end

            Jenkins::buildend_metric id, true
          else
            errors << path

            Jenkins::buildend_metric id, false

            status = false
          end
        end

        Jenkins::dashboard_dump 'deploy', errors

        if not status
          errors_list.each do |errors|
            Compile::errors_puts errors
          end

          errors_list.each do |errors|
            Compile::errors_mail errors
          end
        end
      else
        Util::Logger::error 'name is nil'

        status = false
      end

      status.exit
    end
  end

  namespace :patch do
    task :install, [:build_home, :code_home, :version, :display_version, :sp_next, :type] do |t, args|
      build_home = args[:build_home].to_s.nil || ($build_home || 'build')
      code_home = args[:code_home].to_s.nil || ($code_home || 'code')
      version = args[:version].to_s.nil || $version
      display_version = args[:display_version].to_s.nil || ($display_version || version)
      sp_next = args[:sp_next].to_s.boolean false
      type = args[:type].to_s.nil

      status = true

      if not Install::install_patch build_home, code_home, version, display_version, sp_next, type
        status = false
      end

      status.exit
    end

    task :install_lct, [:build_home, :version, :display_version] do |t, args|
      build_home = args[:build_home].to_s.nil || ($build_home || 'build')
      version = args[:version].to_s.nil || $version
      display_version = args[:display_version].to_s.nil || ($display_version || version)

      status = true

      if not Install::install_patch_lct build_home, version, display_version
        status = false
      end

      status.exit
    end

    task :patch, [:name, :build_home, :code_home] do |t, args|
      name = args[:name].to_s.nil
      build_home = args[:build_home].to_s.nil || ($build_home || 'build')
      code_home = args[:code_home].to_s.nil || ($code_home || 'code')

      if ENV['DEVTOOLS_ROOT'].nil?
        ENV['DEVTOOLS_ROOT'] = File.expand_path $devtools_home || 'devtools'
      end

      if ENV['INTERFACE_OUTPUT_HOME'].nil?
        ENV['INTERFACE_OUTPUT_HOME'] = File.join File.expand_path(File.join(build_home, 'code')), BN_CPP_PATHS['interface'], 'code_c/build/output'
      end

      if ENV['PLATFORM_OUTPUT_HOME'].nil?
        ENV['PLATFORM_OUTPUT_HOME'] = File.join File.expand_path(File.join(build_home, 'code')), BN_CPP_PATHS['platform'], 'code_c/build/output'
      end

      if name.nil?
        name = ['ptn', 'e2e', 'naf', 'wdm']
      end

      status = true

      patch = Patch::Bn.new build_home, code_home

      name.to_array.each do |_name|
        if not patch.patch File.join(build_home, 'xml', _name)
          status = false
        end
      end

      status.exit
    end

    task :clear, [:build_home] do |t, args|
      build_home = args[:build_home].to_s.nil || ($build_home || 'build')

      status = true

      if File.directory? File.join(build_home, 'code')
        Dir.chdir File.join(build_home, 'code') do
          File.glob('*/trunk/.{git,svn}').each do |dir|
            if not File.delete dir do |file|
                Util::Logger::puts file

                file
              end

              status = false
            end
          end
        end
      end

      status.exit
    end
  end
end