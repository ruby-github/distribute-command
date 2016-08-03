require 'yaml'

module YAML
  module_function

  def dump_tmpfile obj, tmpname = nil
    if tmpname.nil?
      tmpname = "#{File.tmpname}.yaml"
    end

    File.open File.join(Dir.tmpdir, tmpname), 'w:utf-8' do |f|
      f.puts obj.utf8.to_yaml
    end

    tmpname
  end

  def load_tmpfile tmpname
    begin
      YAML::load_file(File.join(Dir.tmpdir, tmpname)).utf8
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