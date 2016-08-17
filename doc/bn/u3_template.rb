require 'fileutils'
require 'net/ftp'

LOG_FILE = 'log.log'
PATCH_HOME = 'c:/temp/u3_patch'

if $0 == __FILE__
  if File.directory? PATCH_HOME
    Dir.chdir PATCH_HOME do
      if File.file? LOG_FILE
        if File.size(LOG_FILE) > 102400
          FileUtils.rm_rf LOG_FILE
        end
      end

      status = true

      File.open LOG_FILE, 'a' do |f|
        f.puts '%s %s %s' % ['=' * 30, Time.now, '=' * 30]

        begin
          Net::FTP.open '10.8.9.80', 'user', 'user' do |ftp|
            Dir.glob('**/*.{xml,zip}').each do |file|
              if not File.file? file
                next
              end

              paths = file.split '/'
              paths.shift

              dest_file = File.join 'source', paths.join('/')
              dir = nil

              paths = dest_file.split '/'
              paths.pop

              paths.each do |path|
                if dir.nil?
                  dir = path
                else
                  dir = File.join dir, path
                end

                begin
                  ftp.mkdir dir
                rescue
                end
              end

              begin
                ftp.delete dest_file
              rescue
              end

              begin
                ftp.putbinaryfile file , dest_file
                FileUtils.rm_rf file

                f.puts '[SUCCESS] %s ftp put file: %s -> %s' % [Time.now, file, dest_file]
              rescue
                f.puts '[FAILED ] %s ftp put file: %s -> %s' % [Time.now, file, dest_file]

                status = false
              end
            end
          end
        rescue
          f.puts $!.to_s

          status = false
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

      status
    end
  end
end