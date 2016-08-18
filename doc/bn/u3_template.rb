require 'fileutils'

LOG_FILE = 'log.log'
PATCH_HOME = 'c:/temp/u3_patch'
SOURCE_HOME = '//10.8.9.80/source'

def locale str
  begin
    str.dup.encode 'locale', invalid: :replace, undef: :replace, replace: ''
  rescue
    str
  end
end

if $0 == __FILE__
  if File.directory? PATCH_HOME
    Dir.chdir PATCH_HOME do
      if File.file? LOG_FILE
        if File.size(LOG_FILE) > 102400
          FileUtils.rm_rf LOG_FILE
        end
      end

      system "net use \\\\10.8.9.80\\source share /user:user"

      status = true

      File.open LOG_FILE, 'a' do |f|
        f.puts '%s %s %s' % ['=' * 30, Time.now, '=' * 30]

        f.puts '%s %s %s' % ['=' * 30, Time.now, '=' * 30]

        Dir.glob('**/*.{xml,zip}').each do |file|
          if not File.file? file
            next
          end

          paths = file.split '/'
          paths.shift

          dest_file = File.join SOURCE_HOME, paths.join('/')

          begin
            FileUtils.mkdir_p File.dirname(dest_file)
            FileUtils.copy_file file, dest_file, false
            FileUtils.rm_rf file

            f.puts '[SUCCESS] %s copy file: %s' % [Time.now, locale(file)]
            f.puts '%s -> %s' % [' ' * 9, locale(dest_file)]
          rescue
            f.puts '[ERROR  ] %s' % locale($!.to_s)
            f.puts '[FAILED ] %s copy file: %s' % [Time.now, locale(file)]
            f.puts '%s -> %s' % [' ' * 9, locale(dest_file)]

            status = false
          end
        end

        f.puts
      end

      if status
        Dir.glob('*').each do |file|
          if File.directory? file
            FileUtils.rm_rf file
          end
        end
      end
    end
  end
end
