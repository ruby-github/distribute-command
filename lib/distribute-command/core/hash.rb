class Hash
  def dclone
    dup = self.dup

    dup.keys.each do |k|
      v = dup[k].dclone

      dup.delete k
      dup[k.dclone] = v
    end

    dup
  end
end

class Hash
  def locale!
    keys.each do |k|
      v = self[k].locale

      self.delete k
      self[k.locale] = v
    end

    self
  end

  def utf8!
    keys.each do |k|
      v = self[k].utf8

      self.delete k
      self[k.utf8] = v
    end

    self
  end

  def to_string
    if empty?
      '{}'
    else
      "{\n%s\n}" % map { |k, v| INDENT + ("%s => %s" % [k.to_string, v.to_string].utf8).lines.join(INDENT) }.join(",\n")
    end
  end

  def to_json_string
    if empty?
      '{}'
    else
      "{\n%s\n}" % map { |k, v| INDENT + ("%s: %s" % [k.to_json_string, v.to_json_string].utf8).lines.join(INDENT) }.join(",\n")
    end
  end
end

class Hash
  def deep_merge hash, &block
    dclone.deep_merge! hash, &block
  end

  def deep_merge! hash, &block
    hash.each do |k, v|
      val = self[k]

      if val.is_a? Hash and v.is_a? Hash
        self[k] = val.deep_merge! v, &block
      else
        if block
          self[k] = block.call k, val, v
        else
          self[k] = v
        end
      end
    end

    self
  end
end