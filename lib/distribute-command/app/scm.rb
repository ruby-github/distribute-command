module SCM
  module_function

  def info path, args = nil, username = nil, password = nil
    case scm(path)
    when :svn
      SVN::info path, args, username, password
    when :git
      GIT::info path, args, username, password
    when :tfs
      TFS::info path, args, username, password
    else
      nil
    end
  end

  def log path, args = nil, username = nil, password = nil
    case scm(path)
    when :svn
      SVN::log path, args, username, password
    when :git
      GIT::log path, args, username, password
    when :tfs
      TFS::log path, args, username, password
    else
      nil
    end
  end

  def update path, repo = nil, args = nil, username = nil, password = nil, restore = false
    if File.exist? path
      case scm(path)
      when :svn
        SVN::update path, repo, args, username, password, restore
      when :git
        GIT::update path, repo, args, username, password, restore
      when :tfs
        TFS::update path, repo, args, username, password, restore
      else
        nil
      end
    else
      case
      when repo.end_with?(':svn')
        SVN::update path, repo[0..-5], args, username, password, restore
      when repo.end_with?(':git')
        GIT::update path, repo[0..-5], args, username, password, restore
      when repo.end_with?(':tfs')
        TFS::update path, repo[0..-5], args, username, password, restore
      else
        case
        when repo.include?('svn')
          SVN::update path, repo, args, username, password, restore
        when repo.include?('git')
          GIT::update path, repo, args, username, password, restore
        when args.to_s.start_with?('$/')
          TFS::update path, repo, args, username, password, restore
        else
          nil
        end
      end
    end
  end

  def revert path
    case scm(path)
    when :svn
      SVN::revert path
    when :git
      GIT::revert path
    when :tfs
      TFS::revert path
    else
      nil
    end
  end

  def cleanup path
    case scm(path)
    when :svn
      SVN::cleanup path
    when :git
      GIT::cleanup path
    when :tfs
      TFS::cleanup path
    else
      nil
    end
  end

  def scm path = nil
    scm_home = home path

    if not scm_home.nil?
      if File.directory? File.join(scm_home, '.svn') or File.directory? File.join(scm_home, '_svn')
        return :svn
      end

      if File.directory? File.join(scm_home, '.git')
        if GIT::config(scm_home, 'git-tf.server.collection').nil?
          return :git
        else
          return :tfs
        end
      end
    end

    nil
  end

  def home path = nil
    path ||= '.'
    path = File.expand_path path

    loop do
      if File.directory? File.join(path, '.svn') or File.directory? File.join(path, '_svn')
        return path
      end

      if File.directory? File.join(path, '.git')
        return path
      end

      if File.dirname(path) == path
        break
      end

      path = File.dirname path
    end

    nil
  end
end

module SVN
  module_function

  def info path, args = nil, username = nil, password = nil
    username ||= $username
    password ||= $password

    cmdline = 'svn info'

    if not args.nil?
      cmdline += ' %s' % args
    end

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username, password]
    end

    cmdline += ' %s' % File.cmdline(path)

    info = {
      :url    => nil,
      :root   => nil,
      :author => nil,
      :mail   => nil,
      :rev    => nil,
      :date   => nil
    }

    if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        authorization line, stdin

        Util::Logger::puts line
        line = line.strip

        case
        when line =~ /^(URL)(:|：)/
          info[:url] = $'.strip.gsub '%20', ' '
        when line =~ /^(Repository Root|版本库根)(:|：)/
          info[:root] = $'.strip.gsub '%20', ' '
        when line =~ /^(Last Changed Author|最后修改的作者)(:|：)/
          info[:author] = $'.strip
        when line =~ /^(Last Changed Rev|最后修改的版本|最后修改的修订版)(:|：)/
          info[:rev] = $'.strip
        when line =~ /^(Last Changed Date|最后修改的时间)(:|：)/
          begin
            info[:date] = Time.parse $'.strip[0..24]
          rescue
            Util::Logger::exception $!

            info[:date] = nil
          end
        end
      end

      info
    else
      nil
    end
  end

  def log path, args = nil, username = nil, password = nil
    username ||= $username
    password ||= $password

    cmdline = 'svn log'

    if not args.nil?
      cmdline += ' %s' % args
    end

    if not username.nil? and not password.nil?
      cmdline += ' --username %s --password %s' % [username, password]
    end

    cmdline += ' %s' % File.cmdline(path)

    lines = []

    if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        authorization line, stdin

        Util::Logger::puts line
        lines << line.strip
      end

      list = []

      lines.split { |line| line =~ /^-+$/ }.each do |x|
        if x.shift =~ /^r(\d+)\s+\|\s+(.+)\s+\|\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+[+-]\d{4})\s+.*/
          rev = $1.strip
          author = $2.strip

          begin
            date = Time.parse $3.to_s.strip[0..24]
          rescue
            Util::Logger::exception $!

            date = nil
          end

          change_files = {}
          comment = []

          start = false
          x.each do |line|
            if not start
              if ['Changed paths:', '改变的路径:'].include? line
                start = true

                next
              end
            end

            if start
              if line.empty?
                start = false
              else
                if line =~ /^\s*([A-Z])\s+(.*)$/
                  flag = $1.strip
                  name = $2.strip

                  if name.start_with? '/'
                    name = name[1..-1]
                  end

                  if name =~ /\(from\s+.*:\d+\)$/
                    name = $`.strip
                  end

                  case flag
                  when 'A'
                    change_files[:add] ||= []
                    change_files[:add] << name
                  when 'D'
                    change_files[:delete] ||= []
                    change_files[:delete] << name
                  else
                    change_files[:update] ||= []
                    change_files[:update] << name
                  end
                end
              end
            else
              comment << line
            end
          end

          list << {
            rev:          rev,
            author:       author,
            mail:         nil,
            date:         date,
            change_files: change_files,
            comment:      comment
          }
        end
      end

      list.sort { |x, y| x[:rev].to_i <=> y[:rev].to_i }
    else
      nil
    end
  end

  def update path, repo = nil, args = nil, username = nil, password = nil, restore = false
    username ||= $username
    password ||= $password

    if restore
      revert path
    end

    if File.exist? path
      cmdline = 'svn update --force'

      if not args.nil?
        cmdline += ' %s' % args
      end

      if not username.nil? and not password.nil?
        cmdline += ' --username %s --password %s' % [username, password]
      end

      cmdline += ' %s' % File.cmdline(path)

      if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
          authorization line, stdin

          Util::Logger::puts line
        end

        true
      else
        if cleanup path
          CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            authorization line, stdin

            Util::Logger::puts line
          end
        else
          false
        end
      end
    else
      if not repo.nil?
        cmdline = 'svn checkout'

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not username.nil? and not password.nil?
          cmdline += ' --username %s --password %s' % [username, password]
        end

        cmdline += ' %s' % File.cmdline(repo)
        cmdline += ' %s' % File.cmdline(path)

        if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            authorization line, stdin

            Util::Logger::puts line
          end

          true
        else
          false
        end
      else
        Util::Logger::error 'svn repo is nil'

        false
      end
    end
  end

  def revert path
    if File.exist? path
      cmdline = 'svn revert -R'
      cmdline += ' %s' % File.cmdline(path)

      CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        Util::Logger::puts line
      end
    else
      true
    end
  end

  def cleanup path
    cmdline = 'svn cleanup'
    cmdline += ' %s' % File.cmdline(path)

    CommandLine::cmdline cmdline do |line, stdin, wait_thr|
      Util::Logger::puts line
    end
  end

  def authorization line, stdin
    case line
    when /\(p\)(ermanently|永远接受)(\?|？)/
      stdin.puts 'p'
    when /\(yes\/no\)\?/
      stdin.puts 'yes'
    when /\(mc\)\s*(mine-conflict|我的版本)\s*,\s*\(tc\)\s*(theirs-conflict|他人的版本)/
      sleep 1
      stdin.puts 'tc'
    end
  end

  class << self
    private :authorization
  end
end

module GIT
  module_function

  def info path, args = nil, username = nil, password = nil
    username ||= $username
    password ||= $password

    logs = log path, '-1', username, password

    if not logs.nil? and not logs.empty?
      info = logs.first

      info.delete :change_files
      info.delete :comment

      info[:url] = config path, 'remote.origin.url'
      info[:root] = home path

      info
    else
      nil
    end
  end

  def log path, args = nil, username = nil, password = nil
    username ||= $username
    password ||= $password

    if not path.nil?
      path = File.normalize path
    end

    dirname = home path

    if not dirname.nil?
      Dir.chdir dirname do
        cmdline = 'git log --stat=256'

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not path.nil?
          tmp_path = File.relative_path path, dirname

          if tmp_path != '.'
            cmdline += ' -- %s' % File.cmdline(tmp_path)
          end
        end

        lines = []

        if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            authorization line, stdin, username, password

            Util::Logger::puts line
            lines << line.strip
          end

          list = []

          lines.split(true) { |line| line =~ /^commit\s+[0-9a-fA-F]+$/ }.each do |x|
            if x.shift =~ /^commit\s+([0-9a-fA-F]+)$/
              rev = $1.strip
              author = nil
              mail = nil
              date = nil

              loop do
                line = x.shift

                if line.nil? or line.empty?
                  break
                end

                if line =~ /^Author:/
                  author = $'.strip

                  if author =~ /<(.*)>/
                    author = $`.strip

                    if $1.include? '@'
                      mail = $1.strip

                      if mail =~ /\\/
                        mail = $'.strip
                      end
                    end
                  end

                  next
                end

                if line =~ /^Date:/
                  begin
                    date = Time.parse $'.strip
                  rescue
                    Util::Logger::exception $!

                    date = nil
                  end

                  next
                end
              end

              comment = []

              loop do
                line = x.shift

                if line.nil? or line.empty?
                  break
                end

                comment << line
              end

              change_files = {}

              x.each do |line|
                if line =~ /\|\s+(\d+\s+([+-]*)|Bin\s+(\d+)\s+->\s+(\d+)\s+bytes)$/
                  name = $`.strip
                  match_data = $~

                  if name =~ /^\.{3}\//
                    name = File.glob(File.join('**', $')).first.to_s
                  end

                  if match_data[2].nil?
                    if match_data[3] == '0'
                      change_files[:add] ||= []
                      change_files[:add] << name
                    else
                      if match_data[4] == '0'
                        change_files[:delete] ||= []
                        change_files[:delete] << name
                      else
                        change_files[:update] ||= []
                        change_files[:update] << name
                      end
                    end
                  else
                    if match_data[2].include? '+' and match_data[2].include? '-'
                      change_files[:update] ||= []
                      change_files[:update] << name
                    else
                      if match_data[2].include? '+'
                        change_files[:add] ||= []
                        change_files[:add] << name
                      else
                        change_files[:delete] ||= []
                        change_files[:delete] << name
                      end
                    end
                  end
                end
              end

              list << {
                rev:          rev,
                author:       author,
                mail:         mail,
                date:         date,
                change_files: change_files,
                comment:      comment
              }
            end
          end

          list.reverse
        else
          nil
        end
      end
    else
      nil
    end
  end

  def update path, repo = nil, args = nil, username = nil, password = nil, restore = false
    username ||= $username
    password ||= $password

    if restore
      revert path
    end

    if File.exist? path
      dirname = home path

      if not dirname.nil?
        Dir.chdir dirname do
          cmdline = 'git pull'

          if block_given?
            cmdline = yield cmdline
          end

          if not args.nil?
            cmdline += ' %s' % args
          end

          if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
              authorization line, stdin, username, password

              Util::Logger::puts line
            end

            true
          else
            false
          end
        end
      else
        false
      end
    else
      if not repo.nil?
        cmdline = 'git clone'

        if block_given?
          cmdline = yield cmdline
        end

        repo.gsub! '/$/', ' $/'

        if not username.nil? and not password.nil?
          case
          when repo =~ /^(http|https):\/\//
            repo = '%s%s:%s@%s' % [$&, username, password, $']
          when repo =~ /^ssh:\/\//
            repo = '%s%s@%s' % [$&, username, $']
          end
        end

        if not args.nil?
          cmdline += ' %s -- %s' % [args, repo]
        else
          cmdline += ' %s' % repo
        end

        if not path.nil?
          cmdline += ' %s' % File.normalize(path)
        end

        if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            authorization line, stdin, username, password

            Util::Logger::puts line
          end

          true
        else
          false
        end
      else
        Util::Logger::error 'git repo is nil'

        false
      end
    end
  end

  def revert path
    if File.exist? path
      cmdline = 'git checkout'
      cmdline += ' -- %s' % File.cmdline(path)

      CommandLine::cmdline cmdline do |line, stdin, wait_thr|
        Util::Logger::puts line
      end
    else
      true
    end
  end

  def cleanup path
    true
  end

  def authorization line, stdin, username = nil, password = nil
    username ||= $username
    password ||= $password

    case line
    when /^Username.*:$/
      stdin.puts username
    when /^Password.*:$/
      stdin.puts password
    end
  end

  def config path, name = nil, args = nil
    dirname = home path

    if not dirname.nil?
      Dir.chdir dirname do
        cmdline = 'git config'

        if not args.nil?
          cmdline += ' %s' % args
        end

        if not name.nil?
          cmdline += ' -- %s' % name
        else
          cmdline += ' --list'
        end

        info = {}

        if CommandLine::cmdline cmdline do |line, stdin, wait_thr|
            if line.empty?
              next
            end

            k, v = line.split('=', 2).map { |x| x.strip }

            if v.nil?
              info[name] = k
            else
              info[k] = v
            end
          end

          if not name.nil?
            info[name]
          else
            info
          end
        else
          nil
        end
      end
    else
      nil
    end
  end

  def home path = nil
    path ||= '.'

    loop do
      if File.directory? File.join(path, '.git')
        return path
      end

      if File.dirname(path) == path
        break
      end

      path = File.dirname path
    end

    nil
  end

  class << self
    private :authorization, :home
  end
end

module TFS
  module_function

  def info path, args = nil, username = nil, password = nil
    GIT::info path, args, username, password
  end

  def log path, args = nil, username = nil, password = nil
    GIT::log path, args, username, password
  end

  def update path, repo = nil, args = nil, username = nil, password = nil, restore = false
    if restore
      revert path
    end

    GIT::update path, repo, args, username, password do |cmdline|
      cmdline.gsub 'git', 'git-tf'
    end
  end

  def revert path
    GIT::revert path
  end

  def cleanup path
    GIT::cleanup path
  end
end