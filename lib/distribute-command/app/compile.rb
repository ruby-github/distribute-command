module Compile
  module_function

  BN_MAX_SIZE_SERVER = 160
  BN_MAX_SIZE_CLIENT = 140
  MAIL_THRESHOLD_DAY = 7
  PATH = ENV['PATH']

  def mvn path, cmdline = nil, _retry = false, sendmail = false, args = nil
    if not ENV['DEVTOOLS_ROOT'].nil?
      if $x64
        case OS::name
        when :windows
          ENV['WIN64'] = '1'
        when :linux
          ENV['LINUX64'] = '1'
        when :solaris
          ENV['SOLARIS64'] = '1'
        end
      end

      if OS::windows?
        ENV['PATH'] = [PATH, File.join(ENV['DEVTOOLS_ROOT'], 'vc/bin')].join ';'
      end
    end

    cmdline ||= 'mvn install -fn'

    if File.directory? path
      Dir.chdir path do
        status = true

        errors = nil
        lines = []

        if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            if line =~ /(Press any key to continue|请按任意键继续)/
              stdin.puts
            end

            Util::Logger::puts line
            lines << line
          end

          status = false
        end

        errors = mvn_errors lines

        if not errors.nil?
          status = false
        end

        if not status
          if not errors.nil?
            if _retry
              status = true

              if cmdline =~ /mvn\s+deploy/
                cmdline = 'mvn deploy -fn'
              else
                cmdline = 'mvn install -fn'
              end

              modules = []

              errors[:failure].each do |k, v|
                if v.last.nil?
                  next
                end

                modules << v.last
              end

              errors[:skipped].each do |k, v|
                if v.last.nil?
                  next
                end

                modules << v.last
              end

              modules.uniq!

              if modules.size == 1
                if File.expand_path(modules.first) == Dir.pwd
                  modules = []
                end
              end

              errors = nil

              if not modules.empty?
                tmpfile = 'tmpdir/pom.xml'

                File.delete File.dirname(tmpfile)

                begin
                  doc = REXML::Document.file 'pom.xml'

                  REXML::XPath.each doc, '/project/build' do |e|
                    doc.root.delete e
                  end

                  REXML::XPath.each doc, '/project/profiles' do |e|
                    doc.root.delete e
                  end

                  REXML::XPath.each doc, '/project/artifactId' do |e|
                    e.text = "#{e.text.to_s.strip}-tmpdir"

                    break
                  end

                  REXML::XPath.each doc, '//modules' do |e|
                    e.children.each do |element|
                      e.delete element
                    end
                  end

                  REXML::XPath.each doc, '//modules' do |e|
                    modules.each do |module_name|
                      element = REXML::Element.new 'module'
                      element.text = File.join '..', module_name
                      e << element
                    end

                    break
                  end

                  doc.to_file tmpfile
                rescue
                  Util::Logger::exception $!
                end

                if File.file? tmpfile
                  Dir.chdir File.dirname(tmpfile) do
                    lines = []

                    if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                        if line =~ /(Press any key to continue|请按任意键继续)/
                          stdin.puts
                        end

                        Util::Logger::puts line
                        lines << line
                      end

                      status = false
                    end

                    errors = mvn_errors lines

                    if not errors.nil?
                      status = false
                    end
                  end
                else
                  status = false
                end

                File.delete File.dirname(tmpfile)
              else
                lines = []

                if not CommandLine::cmdline cmdline do |line, stdin, wait_thr|
                    if line =~ /(Press any key to continue|请按任意键继续)/
                      stdin.puts
                    end

                    Util::Logger::puts line
                    lines << line
                  end

                  status = false
                end

                errors = mvn_errors lines

                if not errors.nil?
                  status = false
                end
              end
            end
          end
        end

        if not errors.nil?
          if block_given?
            if yield errors
              errors_puts errors

              if sendmail
                errors_mail errors, args
              end
            end
          else
            errors_puts errors

            if sendmail
              errors_mail errors, args
            end
          end
        end

        status
      end
    else
      Util::Logger::error 'no such directory - %s' % path

      false
    end
  end

  def check_xml home, sendmail = false
    xmls = []

    POM::modules(home).each do |dir|
      File.glob(File.join(dir, '{src,include,*conf*}/**/*.xml')).each do |file|
        xmls << File.expand_path(file)
      end
    end

    if File.directory? File.join(home, '../../public')
      File.glob(File.join(home, '../../public/**/*.xml')).each do |file|
        xmls << File.expand_path(file)
      end
    end

    xmls.uniq!

    errors = {}

    xmls.each do |file|
      begin
        REXML::Document.file file
      rescue
        lineno = nil
        lines = []

        $!.to_s.lines do |line|
          line.rstrip!

          if line =~ /^Line:/
            lineno = $'.strip.to_i
          end

          lines << line
        end

        errors[:error] ||= {}
        errors[:error][file] = {
          :list => {
            lineno:   lineno,
            message:  lines
          }
        }
      end
    end

    if not errors.empty?
      if block_given?
        if yield errors
          errors_puts errors

          if sendmail
            errors_mail errors, subject: '<CHECK 通知>XML文件格式错误, 请尽快处理'
          end
        end
      else
        errors_puts errors

        if sendmail
          errors_mail errors, subject: '<CHECK 通知>XML文件格式错误, 请尽快处理'
        end
      end

      false
    else
      true
    end
  end

  def check_size home, sendmail = false, addrs = nil
    errors = []

    if File.directory? home
      Dir.chdir home do
        File.glob('**/*').each do |file|
          file = File.normalize file

          if not File.file? file
            next
          end

          if block_given?
            if not yield file, nil
              next
            end
          end

          if file.include? 'ums-server'
            if file.bytesize <= BN_MAX_SIZE_SERVER
              next
            end
          else
            if file.bytesize <= BN_MAX_SIZE_CLIENT
              next
            end
          end

          errors << file
        end
      end
    end

    if not errors.empty?
      if block_given?
        if yield nil, errors
          errors.each do |file|
            Util::Logger::error file
          end

          if sendmail
            subject = '<CHECK 通知>文件名超长(客户端最大%s个字符, 服务端最大%s个字符), 请尽快处理' % [BN_MAX_SIZE_CLIENT, BN_MAX_SIZE_SERVER]

            lines = []

            if ENV.has_key? 'BUILD_URL'
              http = File.join ENV['BUILD_URL'], 'console'

              lines <<  'Jenkins日志: <font color = "blue"><a href="%s">%s</a></font><br>' % [http, http]
              lines << '<br>'
            end

            errors.each do |file|
              lines << '%s<br>' % file
            end

            opt = {
              :subject  => 'Subject: %s' % subject,
              :html     => lines.join("\n")
            }

            Net::send_smtp nil, nil, addrs, opt
          end
        end
      else
        errors.each do |file|
          Util::Logger::error file
        end

        if sendmail
          subject = '<CHECK 通知>文件名超长(客户端最大%s个字符, 服务端最大%s个字符), 请尽快处理' % [BN_MAX_SIZE_CLIENT, BN_MAX_SIZE_SERVER]

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

      false
    else
      true
    end
  end

  # errors
  #   :error
  #     file
  #       :list
  #         -
  #           :lineno
  #           :message
  #           :build
  #       :scm
  #         :author
  #         :mail
  #         :rev
  #         :date
  #   :failure
  #     module_name:
  #       - line
  #       - path
  #   :skipped
  #     module_name:
  #       - line
  #       - path
  def mvn_errors lines
    status = nil
    last_lines = []

    start = false
    file = nil
    lineno = nil
    error_lines = []
    cur_lines = []

    info = {
      :error    => {},
      :failure  => {},
      :skipped  => {}
    }

    map = POM::artifactid_paths
    cur_artifactid = nil

    lines.each_with_index do |line, index|
      line = line.rstrip
      cur_lines << line

      line.strip!

      if line =~ /^\[INFO\]\s+Reactor\s+Build\s+Order:$/
        if not file.nil?
          if cur_lines.first =~ /^\[INFO\]\s+----+$/
            cur_lines.shift
          end

          info[:error][file] ||= {
            :list => []
          }

          info[:error][file][:list] << {
            lineno:   lineno,
            message:  error_lines,
            build:    cur_lines
          }
        end

        start = true
        file = nil
        lineno = nil
        error_lines = []
        cur_lines = []

        next
      end

      if line =~ /^\[INFO\]\s+Reactor\s+Summary:$/
        start = false
        file = nil
        lineno = nil
        error_lines = []
        cur_lines = []

        next
      end

      if line =~ /^\[INFO\]\s+Building\s+/
        start = true
      end

      if line =~ /^\[INFO\]\s+BUILD\s+(SUCCESS|FAILURE)$/
        if $1 == 'SUCCESS'
          status ||= true
        else
          status = false

          last_lines = lines[index..-1]
        end
      end

      if line =~ /^\[INFO\]\s+Total\s+time\s*:/
        cur_lines.each do |tmp_line|
          tmp_line.strip!

          if tmp_line =~ /^\[INFO\]\s+(.*?)\s+\.+\s*FAILURE/
            info[:failure][$1] = [tmp_line, nil]
          end

          if tmp_line =~ /^\[INFO\]\s+(.*?)\s+\.+\s*SKIPPED/
            info[:skipped][$1] = [tmp_line, nil]
          end
        end

        start = false
        file = nil
        lineno = nil
        error_lines = []
        cur_lines = []

        next
      end

      if line =~ /^\[INFO\]\s+----+$/
        next
      end

      if start
        if line =~ /^\[INFO\]\s+Building\s+/
          cur_artifactid = $'.split(/\s+/).first

          if not file.nil?
            if cur_lines.first =~ /^\[INFO\]\s+----+$/
              cur_lines.shift
            end

            info[:error][file] ||= {
              :list => []
            }

            info[:error][file][:list] << {
              lineno:   lineno,
              message:  error_lines,
              build:    cur_lines
            }
          end

          file = nil
          lineno = nil
          error_lines = []
          cur_lines = [
            line
          ]

          if index > 1 and lines[index - 1] =~ /^\[INFO\]\s+----+$/
            cur_lines.insert 0, lines[index - 1].strip
          end

          next
        end

        if line =~ /^\[ERROR\]\s+(.+):\[(\d+),\d+\]/ or line =~ /^\[ERROR\]\s+(.+)\[(\d+):\d+\]/
          match_data = $~

          if not file.nil?
            if cur_lines.first =~ /^\[INFO\]\s+----+$/
              cur_lines.shift
            end

            info[:error][file] ||= {
              :list => []
            }

            info[:error][file][:list] << {
              lineno:   lineno,
              message:  error_lines,
              build:    cur_lines
            }
          end

          file = match_data[1].strip
          lineno = match_data[2].to_i
          error_lines = [
            line
          ]

          if OS::windows?
            if file.start_with? '/'
              file = file[1..-1]
            end
          end

          if file =~ /\/src\/testSrc\//
            test_file = File.join $`, 'testSrc', $'

            if File.exist? test_file
              file = test_file
            end
          end

          if not File.exist? file
            if not map[cur_artifactid].nil?
              file = File.expand_path file, map[cur_artifactid]
            end
          end

          next
        end

        if line =~ /^\[INFO\]\s+\d+\s+(error|errors)$/
          if not file.nil?
            if cur_lines.first =~ /^\[INFO\]\s+----+$/
              cur_lines.shift
            end

            info[:error][file] ||= {
              :list => []
            }

            info[:error][file][:list] << {
              lineno:   lineno,
              message:  error_lines,
              build:    cur_lines
            }
          end

          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        if line =~ /^Tests\s+run\s*:\s*(\d+)\s*,\s*Failures\s*:\s*(\d+)\s*,\s*Errors\s*:\s*(\d+)\s*,\s*Skipped\s*:\s*(\d+)$/
          if $2.to_i > 0 or $3.to_i > 0
            cur_lines.each_with_index do |tmp_line, i|
              tmp_line = tmp_line.strip

              if tmp_line =~ /Surefire\s+report\s+directory\s*:\s*(.*)[\/\\]target[\/\\]surefire-reports$/
                file = $1

                if file =~ /\/src\/testSrc\//
                  test_file = File.join $`, 'testSrc', $'

                  if File.exist? test_file
                    file = test_file
                  end
                end

                next
              end

              if i > 0 and cur_lines[i - 1].strip =~ /^T\s*E\s*S\s*T\s*S$/ and tmp_line =~ /^----+$/
                error_lines = cur_lines[i + 1..-1]

                break
              end
            end

            if not file.nil?
              info[:error][file] ||= {
                :list => []
              }

              info[:error][file][:list] << {
                lineno:   lineno,
                message:  error_lines,
                build:    cur_lines
              }
            end

            file = nil
            lineno = nil
            error_lines = []
            cur_lines = []
          end

          next
        end

        # linux
        #   /:\s*(\d+)\s*:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
        #
        # solaris
        #   /,\s*第\s*(\d+)\s*行:\s*(error|错误)\s*,/
        #
        # windows
        #   /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
        #   /:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
        if line =~ /:\s*(\d+)\s*:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/ or
          line =~ /,\s*第\s*(\d+)\s*行:\s*(error|错误)\s*,/ or
          line =~ /\((\d+)\)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/ or line =~ /:\s*(\d+)\s*:\s*\w*\s*(error|错误)\s*\w*\d*(:|：)/
          file = $`.strip.nil
          lineno = $1.to_i

          if file =~ /^"(.*)"$/
            file = $1.strip.nil
          end

          if file =~ /\/src\/testSrc\//
            test_file = File.join $`, 'testSrc', $'

            if File.exist? test_file
              file = test_file
            end
          end

          if not file.nil?
            file = File.normalize file

            info[:error][file] ||= {
              :list => []
            }

            if not info[:error][file][:list].empty? and info[:error][file][:list].last[:lineno] == lineno
              info[:error][file][:list][-1][:message] << line
              info[:error][file][:list][-1][:build] += cur_lines
            else
              info[:error][file][:list] << {
                lineno:   lineno,
                message:  [line],
                build:    cur_lines
              }
            end
          end

          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        # linux
        #   /:\s*(\d+)\s*:\s*undefined\s+reference\s+/
        #   /collect2\s*:\s*ld\s+/
        #
        # solaris
        #   /\s*(\(|（)(符号范围指定本机绑定)(\)|）)/
        #   /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors.\s+No\s+output\s+written\s+to\s+/
        #
        # windows
        #   /:\s*error\s+LNK\d+\s*:/
        #   /\s*:\s*fatal\s+error\s+LNK\d+\s*:/

        if line =~ /collect2\s*:\s*ld\s+/ or
          line =~ /ld\s*:\s*.*:\s*symbol\s+referencing\s+errors.\s+No\s+output\s+written\s+to\s+/ or
          line =~ /\s*:\s*fatal\s+error\s+LNK\d+\s*:/

          file = Dir.pwd

          error_lines = []

          cur_lines.each_with_index do |x, index|
            if x =~ /:\s*(\d+)\s*:\s*undefined\s+reference\s+/
              if index > 0
                if cur_lines[index - 1] =~ /\s*:\s*In\s+function\s+.*:/
                  error_lines << cur_lines[index - 1]
                end
              end

              error_lines << x

              next
            end

            if x =~ /\s*(\(|（)(符号范围指定本机绑定)(\)|）)/
              error_lines << x

              next
            end

            if x =~ /:\s*error\s+LNK\d+\s*:/ or x =~ /\s*:\s*fatal\s+error\s+LNK\d+\s*:/
              error_lines << x

              next
            end
          end

          if not file.nil?
            file = File.normalize file

            info[:error][file] ||= {
              :list => []
            }

            if not info[:error][file][:list].empty?
              info[:error][file][:list][-1][:message] << line
              info[:error][file][:list][-1][:build] += cur_lines
            else
              info[:error][file][:list] << {
                lineno:   nil,
                message:  error_lines,
                build:    cur_lines
              }
            end
          end

          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        # daobuilder
        #   /^\[exec\].*\s+error\s*:\s*file\s*:\s*(.*\.xml)/
        if line =~ /^\[exec\].*\s+error\s*:\s*file\s*:\s*(.*\.xml)/
          file = $1.strip.nil

          if cur_lines.size <= 5
            error_lines = cur_lines
          else
            error_lines = cur_lines[-5..-1]
          end

          if lines.size > index + 1
            lines[index + 1 .. index + 10].each do |tmp_line|
              tmp_line.strip!

              if tmp_line =~ /^\[exec\].*\s+error\s*:\s*file\s*:\s*(.*\.xml)/
                break
              end

              if tmp_line =~ /^\[exec\].*\s+error\s*/
                error_lines << tmp_line
              end
            end
          end

          if not file.nil?
            file = File.normalize file

            info[:error][file] ||= {
              :list => []
            }

            if not info[:error][file][:list].empty?
              info[:error][file][:list][-1][:message] += error_lines
              info[:error][file][:list][-1][:build] += cur_lines
            else
              info[:error][file][:list] << {
                lineno:   nil,
                message:  error_lines,
                build:    cur_lines
              }
            end
          end

          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end

        # asn1
        #   /^\[exec\].*file\s*\"(.*)\",\s*line\s*(\d+)\s*:\s*parse\s+error\s+/
        if line =~ /^\[exec\].*file\s*\"(.*)\",\s*line\s*(\d+)\s*:\s*parse\s+error\s+/
          file = $1.strip.nil

          if cur_lines.size <= 5
            error_lines = cur_lines
          else
            error_lines = cur_lines[-5..-1]
          end

          if lines.size > index + 1
            lines[index + 1 .. index + 10].each do |tmp_line|
              tmp_line.strip!

              if tmp_line =~ /^\[exec\].*file\s*\"(.*)\",\s*line\s*(\d+)\s*:\s*parse\s+error\s+/
                break
              end

              if tmp_line =~ /^\[exec\]\s*Parsing\s+errors/
                error_lines << tmp_line
              end
            end
          end

          if not file.nil?
            file = File.normalize file

            info[:error][file] ||= {
              :list => []
            }

            if not info[:error][file][:list].empty?
              info[:error][file][:list][-1][:message] += error_lines
              info[:error][file][:list][-1][:build] += cur_lines
            else
              info[:error][file][:list] << {
                lineno:   nil,
                message:  error_lines,
                build:    cur_lines
              }
            end
          end

          file = nil
          lineno = nil
          error_lines = []
          cur_lines = []

          next
        end
      else
        if line =~ /^\[ERROR\]/
          error_lines << line

          if line =~ /\((.+)\)\s+has\s+\d+\s+error/
            file = $1
          end

          next
        end
      end

      if not error_lines.empty?
        error_lines << line
      end
    end

    if not file.nil?
      if cur_lines.first =~ /^\[INFO\]\s+----+$/
        cur_lines.shift
      end

      info[:error][file] ||= {
        :list => []
      }

      info[:error][file][:list] << {
        lineno:   lineno,
        message:  error_lines,
        build:    cur_lines
      }
    end

    info[:failure].each do |k, v|
      if map.has_key? k
        info[:failure][k] = [v, File.relative_path(map[k])]
      end
    end

    info[:skipped].each do |k, v|
      if map.has_key? k
        info[:skipped][k] = [v, File.relative_path(map[k])]
      end
    end

    if not info[:failure].empty?
      if info[:error].empty?
        info[:failure].each do |k, v|
          file = File.expand_path v.last

          info[:error][file] ||= {
            :list => []
          }

          info[:error][file][:list] << {
            lineno:   nil,
            message:  v.first,
            build:    v.first
          }
        end
      end
    end

    if status != true
      # name = nil
      # error_lines = []
      #
      # last_lines.each do |line|
      #   line.strip!
      #
      #   if line =~ /^\[ERROR\]\s+Failed\s+to\s+execute\s+.*\s+on\s+project\s+([\w_-]+):/
      #     name = $1
      #   end
      #
      #   if not name.nil?
      #     error_lines << line
      #   end
      #
      #   if line =~ /^\[ERROR\]\s+.*->\s+\[Help\s+1\]$/
      #     if not name.nil?
      #       dirname = map[name]
      #
      #       if not dirname.nil?
      #         found = false
      #
      #         info[:error].keys.each do |file|
      #           if File.include? dirname, file
      #             found = true
      #
      #             break
      #           end
      #         end
      #
      #         if not found
      #           info[:error][dirname] ||= {
      #             :list => []
      #           }
      #
      #           info[:error][dirname][:list] << {
      #             lineno:   nil,
      #             message:  error_lines,
      #             build:    error_lines
      #           }
      #         end
      #       end
      #     end
      #
      #     name = nil
      #     error_lines = []
      #   end
      # end
    end

    if status
      nil
    else
      mvn_scminfo info
    end
  end

  def errors_puts errors
    Util::Logger::puts ''
    Util::Logger::puts '=' * 60
    Util::Logger::puts ''

    errors[:error].each do |file, info|
      Util::Logger::puts ''
      Util::Logger::puts file

      if not info[:scm].nil?
        Util::Logger::puts '责任人: %s' % info[:scm][:author]
        Util::Logger::puts '版本: %s' % info[:scm][:rev]
        Util::Logger::puts '日期: %s' % info[:scm][:date]
      end

      Util::Logger::puts '-' * 60

      info[:list].each_with_index do |x, index|
        if index > 0
          Util::Logger::puts ''
        end

        Util::Logger::puts '%s行号: %s' % [INDENT, x[:lineno]]

        x[:message].each do |line|
          Util::Logger::puts '%s%s' % [INDENT, line]
        end
      end

      Util::Logger::puts ''
    end

    if not errors[:failure].empty?
      Util::Logger::puts '=' * 60
      Util::Logger::puts ''

      errors[:failure].each do |k, v|
        Util::Logger::puts '%s(%s)' % [v[0], v[1]]
      end

      Util::Logger::puts ''
    end

    Util::Logger::puts '=' * 60
  end

  def errors_mail errors, args = nil
    args ||= {}

    map = {}

    default_map = nil

    errors[:error].each do |file, info|
      if not info[:scm].nil?
        if info[:scm][:date].is_a? Time
          if info[:scm][:date] < (Time.now - MAIL_THRESHOLD_DAY * 24 * 3600)
            if $mail_threshold
              if default_map.nil?
                addrs = args[:addrs] || info[:scm][:mail] || $mail_admin

                if not addrs.nil?
                  default_map = {}
                  default_map[addrs] ||= {}
                  default_map[addrs][file] = info
                end
              end

              next
            end
          end
        end
      end

      addrs = args[:addrs] || info[:scm][:mail] || $mail_admin

      if not addrs.nil?
        map[addrs] ||= {}
        map[addrs][file] = info
      end
    end

    if map.empty?
      if not default_map.nil?
        map = default_map
      end
    end

    status = true

    opt = {}

    opt[:admin] = (args[:admin] || []).to_array + ($mail_admin || []).to_array
    opt[:admin].uniq!

    opt[:cc] = (args[:cc] || []).to_array + ($mail_cc || []).to_array
    opt[:cc].uniq!

    map.each do |addrs, addrs_info|
      if $x64
        opt[:subject] = 'Subject: %s(%s-X64)' % [(args[:subject] || '<BUILD 通知>编译失败, 请尽快处理'), OS::name]
      else
        opt[:subject] = 'Subject: %s(%s)' % [(args[:subject] || '<BUILD 通知>编译失败, 请尽快处理'), OS::name]
      end

      lines = []

      if ENV.has_key? 'BUILD_URL'
        http = File.join ENV['BUILD_URL'], 'console'

        lines <<  'Jenkins日志: <font color = "blue"><a href="%s">%s</a></font><br>' % [http, http]
        lines << '<br>'
      end

      lines << '操作系统: <font color = "blue">%s</font><br>' % OS::name
      lines << '当前目录: <font color = "blue">%s</font><br>' % Dir.pwd
      lines << '<br>'

      build_info = {}

      addrs_info.each do |file, info|
        lines << '<h3><a href = "%s">%s</a></h3><br>' % [file, file]
        lines << '<pre>'

        if not info[:scm].nil? and not info[:scm][:author].nil?
          lines << '<b>责任人: <font color = "red">%s</font></b><br>' % info[:scm][:author]
          lines << '<b>版本: %s</b>' % info[:scm][:rev]
          lines << '<b>日期: %s</b>' % info[:scm][:date]
        end

        lines << ''

        message_info = []

        info[:list].each do |x|
          message_info << {
            :lineno   => x[:lineno],
            :message  => x[:message]
          }

          if x[:build]
            build_info[file] ||= []
            build_info[file] << x[:build]
          end
        end

        message_info.uniq.each do |message|
          lines << '<b>行号: %s</b>' % message[:lineno]
          lines << ''

          message[:message].each do |line|
            lines << line
          end

          lines << ''
        end

        lines << '</pre>'
        lines << '<br>'
      end

      opt[:html] = lines.join "\n"

      if not Net::send_smtp nil, nil, addrs, opt do |mail|
          File.tmpdir do |dir|
            build_info.each do |k, v|
              filename = File.join dir, 'build(%s).log' % File.basename(k.to_s, '.*')

              File.open filename, 'w' do |file|
                v.each_with_index do |build, index|
                  if index > 0
                    file.puts
                    file.puts '=' * 60
                    file.puts
                  end

                  file.puts build
                end
              end

              mail.attach filename.locale
            end
          end
        end

        status = false
      end
    end

    status
  end

  def mvn_scminfo errors
    errors[:error].each do |file, info|
      scminfo = POM::scm_info file

      if scminfo.nil?
        info[:scm] = {
          :author => nil,
          :mail   => nil,
          :rev    => nil,
          :date   => nil
        }

        if File.exists? file
          info[:scm][:date] = File.mtime file
        end
      else
        author = scminfo[:author]
        mail = scminfo[:mail]

        if not author.nil?
          if not mail.to_s.include? '@zte.com.cn'
            if author =~ /\d+$/
              mail = '%s@zte.com.cn' % $&.strip
            end
          end
        end

        info[:scm] = {
          :author => author,
          :mail   => mail,
          :rev    => scminfo[:rev],
          :date   => scminfo[:date]
        }
      end
    end

    errors
  end

  class << self
    private :mvn_scminfo
  end
end