class Object
  alias __clone__ clone
  alias __dup__ dup

  def clone
    begin
      __clone__
    rescue
      self
    end
  end

  def dup
    begin
      __dup__
    rescue
      self
    end
  end

  def dclone
    clone
  end
end

class Object
  def to_array
    [self]
  end
end

class Object
  def locale
    dclone.locale!
  end

  def locale!
    instance_variables.each do |x|
      instance_variable_set x, instance_variable_get(x).locale
    end

    self
  end

  def utf8
    dclone.utf8!
  end

  def utf8!
    instance_variables.each do |x|
      instance_variable_set x, instance_variable_get(x).utf8
    end

    self
  end

  def to_string
    to_s
  end

  def to_json_string
    '"%s"' % to_s
  end
end

class Object
  def gem_dir name = nil, version = nil
    if name.nil?
      File.join Gem.dir, 'gems'
    else
      dirs = []

      Dir.glob(File.join(Gem.dir, 'gems', '%s*' % name)).each do |x|
        if not version.nil?
          if File.basename(x) !~ /^#{name}-[0-9.]+$/
            next
          end
        end

        dirs << x
      end

      dirs.last
    end
  end
end