require 'rake'

namespace :jenkins do
  task :autopatch do |t, args|
    status = true

    if not Jenkins::autopatch_monitor
      status = false
    end

    status.exit
  end

  task :bn_patch_init, [:name, :version, :uep_version, :branch] do |t, args|
    name = args[:name].to_s.nil
    version = args[:version].to_s.nil || $version || ENV['POM_VERSION']
    uep_version = args[:uep_version].to_s.nil || File.basename($installation_uep.to_s).nil || ENV['POM_UEP_VERSION']
    branch = args[:branch].to_s.nil || $branch

    status = true

    if not name.nil?
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
            f.puts "ENV['POM_UEP_VERSION'] = '%s'" % uep_version.to_s.upcase.gsub(/\s+/, '')
            f.puts

            f.puts '# ----------------------------------------------------------'
            f.puts '# 环境变量设置'
            f.puts '# ----------------------------------------------------------'
            f.puts
            f.puts "ENV['DEVTOOLS_ROOT'] = File.expand_path 'devtools'"

            if OS::name == :linux
              f.puts "ENV['USE_CCACHE'] = '1'"
            end

            f.puts
          end
        end
      else
        status = false
      end
    else
      status = false
    end

    status.exit
  end

  task :stn_patch_init, [:name, :version, :uep_version, :oscp_version, :branch] do |t, args|
    name = args[:name].to_s.nil
    version = args[:version].to_s.nil || $version || ENV['POM_VERSION']
    uep_version = args[:uep_version].to_s.nil || ENV['POM_ICT_VERSION']
    oscp_version = args[:oscp_version].to_s.nil || File.basename($installation_uep.to_s).nil || ENV['POM_NFM_VERSION']
    branch = args[:branch].to_s.nil || $branch

    status = true

    if not name.nil?
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
            f.puts "ENV['POM_ICT_VERSION'] = '%s'" % uep_version.to_s.upcase.gsub(/\s+/, '')
            f.puts "ENV['POM_UEP_VERSION'] = '%s'" % oscp_version.to_s.upcase.gsub(/\s+/, '')
            f.puts
          end
        end
      else
        status = false
      end
    else
      status = false
    end

    status.exit
  end
end