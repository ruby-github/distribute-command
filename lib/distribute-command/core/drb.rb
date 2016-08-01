require 'drb'
require 'timeout'

module DRb
  class Object
    include DRbUndumped

    attr_reader :server

    @@lock = Monitor.new

    def initialize
      if DRb::thread.nil?
        DRb::start_service DRb::druby(System::ip, 0)
      end

      @server = nil
    end

    def connect ip = nil, port = nil
      begin
        @server = DRbObject.new nil, DRb::druby(ip, port)

        if @server.connect?
          @server.clear

          true
        else
          false
        end
      rescue
        Util::Logger::exception $!

        @server = nil

        false
      end
    end

    def close stop_service = false, reboot = false
      if not @server.nil?
        begin
          @server.close reboot
        rescue
        end

        @server = nil
      end

      if stop_service
        DRb::stop_service
      end
    end

    def connect?
      if not @server.nil?
        begin
          @server.connect?
        rescue
          false
        end
      else
        false
      end
    end

    def errors
      if not @server.nil?
        begin
          @server.errors
        rescue
          nil
        end
      else
        nil
      end
    end

    def ip
      ip = nil

      if connect?
        if DRb::uri =~ /^druby:\/\/(.*?):(\d+)(\?(.*))?$/
          ip = $1
        end
      end

      ip
    end

    def uri
      '%s:%s' % [DRb::uri, object_id]
    end
  end

  class Server
    attr_reader :handle, :variables

    @@lock = Monitor.new

    def initialize
      @handle = {}
      @variables = {}
    end

    def close reboot = false
      if reboot
        begin
          DRb::stop_service
        rescue
        end

        if OS::windows?
          OS::kill do |pid, info|
            info[:name] == 'cmd.exe' and info[:command_line].include? '/K drb'
          end

          system 'start drb'
        else
          system 'drb &'
        end
      end
    end

    def connect?
      true
    end

    def errors
      $errors
    end

    def clear
      $errors = nil
    end

    def self.start ip = nil, port = nil, config = nil
      url = DRb::druby ip || '0.0.0.0', port
      DRb::start_service url, Server.new, config

      if block_given?
        yield url
      end

      DRb::thread.join
    end
  end

  def self.druby ip = nil, port = nil
    'druby://%s:%s' % [ip || '127.0.0.1', port || 9000]
  end
end

module DRb
  class Object
    def cmdline cmdline, args = nil
      begin
        @server.cmdline cmdline, args do |line, stdin, wait_thr|
          if block_given?
            yield line, stdin, wait_thr
          end
        end
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def callback callback_name, function = true, args = nil
      begin
        @server.callback callback_name, function, args do |line|
          if block_given?
            yield line
          end
        end
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def function function_name, function = true, args = nil
      begin
        @server.function function_name, function, args do |line|
          if block_given?
            yield line
          end
        end
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def eval string
      begin
        @server.eval string do |line|
          if block_given?
            yield line
          end
        end
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def mkdir path
      begin
        @server.mkdir path do |path|
          if block_given?
            yield path
          end
        end
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def delete path
      begin
        @server.delete path do |file|
          if block_given?
            file = yield file
          end

          file
        end
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def copy_remote home, remote_home, xpath
      @@lock.synchronize do
        begin
          status = true

          home = File.expand_path home

          @server.glob(remote_home, xpath).each do |file, is_file|
            name = file

            if block_given?
              name = yield name
            end

            if name.nil?
              next
            end

            if is_file
              str = @server.file File.join(remote_home, file), true

              begin
                File.open File.join(home, name), 'wb' do |file|
                  file << str
                end
              rescue
                status = false
              end
            else
              if not File.mkdir File.join(home, name)
                status = false
              end
            end
          end

          status
        rescue
          Util::Logger::exception $!

          false
        end
      end
    end

    def file filename, binary = false
      begin
        if block_given?
          @server.file filename, binary do |string|
            str = yield string

            str
          end
        else
          @server.file filename, binary
        end
      rescue
        Util::Logger::exception $!

        nil
      end
    end

    def copy src, dest
      begin
        status = true

        src = File.expand_path src

        File.copy_info(src, dest).each do |dest_file, src_file|
          if block_given?
            src_file, dest_file = yield src_file, dest_file

            if src_file.nil?
              next
            end
          end

          if File.directory? src_file
            if not @server.mkdir dest_file
              status = false
            end
          else
            File.lock src_file, 'rb' do |file|
              loop do
                data = file.read 4096

                if not @server.copy_file dest_file, data do |string|
                    if block_given?
                      yield string
                    end
                  end

                  status = false
                end

                if data.nil?
                  break
                end
              end
            end
          end
        end

        status
      rescue
        Util::Logger::exception $!

        false
      end
    end
  end

  class Server
    def cmdline cmdline, args = nil
      args ||= {}
      home = args['home'] || '.'

      if File.directory? home
        thread = Thread.new do
          string = "Dir.chdir '#{home}' do; system '#{cmdline}'; end"

          CommandLine::function string do |line, stdin, wait_thr|
            if block_given?
              yield line, stdin, wait_thr
            end
          end
        end

        thread.join
        thread.value
      else
        false
      end
    end

    def callback callback_name, function = true, args = nil
      if DistributeCommand::Callback::respond_to? callback_name
        thread = Thread.new do
          if function
            string = "DistributeCommand::Callback::#{callback_name}"

            CommandLine::function string, true, nil, args do |line, stdin, wait_thr|
              if block_given?
                yield line
              end
            end
          else
            DistributeCommand::Callback::__send__ callback_name, args do |line|
              if block_given?
                yield line
              end
            end
          end
        end

        thread.join
        thread.value
      else
        Util::Logger::exception 'No found function @ drb_callback - DistributeCommand::Callback::%s' % callback_name

        false
      end
    end

    def function function_name, function = true, args = nil
      if DistributeCommand::Function::respond_to? function_name
        thread = Thread.new do
          if function
            string = "DistributeCommand::Function::#{function_name}"

            CommandLine::function string, true, nil, args do |line, stdin, wait_thr|
              if block_given?
                yield line
              end
            end
          else
            DistributeCommand::Function::__send__ function_name, args do |line|
              if block_given?
                yield line
              end
            end
          end
        end

        thread.join
        thread.value
      else
        Util::Logger::exception 'No found function @ drb_callback - DistributeCommand::Function::%s' % function_name

        false
      end
    end

    def eval string
      thread = Thread.new do
        begin
          Kernel::eval string
        rescue
          string = Util::Logger::exception $!, false, nil

          if block_given?
            yield string
          end

          nil
        end
      end

      thread.join
      thread.value
    end

    def mkdir path
      File.mkdir path do |path|
        if block_given?
          yield path
        end
      end
    end

    def delete path
      if File.exist? path
        thread = Thread.new do
          File.delete path do |file|
            if block_given?
              file = yield file
            end

            file
          end
        end

        thread.join
        thread.value
      else
        true
      end
    end

    def glob home, xpath
      home = File.expand_path home

      if File.directory? home
        list = []

        if File.directory? File.join(home, xpath)
          xpath = File.join xpath, '**/*'
        end

        File.glob(File.join(home, xpath)).each do |file|
          list << [file[(home.size + 1)..-1], File.file?(file)]
        end

        list
      else
        []
      end
    end

    def file filename, binary = false
      @@lock.synchronize do
        string = nil

        if File.file? filename
          if binary
            string = IO.read filename, mode: 'rb'
          else
            string = IO.read filename
          end
        end

        if block_given?
          str = yield string

          if str != string
            if binary
              File.open filename, 'wb' do |file|
                file << str
              end
            else
              File.open filename, 'w' do |file|
                file << str
              end
            end
          end
        end

        string
      end
    end

    def copy_file filename, data = nil
      @@lock.synchronize do
        filename = File.normalize filename

        begin
          if @handle[filename].nil?
            @handle[filename] = File.open filename, 'wb'
          end

          file = @handle[filename]

          if data.nil?
            file.close

            @handle.delete filename
          else
            file << data
          end

          true
        rescue
          string = Util::Logger::exception $!, false, nil

          if block_given?
            yield string
          end

          false
        end
      end
    end
  end
end

at_exit do
  DRb::stop_service
end