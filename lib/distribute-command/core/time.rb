class Time
  def to_s_with_usec
    '%s %s' % [strftime('%Y-%m-%d %H:%M:%S'), usec]
  end

  def timestamp sep = ''
    strftime "%Y#{sep}%m#{sep}%d#{sep}%H#{sep}%M#{sep}%S"
  end

  def timestamp_day sep = ''
    strftime "%Y#{sep}%m#{sep}%d"
  end
end