require 'zip'

class ZipFile < Zip::File
  attr_accessor :auto_commit

  def initialize name, create = nil, buffer = false
    super

    @auto_commit = false
  end

  def list path = nil, all = false
    paths = []

    each_entry.each do |zip_path|
      filename = zip_path.to_s.utf8
      relative_path = File.relative_path filename, path

      if relative_path.include? '..'
        next
      end

      if not path.nil?
        if filename.chomp('/') == path.chomp('/')
          next
        end
      end

      if not all
        if relative_path.include? '/'
          next
        end
      end

      paths << filename
    end

    paths
  end

  alias __add__ add
  private :__add__

  def add src, path
    src = File.normalize src
    path = File.normalize path

    Util::Logger::cmdline '[zip:add] %s -> %s' % [src, path]

    map = {}

    dir, pattern = File.pattern_split src

    if dir
      if File.directory? dir
        list = []

        Dir.chdir dir do
          File.glob(pattern).each do |file|
            list << file

            if File.directory? file
              list += File.glob File.join(file, '**/*')
            end
          end
        end

        list.each do |file|
          src_file = File.join dir, file
          path_file = File.join path, file

          if block_given?
            src_file, path_file = yield src_file, path_file

            if src_file.nil?
              next
            end
          end

          map[path_file] = src_file
        end
      end
    else
      if block_given?
        src, path = yield src, path

        if not src.nil?
          map[path] = src
        end
      else
        map[path] = src
      end

      if not src.nil?
        if File.directory? src
          list = []

          Dir.chdir src do
            list += File.glob '**/*'
          end

          list.each do |file|
            src_file = File.join src, file
            path_file = File.join path, file

            if block_given?
              src_file, path_file = yield src_file, path_file

              if src_file.nil?
                next
              end
            end

            map[path_file] = src_file
          end
        end
      end
    end

    status = true

    map.each do |path_file, src_file|
      case
      when File.directory?(src_file)
        if not mkdir path_file
          status = false

          break
        end
      when File.file?(src_file)
        path_file_dup = path_file.locale.force_encoding 'ASCII-8BIT'

        if find_entry path_file_dup
          if not replace src_file, path_file
            status = false

            break
          end
        else
          begin
            Util::Logger::puts '%s, %s' % [src_file, path_file]

            __add__ path_file_dup, src_file
          rescue
            Util::Logger::exception $!

            status = false

            break
          end
        end
      else
        next
      end
    end

    if status
      if @auto_commit
        save
      else
        true
      end
    else
      false
    end
  end

  def update
    file = File.normalize file

    Util::Logger::cmdline '[zip:update] %s' % file

    status = true

    each_entry do |zip_path|
      filename = zip_path.to_s.utf8
      path = yield filename

      if path.nil?
        next
      end

      if not replace zip_path, path
        status = false

        break
      end
    end

    if status
      if @auto_commit
        save
      else
        true
      end
    else
      false
    end
  end

  def delete path = nil
    if not path.nil?
      path = File.normalize path
    end

    Util::Logger::cmdline '[zip:delete] %s' % path

    deletes = []

    each_entry do |zip_path|
      filename = zip_path.to_s.utf8
      found = false

      if block_given?
        found = yield filename
      else
        if not path.nil?
          found = File.include? path, filename
        end
      end

      if found
        deletes << zip_path
      end
    end

    status = true

    deletes.each do |zip_path|
      begin
        Util::Logger::puts zip_path.to_s.utf8

        remove zip_path
      rescue
        Util::Logger::exception $!

        status = false

        break
      end
    end

    if status and not deletes.empty?
      if @auto_commit
        save
      else
        true
      end
    else
      false
    end
  end

  def rename old_path, new_path
    old_path = File.normalize old_path
    new_path = File.normalize new_path

    Util::Logger::cmdline '[zip:rename] %s -> %s' % [old_path, new_path]

    status = true

    each_entry do |zip_path|
      filename = zip_path.to_s.utf8

      if File.inlcude? old_path, filename
        begin
          Util::Logger::puts filename

          super zip_path, (new_path + filename[old_path.size..-1]).locale
        rescue
          Util::Logger::exception $!

          status = false

          break
        end
      end
    end

    if status
      if @auto_commit
        save
      else
        true
      end
    else
      false
    end
  end

  def unzip dest, paths = nil
    dest = File.normalize dest

    Util::Logger::cmdline '[zip:unzip] %s' % dest

    if not paths.nil?
      paths = paths.map {|x| File.normalize x}
    end

    status = true

    each_entry do |zip_path|
      filename = zip_path.to_s.utf8

      if not paths.nil?
        include = false

        paths.each do |path|
          if File.include? path, filename
            include = true

            break
          end
        end

        if not include
          next
        end
      end

      dest_file = File.join dest, filename

      begin
        if not File.directory? File.dirname(dest_file)
          FileUtils.mkdir_p File.dirname(dest_file)
        end
      rescue
        Util::Logger::exception $!

        status = false

        next
      end

      begin
        Util::Logger::puts '%s, %s' % [filename, dest_file]

        extract zip_path, dest_file do
          true
        end
      rescue
        Util::Logger::exception $!

        status = false

        next
      end
    end

    status
  end

  def save
    Util::Logger::cmdline '[zip:save] %s' % File.normalize(name)

    if not File.mkdir File.dirname(name)
      return false
    end

    begin
      commit

      true
    rescue
      Util::Logger::exception $!

      initialize name

      false
    end
  end

  private

  def mkdir path
    paths = File.normalize(path).split '/'
    dir = nil

    paths.each do |path|
      if dir.nil?
        dir = path
      else
        dir = File.join dir, path
      end

      dir_dup = dir.locale.force_encoding 'ASCII-8BIT'

      if not find_entry dir_dup
        begin
          Util::Logger::puts dir

          super dir_dup
        rescue
          Util::Logger::exception $!

          return false
        end
      end
    end

    true
  end

  def replace file, path
    begin
      Util::Logger::puts '%s, %s' % [file, path]

      check_file file
      __add__ remove(path.locale.force_encoding('ASCII-8BIT')), file

      true
    rescue
      Util::Logger::exception $!

      false
    end
  end

  def get_tempfile
    if OS.windows?
      temp_file = Tempfile.new('%s_%s' % [File.tmpname, File.basename(name)], Dir.tmpdir)
    else
      temp_file = Tempfile.new(File.basename(name), File.dirname(name))
    end

    temp_file.binmode
    temp_file
  end
end