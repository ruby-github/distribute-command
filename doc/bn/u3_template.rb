require 'fileutils'
require 'net/ftp'

if $0 == __FILE__
  Dir.chdir 'c:/temp/u3_patch' do
    if File.size('log.log') > 102400
      FileUtils.rm_rf 'log.log'
    end

    File.open 'log.log', 'a' do |f|
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

            line = '%s ftp put file: %s -> %s' % [Time.now, file, dest_file]

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
              ftp.putbinaryfile file , dest_file

              FileUtils.rm_rf file

              f.puts '%s success' % line
            rescue
              f.puts '%s fail' % line
            end
          end
        end
      rescue
        f.puts $!.to_s
      end

      f.puts
    end
  end
end