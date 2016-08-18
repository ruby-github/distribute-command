require 'fileutils'

LOG_FILE = 'log.log'
PATCH_HOME = 'c:/temp/u3_patch'
SOURCE_HOME = '//10.8.9.80/source'

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

          file_locale = file.dup.encode 'locale', invalid: :replace, undef: :replace, replace: ''
          dest_file_locale = dest_file.dup.encode 'locale', invalid: :replace, undef: :replace, replace: ''

          begin
            FileUtils.mkdir_p File.dirname(dest_file_locale)

            FileUtils.copy_file file_locale, dest_file_locale, false

            f.puts '[SUCCESS] %s copy file: %s ->' % [Time.now, file_locale]
            f.puts ' ' * 10 + dest_file_locale
          rescue
            f.puts '[FAILED ] %s copy file: %s ->' % [Time.now, file_locale]
            f.puts ' ' * 10 + dest_file_locale

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
