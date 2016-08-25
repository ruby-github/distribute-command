require 'fileutils'
require 'pathname'

class File
  class << self
    alias __expand_path__ expand_path
    alias __join__ join
    alias __open__ open
  end

  def self.expand_path filename, dir = nil
    filename = filename.utf8.strip

    if not dir.nil?
      dir = dir.utf8.strip
    end

    __expand_path__(filename, dir).utf8
  end

  def self.join *args
    if absolute? args.last
      args.last.utf8
    else
      __join__ args.utf8
    end
  end

  def self.open filename, mode = 'r', *args
    if args.last.is_a? Hash
      options = args.pop
    else
      options = {}
    end

    create = false

    if mode.is_a? Integer
      if (mode & File::CREAT) == File::CREAT
        create = true
      end
    else
      if not mode.strip.empty? and not mode.include? 'r'
        create = true
      end
    end

    filename = expand_path filename

    if not File.directory? File.dirname(filename) and create
      FileUtils.mkdir_p File.dirname(filename)
    end

    if block_given?
      __open__ filename, mode, args.first, options do |file|
        yield file
      end
    else
      __open__ filename, mode, args.first, options
    end
  end
end

class File
  def self.normalize filename
    if filename.empty?
      ''
    else
      filename = filename.utf8.gsub '\\', '/'

      if relative? filename
        relative_path filename
      else
        expand_path filename
      end
    end
  end

  def self.relative_path filename, dir = nil
    if dir.nil?
      dir = Dir.pwd
    end

    filename = expand_path filename
    dir = expand_path dir

    if not dir.end_with? '/'
      dir += '/'
    end

    begin
      Pathname.new(filename.locale).relative_path_from(Pathname.new(dir.locale)).to_s.utf8
    rescue
      filename
    end
  end

  def self.absolute? filename
    not relative? filename
  end

  def self.relative? filename
    Pathname.new(filename.locale.strip).relative?
  end

  def self.cmdline filename
    found = false

    filename.each_byte do |byte|
      if byte < 127
        if '-./:@[\]_{}~'.bytes.include? byte
          next
        end

        if OS::windows?
          if byte == 58
            next
          end
        end

        if byte >= 48 and byte <= 57
          next
        end

        if byte >= 65 and byte <= 90
          next
        end

        if byte >= 97 and byte <= 122
          next
        end

        found = true

        break
      end
    end

    if found
      "%s" % filename.gsub('"', '\"')
    else
      filename
    end
  end

  def self.lock filename, mode = 'r+:utf-8'
    filename = expand_path filename

    if not file? filename
      open filename, 'w:utf-8' do |file|
      end
    end

    open filename, mode do |file|
      file.flock File::LOCK_EX

      yield file
    end
  end

  class << self
    alias absolute_path expand_path
  end
end

class File
  def self.glob xpath
    xpath = normalize xpath

    if File.exist? xpath
      [xpath]
    else
      if File::FNM_SYSCASE.nonzero?
        Dir.glob(xpath, File::FNM_CASEFOLD).sort.utf8
      else
        Dir.glob(xpath).sort.utf8
      end
    end
  end

  def self.pattern_split xpath
    xpath = normalize xpath

    if not File.exist? xpath
      if xpath =~ /\*|\?|\[.+\]|\{.+\}/
        dir = $`

        if dir.empty?
          dir = '.'
        else
          if dir.end_with? '/'
            dir.chop!
          else
            dir = dirname dir
          end

          xpath = xpath[dir.size + 1..-1]
        end

        [
          dir, xpath
        ]
      else
        [
          nil, xpath
        ]
      end
    else
      [
        nil, xpath
      ]
    end
  end

  def self.include? a, b
    a = expand_path a
    b = expand_path b

    if File::FNM_SYSCASE.nonzero?
      a = a.downcase
      b = b.downcase
    end

    a == b or b.start_with? a + File::SEPARATOR
  end

  def self.same_path? a, b, expand = false
    if expand
      a = expand_path a
      b = expand_path b
    else
      a = normalize a
      b = normalize b
    end

    if File::FNM_SYSCASE.nonzero?
      a.casecmp(b).zero?
    else
      a == b
    end
  end

  def self.root filename
    filename = expand_path filename

    if filename =~ /^(\w+:\/\/+[^\/\\]+)[\/\\]/
      $1
    else
      loop do
        dir, name = split filename

        if dir == '.'
          if not filename.start_with? './'
            return name
          end
        end

        if dir == filename
          return dir
        end

        filename = dir
      end
    end
  end
end

class File
  def self.tmpname
    '%s%04d' % [Time.now.timestamp, rand(1000)]
  end

  def self.tmpdir dir = nil, prefix = nil
    if dir.nil?
      dir = Dir.tmpdir
    end

    if prefix.nil?
      tmpdir = File.join dir, tmpname
    else
      tmpdir = File.join dir, '%s_%s' % [prefix, tmpname]
    end

    if block_given?
      begin
        FileUtils.mkdir_p tmpdir

        yield tmpdir
      ensure
        FileUtils.rm_rf tmpdir
      end
    else
      tmpdir
    end
  end
end

class File
  def self.mkdir paths
    status = true

    paths.to_array.each do |path|
      path = normalize path

      if File.directory? path
        next
      end

      if block_given?
        yield path
      end

      begin
        FileUtils.mkdir_p path
      rescue
        Util::Logger::exception $!

        status = false
      end
    end

    status
  end

  def self.copy src, dest, preserve = true
    if same_path? src, dest, true
      return true
    end

    status = true

    copy_info(src, dest).each do |dest_file, src_file|
      if block_given?
        src_file, dest_file = yield src_file, dest_file

        if src_file.nil?
          next
        end
      end

      begin
        case
        when file?(src_file)
          if not directory? dirname(dest_file)
            FileUtils.mkdir_p dirname(dest_file)
          end

          begin
            FileUtils.copy_file src_file, dest_file, preserve
          rescue
            FileUtils.copy_file src_file, dest_file, false

            if preserve
              File.utime File.atime(src_file), File.mtime(src_file), dest_file
            end
          end
        when directory?(src_file)
          if not directory? dest_file
            FileUtils.mkdir_p dest_file
          end
        else
          raise Errno::ENOENT, src_file
        end
      rescue
        Util::Logger::exception $!

        status = false
      end
    end

    status
  end

  def self.move src, dest, force = false
    src = normalize src
    dest = normalize dest

    if same_path? src, dest, true
      return true
    end

    if same_path? root(src), root(dest)
      map = {}

      dir, pattern = pattern_split src

      if dir
        if directory? dir
          Dir.chdir dir do
            glob(pattern).each do |file|
              src_file = join dir, file
              dest_file = join dest, file

              map[src_file] = dest_file
            end
          end
        end
      else
        map[src] = dest
      end

      status = true

      map.each do |src_file, dest_file|
        if file? src_file or not exist? dest_file
          if block_given?
            srcfile = yield srcfile
          end

          if src_file.nil?
            delete src_file

            next
          end

          begin
            if not directory? dirname(dest_file)
              FileUtils.mkdir_p dirname(dest_file)
            end

            FileUtils.move src_file, dest_file
          rescue
            exception = $!

            if not copy src_file, dest_file or not delete src_file
              Util::Logger::exception exception

              status = false
            end
          end
        else
          if copy src, dest do |srcfile, destfile|
              if block_given?
                srcfile = yield srcfile
              end

              [srcfile, destfile]
            end

            if not delete srcfile
              status = false
            end
          else
            status = false
          end
        end
      end

      status
    else
      if not copy src, dest do |src_file, dest_file|
          if block_given?
            src_file = yield src_file
          end

          [src_file, dest_file]
        end

        return false
      end

      if not delete src
        return false
      end

      true
    end
  end

  def self.delete paths
    status = true

    paths.to_array.each do |path|
      path = normalize path

      glob(path).each do |file|
        list = []

        if directory? file
          list += glob(join(file, '**/*')).reverse
        end

        list << file

        list.each do |filename|
          if block_given?
            filename = yield filename
          end

          if filename.nil?
            next
          end

          FileUtils.rm_rf filename

          if exist? filename
            Util::Logger::error 'No delete file or directory - %s' % filename

            status = false
          end
        end
      end
    end

    status
  end

  def self.copy_info src, dest
    src = normalize src

    if dest.nil?
      dest = '.'
    else
      dest = normalize dest
    end

    info = {}
    dir, pattern = pattern_split src

    if dir
      if directory? dir
        list = []

        glob(File.join(dir, pattern)).each do |file|
          list << file

          if directory? file
            list += glob join(file, '**/*')
          end
        end

        list.each do |file|
          dest_file = join dest, file[(dir.size + 1)..-1]

          info[dest_file] = file
        end
      end
    else
      info[dest] = src

      if directory? src
        list = glob File.join(src, '**/*')

        list.each do |file|
          dest_file = join dest, file[(src.size + 1)..-1]

          info[dest_file] = file
        end
      end
    end

    info
  end
end

class Pathname
  private

  def chop_basename path
    base = File.basename path

    if /\A#{SEPARATOR_PAT}?\z/o =~ base
      return nil
    else
      return path[0, path.rindex(base) || 0], base
    end
  end
end