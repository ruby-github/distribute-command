require 'rake'

namespace :jenkins do
  task :autopatch do |t, args|
    status = true

    if not Jenkins::autopatch_monitor
      status = false
    end

    status.exit
  end

  task :bn_patch_init, [:name, :version, :branch] do |t, args|
    name = args[:name].to_s.nil
    version = args[:version].to_s.nil
    branch = args[:branch].to_s.nil || $branch

    uep_version = ENV['POM_UEP_VERSION']

    if uep_version.nil?
      file = 'code/BN_Platform/trunk/pom/version/pom.xml'

      if File.file? file
        begin
          doc = REXML::Document.file file

          REXML::XPath.each doc, '/project/properties/uep.version' do |e|
            uep_version = e.text.to_s.gsub '-SNAPSHOT', ''

            break
          end
        rescue
        end
      end
    end

    status = true

    if not name.nil? and not version.nil?
      home = File.expand_path File.join('../build', name)

      if File.mkdir home
        Dir.chdir home do
          [
            'build/code',
            'build/patch/installation',
            'build/patch/patch',
            'build/xml/ptn',
            'build/xml/e2e',
            'build/xml/naf',
            'build/xml/wdm'
          ].each do |dir|
            if not File.mkdir dir do |path|
                Util::Logger::puts path
              end

              status = false
            end
          end

          File.open 'rakefile', 'w:utf-8' do |f|
            f.puts "require 'distribute-command'"
            f.puts

            f.puts '# ----------------------------------------------------------'
            f.puts '# 全局变量设置'
            f.puts '# ----------------------------------------------------------'
            f.puts
            f.puts "$version = '#{version}'"
            f.puts '$display_version = nil'
            f.puts

            if branch.nil?
              f.puts '$branch = nil'
            else
              f.puts "$branch = '#{branch}'"
            end

            if $x64
              f.puts '$x64 = true'
            end

            f.puts
            f.puts '$sendmail = true'

            if $mail_admin
              f.puts "$mail_admin = ['%s']" % $mail_admin.to_array.join("', '")
            end

            if $mail_cc
              f.puts "$mail_cc = ['%s']" % $mail_cc.to_array.join("', '")
            end

            f.puts

            f.puts '# ----------------------------------------------------------'
            f.puts '# POM环境变量设置'
            f.puts '# ----------------------------------------------------------'
            f.puts
            f.puts "ENV['POM_VERSION'] = '%s'" % version.to_s.upcase.gsub(/\s+/, '')
            f.puts "ENV['POM_UEP_VERSION'] = '%s'" % uep_version.to_s
            f.puts

            f.puts '# ----------------------------------------------------------'
            f.puts '# 环境变量设置'
            f.puts '# ----------------------------------------------------------'
            f.puts
            f.puts "ENV['DEVTOOLS_ROOT'] = File.expand_path 'devtools'"

            if OS::name == :linux
              f.puts "ENV['USE_CCACHE'] = '1'"
            end
          end
        end
      else
        status = false
      end
    else
      Util::Logger::error 'name or version is nil'

      status = false
    end

    status.exit
  end

  task :stn_patch_init, [:name, :version, :branch] do |t, args|
    name = args[:name].to_s.nil
    version = args[:version].to_s.nil
    branch = args[:branch].to_s.nil || $branch

    uep_version = ENV['POM_UEP_VERSION']
    nfm_version = ENV['POM_NFM_VERSION']
    oscp_version = ENV['POM_OSCP_VERSION']

    if uep_version.nil? or nfm_version.nil? or oscp_version.nil?
      file = 'code/sdn_interface/trunk/pom/version/pom.xml'

      if File.file? file
        begin
          doc = REXML::Document.file file

          if uep_version.nil?
            REXML::XPath.each doc, '/project/properties/uep.version' do |e|
              uep_version = e.text.to_s

              break
            end
          end

          if nfm_version.nil?
            REXML::XPath.each doc, '/project/properties/nfm.version' do |e|
              nfm_version = e.text.to_s

              break
            end
          end

          if oscp_version.nil?
            REXML::XPath.each doc, '/project/properties/oscp.version' do |e|
              oscp_version = e.text.to_s

              break
            end
          end
        rescue
        end
      end
    end

    status = true

    if not name.nil? and not version.nil?
      home = File.expand_path File.join('../build', name)

      if File.mkdir home
        Dir.chdir home do
          [
            'build/code',
            'build/patch/installation',
            'build/patch/patch',
            'build/xml/sdn'
          ].each do |dir|
            if not File.mkdir dir do |path|
                Util::Logger::puts path
              end

              status = false
            end
          end

          File.open 'rakefile', 'w:utf-8' do |f|
            f.puts "require 'distribute-command'"
            f.puts

            f.puts '# ----------------------------------------------------------'
            f.puts '# 全局变量设置'
            f.puts '# ----------------------------------------------------------'
            f.puts
            f.puts "$version = '#{version}'"
            f.puts '$display_version = nil'
            f.puts

            if branch.nil?
              f.puts '$branch = nil'
            else
              f.puts "$branch = '#{branch}'"
            end

            f.puts
            f.puts '$sendmail = true'

            if $mail_admin
              f.puts "$mail_admin = ['%s']" % $mail_admin.to_array.join("', '")
            end

            if $mail_cc
              f.puts "$mail_cc = ['%s']" % $mail_cc.to_array.join("', '")
            end

            f.puts

            f.puts '# ----------------------------------------------------------'
            f.puts '# POM环境变量设置'
            f.puts '# ----------------------------------------------------------'
            f.puts
            f.puts "ENV['POM_VERSION'] = '%s'" % version.to_s.upcase.gsub(/\s+/, '')
            f.puts "ENV['POM_UEP_VERSION'] = '%s'" % uep_version.to_s
            f.puts "ENV['POM_NFM_VERSION'] = '%s'" % nfm_version.to_s
            f.puts "ENV['POM_OSCP_VERSION'] = '%s'" % oscp_version.to_s
          end
        end
      else
        status = false
      end
    else
      Util::Logger::error 'name or version is nil'

      status = false
    end

    status.exit
  end

  task :scm_change, [:home] do |t, args|
    home = args[:home].to_s.nil || ($home || 'code')

    status = true

    if not Jenkins::scm_change home
      status = false
    end

    status.exit
  end

  task :log_search, [:home] do |t, args|
    home = args[:home].to_s.nil || ($home || 'code')

    status = true

    if File.directory? home
      Dir.chdir home do
        Dir.chdir 'BN_NECOMMON/trunk/doc/日志搜索' do
          if not system 'ruby u3_log_search.rb'
            status = false
          end

          name = File.glob('日志搜索结果*').last

          if not name.nil?
            system 'svn add --force .'
            system 'svn commit . -m "%s"' % ('自动提交日志搜索结果:%s' % name)

            http = 'https://10.5.72.55:8443/svn/BN_NECOMMON/trunk/doc/日志搜索/%s' % name

            Net::send_smtp nil, nil, '10017591@zte.com.cn' do |mail|
              mail.subject = '自动提交日志搜索结果:%s, 请及时查看' % name
              mail.html = '<a href="%s">%s</a>' % [http, http]
            end
          else
            status = false
          end
        end
      end
    else
      Util::Logger::error 'no such directory - %s' % home

      status = false
    end

    status.exit
  end
end