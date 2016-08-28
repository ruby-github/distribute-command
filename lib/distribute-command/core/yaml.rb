require 'yaml'

module YAML
  module_function

  class << self
    alias __load__ load
    alias __load_file__ load_file
  end

  def load yaml, filename = nil
    __load__(yaml, filename).utf8
  end

  def load_file filename
    __load_file__(filename).utf8
  end

  def dump_tmpfile obj, name = nil, tmpdir = nil
    if name.nil?
      name = File.tmpname
    end

    if tmpdir.nil?
      tmpdir = Dir.tmpdir
    end

    if File.extname(name).empty?
      name += '.yml'
    end

    File.open File.join(tmpdir, name), 'w:utf-8' do |f|
      f.puts obj.utf8.to_yaml
    end

    name
  end

  def load_tmpfile name, tmpdir = nil
    if tmpdir.nil?
      tmpdir = Dir.tmpdir
    end

    if File.extname(name).empty?
      name += '.yml'
    end

    begin
      YAML::load_file File.join(tmpdir, name)
    rescue
      nil
    end
  end
end

module YAML
  module Output
    module_function

    def puts object, io = STDOUT
      info = {
        :object => object,
        :errors  => $errors
      }

      lines = []

      lines << '*' * 30 + ' YAML OUTPUT STRING ' + '*' * 29

      info.to_yaml.lines.each do |line|
        lines << '* ' + line.rstrip
      end

      lines << '*' * 30 + ' YAML OUTPUT FINISH ' + '*' * 29

      if not io.nil?
        lines.each do |line|
          io.puts line
        end
      else
        lines.join "\n"
      end
    end

    def load lines
      tmp = []

      start = false

      lines.each do |line|
        if line =~ /\*+\s+YAML\s+OUTPUT\s+STRING\s+\*+/
          start = true

          next
        end

        if line =~ /\*+\s+YAML\s+OUTPUT\s+FINISH\s+\*+/
          start = false

          next
        end

        if start
          if line =~ /\*\s/
            tmp << $'
          end
        end
      end

      begin
        info = YAML::load tmp.join("\n")

        if not info[:errors].nil?
          $errors ||= []
          $errors += info[:errors]
        end

        info[:object]
      rescue
        nil
      end
    end
  end
end