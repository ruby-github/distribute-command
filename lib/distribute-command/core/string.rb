Encoding.default_internal ||= Encoding.default_external

class String
  def locale
    dup.locale!
  end

  def locale!
    begin
      encoding = encoding?

      if encoding.nil?
        force_encoding 'UTF-8'
      else
        force_encoding encoding
      end

      if self.encoding != Encoding.default_external
        encode! 'locale', invalid: :replace, undef: :replace, replace: ''
      end
    rescue
      self.clear
    end

    self
  end

  def utf8
    dup.utf8!
  end

  def utf8!
    begin
      encoding = encoding?

      if encoding.nil?
        force_encoding 'UTF-8'
      else
        force_encoding encoding
      end

      if self.encoding != Encoding::UTF_8
        encode! 'UTF-8', invalid: :replace, undef: :replace, replace: ''
      end
    rescue
      self.clear
    end

    self
  end

  def encoding?
    if encoding != Encoding::ASCII_8BIT and valid_encoding?
      encoding.to_s
    else
      dup = self.dup

      (['utf-8', 'locale', 'external', 'filesystem'] + Encoding.name_list).uniq.each do |name|
        if name == 'ASCII-8BIT'
          next
        end

        if dup.force_encoding(name).valid_encoding?
          return name
        end
      end

      nil
    end
  end
end

class String
  def vars opt = {}
    if self =~ /\$(\(([\w.:-]+)\)|{([\w.:-]+)})/
      val = $1[1..-2]

      if opt.has_key? val or opt.has_key? val.to_sym
        if opt.has_key? val
          str = opt[val]
        else
          str = opt[val.to_sym]
        end
      else
        str = $&
      end

      '%s%s%s' % [$`, str, $'.vars(opt)]
    else
      self
    end
  end
end

class String
  def boolean default = nil
    case downcase.strip
    when 'true'
      true
    when 'false'
      false
    when 'nil', 'null'
      nil
    else
      if default.nil?
        self
      else
        default
      end
    end
  end

  def nil
    str = strip

    if str.empty? or str.downcase == 'nil' or str.downcase == 'null'
      nil
    else
      str
    end
  end
end

class String
  def escapes all = true
    if all
      gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("'", '&apos;')
    else
      gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    end
  end

  def wrap size = 79
    lines = []

    line = ''

    each_char do |c|
      if line.bytesize + c.bytesize > size
        lines << line
        line = nil
      end

      if line.nil?
        line = c
      else
        line << c
      end
    end

    if not line.nil?
      lines << line
    end

    lines
  end
end