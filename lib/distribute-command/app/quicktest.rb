require 'json'
require 'time'

autoload :WIN32OLE, 'win32ole'

module Win32
  autoload :Registry, 'win32/registry'
end

QUICKTEST_FILENAME_QX       = 'qxnew.log'
QUICKTEST_FILENAME_MSG      = 'msg.log'

QUICKTEST_FILENAME_CHECK    = 'check.log'
QUICKTEST_FILENAME_LOG      = 'log.log'

QUICKTEST_FILENAME_QTP      = 'qtp.log'
QUICKTEST_FILENAME_QTP_NEW  = 'qtp_new.log'

QUICKTEST_FILENAME_TESTLOG  = 'd:/AutoTest/Reports/log.txt'

QUICKTEST_FILENAME_RESULTS  = 'results.yml'

class QuickTest
  def initialize opt = nil
    opt ||= {}

    @opt = {
      :addins               => ['java'],
      :results_location     => nil,
      :resources_libraries  => [],
      :recovery             => {},
      :run_settings         => {
        :iteration_mode     => 'rngAll',
        :start_iteration    => 1,
        :end_iteration      => 1,
        :on_error           => 'NextStep'
      }
    }.deep_merge(opt)

    @application = nil
    @expired = false
    @last_run_results = nil

    @path = nil
    @status = nil
  end

  def open
    if @application.nil?
      begin
        WIN32OLE.ole_initialize

        @application = WIN32OLE.new 'QuickTest.Application'
        sleep 3

        true
      rescue
        if exec_qtpro
          begin
            @application = WIN32OLE.new 'QuickTest.Application'
            sleep 3

            true
          rescue
            Util::logger::exception $!
	    Util::logger::error 'create WIN32OLE QuickTest.Application fail'

            false
          end
        else
          false
        end
      end
    else
      true
    end
  end

  def exec path, expired = nil
    path = File.expand_path path

    @path = path
    @status = false

    if not File.file? File.join(path, 'Action1/Script.mts')
      Util::logger::error 'not found %s' % File.join(path, 'Action1/Script.mts')

      return false
    end

    if not open
      return false
    end

    expired = (expired || 3600).to_i

    @expired = false
    @last_run_results = nil

    begin
      if @application.Launched
        @application.Quit
      end

      # addins
      if not @opt[:addins].nil?
        @application.SetActiveAddins @opt[:addins].sort.uniq, 'set active addins fail'
      end

      # launch
      @application.Launch
      @application.Visible = true
      @application.Options.Run.RunMode = 'Fast'
      @application.Open File.expand_path(path), false, false

      # test
      sleep 3
      test = @application.Test
      sleep 3

      # resources_libraries
      if not @opt[:resources_libraries].nil?
        libs = []

        @opt[:resources_libraries].each do |library_path|
          File.glob(library_path).each do |lib|
            libs << File.expand_path(lib)
          end
        end

        test.Settings.Resources.Libraries.RemoveAll

        libs.sort.uniq.each do |lib|
          test.Settings.Resources.Libraries.Add lib, -1
        end

        test.Settings.Resources.Libraries.SetAsDefault
      end

      # recovery
      if not @opt[:recovery].nil?
        test.Settings.Recovery.RemoveAll

        @opt[:recovery].each do |scenario_file, scenario_name|
          test.Settings.Recovery.Add File.expand_path(scenario_file), scenario_name, -1
        end

        test.Settings.Recovery.Count.times do |i|
          test.Settings.Recovery.Item(i + 1).Enabled = true
        end

        test.Settings.Recovery.Enabled = true
        test.Settings.Recovery.SetActivationMode 'OnEveryStep'
        test.Settings.Recovery.SetAsDefault
      end

      # run_settings
      if not @opt[:run_settings].nil?
        if not @opt[:run_settings][:iteration_mode].nil?
          test.Settings.Run.IterationMode = @opt[:run_settings][:iteration_mode]
        end

        if not @opt[:run_settings][:start_iteration].nil?
          test.Settings.Run.StartIteration = @opt[:run_settings][:start_iteration]
        end

        if not @opt[:run_settings][:end_iteration].nil?
          test.Settings.Run.EndIteration = @opt[:run_settings][:end_iteration]
        end

        if not @opt[:run_settings][:on_error].nil?
          test.Settings.Run.OnError = @opt[:run_settings][:on_error]
        end
      end

      test.Save
      sleep 3

      # run_results_options
      run_results_options = WIN32OLE.new 'QuickTest.RunResultsOptions'
      if not @opt[:results_location].nil?
        run_results_options.ResultsLocation = File.expand_path @opt[:results_location]
      end

      sleep 3
      test.Run run_results_options, false, nil
      sleep 3

      @last_run_results = {
        :begin    => Time.now,
        :end      => nil,
        :passed   => nil,
        :failed   => nil,
        :warnings => nil
      }

      while test.IsRunning
        duration = Time.now - @last_run_results[:begin]

        if expired > 0 and duration > expired
          test.Stop

          Util::logger::error 'quicktest execution expired - %s:%s' % [expired, path]

          @expired = true
        end

        sleep 1
      end

      if block_given?
        yield test
      end

      results_path = test.LastRunResults.Path
      status = test.LastRunResults.Status

      test.Close
      @application.Quit

      @last_run_results[:end] = Time.now

      begin
        doc = REXML::Document.file File.join(results_path, 'Report/Results.xml')

        REXML::XPath.each(doc, '/Report/Doc/Summary') do |e|
          @last_run_results[:passed] = e.attributes['passed'].to_i
          @last_run_results[:failed] = e.attributes['failed'].to_i
          @last_run_results[:warnings] = e.attributes['warnings'].to_i

          break
        end
      rescue
      end

      info = {
        'index'   => nil,
        'begin'   => @last_run_results[:begin],
        'end'     => @last_run_results[:end],
        'passed'  => @last_run_results[:passed],
        'failed'  => @last_run_results[:failed],
        'warnings'=> @last_run_results[:warnings],
        'location'=> File.basename(results_path),
        'execute' => true,
        'compare' => nil
      }

      if status != 'Passed'
        if @expired
          info['execute'] = nil
        else
          info['execute'] = false
        end
      end

      File.open File.join(results_path, '..', QUICKTEST_FILENAME_RESULTS), 'w:utf-8' do |f|
        f.puts info.to_yaml
      end

      if status == 'Passed'
        @status = true

        true
      else
        false
      end
    rescue
      close

      false
    end
  end

  def close
    if not @application.nil?
      begin
        if @application.Launched
          @application.Test.Stop
          @application.Test.Close
          @application.Quit
        end
      rescue
        OS::kill do |pid, info|
          ['QTAutomationAgent.exe', 'QtpAutomationAgent.exe', 'QTPro.exe', 'UFT.exe'].include? info[:name]
        end
      ensure
        begin
          @application.ole_free
        rescue
        end

        @application = nil
        GC.start
        sleep 3
      end
    end

    @path = nil
    @status = nil

    true
  end

  def table_external_editors list
    if not open
      return false
    end

    begin
      @application.Launch
      @application.Options.Java.TableExternalEditors = list.join ' '
      @application.Quit

      true
    rescue
      Util::logger::exception $!
      Util::logger::error 'set quicktest java tableexternaleditors fail'

      close

      false
    end
  end

  def create path, src = nil, expand = false
    path = File.expand_path path

    if not open
      return false
    end

    status = true

    begin
      if @application.Launched
        @application.Quit
      end

      @application.Launch
      @application.New false

      if File.mkdir path
        @application.Test.SaveAs File.expand_path(path).gsub(File::SEPARATOR, '\\')
        @application.Quit
      end
    rescue
      close

      File.delete path
      status = false
    end

    if status
      if not src.nil?
        src = File.expand_path src

        if File.same_path? path, src, true
          return true
        end

        if File.directory? src
          if not File.copy File.join(src, '*'), path
            status = false
          end

          if expand
            if not File.copy File.join(src, '../*.{xls,xlsx}'), File.dirname(path)
              status = false
            end
          end
        end
      end
    end

    if status
      true
    else
      File.delete path

      Util::logger::error 'create quicktest testcase fail - %s' % path

      false
    end
  end

  def last_run_results
    if @status
      str = 'SUCCESS'
    else
      if @expired
        str = 'FAIL(EXPIRED)'
      else
        str = 'FAIL'
      end
    end

    lines = []

    Util::Logger::head('QuickTest Execute %s - %s' % [str, @path], nil).strip.lines.each do |line|
      lines << line.rstrip
    end

    (@last_run_results || {}).each do |k, v|
      lines << Util::Logger::info('%s%s%s:%s' % [INDENT, k, ' ' * (18 - k.to_s.bytesize), v], nil)
    end

    lines << Util::Logger::headline

    lines
  end

  private

  def exec_qtpro
    qtpro = nil

    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open 'SOFTWARE\Mercury Interactive\QuickTest Professional\CurrentVersion' do |reg|
        qtpro = File.join reg['QuickTest Professional'], 'bin', 'QTPro.exe'
      end
    rescue
    end

    if qtpro.nil?
      begin
        Win32::Registry::HKEY_LOCAL_MACHINE.open 'SOFTWARE\Wow6432Node\Mercury Interactive\QuickTest Professional\CurrentVersion' do |reg|
          qtpro = File.join reg['QuickTest Professional'], 'bin', 'UFT.exe'
        end
      rescue
      end
    end

    if not qtpro.nil? and File.file? qtpro
      begin
        system File.cmdline(qtpro)

        OS::kill do |pid, info|
          ['QTAutomationAgent.exe', 'QtpAutomationAgent.exe', 'QTPro.exe', 'UFT.exe'].include? info[:name]
        end

        true
      rescue
        false
      end
    else
      Util::logger::error 'not found %s' % (qtpro || 'qtpro.exe')

      false
    end
  end
end

module DRb
  class Object
    def netnumen_quicktest home
      begin
        @server.netnumen_quicktest home
      rescue
        Util::Logger::exception $!

        nil
      end
    end

    def netnumen_quicktest_finish home, info
      begin
        @server.netnumen_quicktest_finish home, info
      rescue
        Util::Logger::exception $!

        nil
      end
    end
  end

  class Server
    def netnumen_quicktest home
      home = File.expand_path home

      if File.directory? home
        info = {}

        File.glob(File.join(home, 'ums-server/works/*/*/log/{qxmsg,climsg}')).each do |path|
          File.glob(File.join(path, '{qxmock-*.log,climock-*.log,server*.hex}')).each do |file|
            info[File.expand_path(file)] = IO.readlines(file).size
          end
        end

        File.glob(File.join(home, 'ums-server/works/*/*/log/bn-{qxmsg,climsg}')).each do |path|
          File.glob(File.join(path, 'bn-{qxmock-*.log,climock-*.log}')).each do |file|
            info[File.expand_path(file)] = IO.readlines(file).size
          end
        end

        info
      else
        nil
      end
    end

    def netnumen_quicktest_finish home, info
      home = File.expand_path home

      if File.directory? home
        map = {}

        File.glob(File.join(home, 'ums-server/works/*/*/log/{qxmsg,climsg}')).each do |path|
          File.glob(File.join(path, '{qxmock-*.log,climock-*.log,server*.hex}')).each do |file|
            file = File.expand_path file
            lines = IO.readlines file

            if lines.size > info[file].to_i
              map[file] = [info[file].to_i, lines.size, lines[info[file].to_i..-1]]
            end
          end
        end

        File.glob(File.join(home, 'ums-server/works/*/*/log/bn-{qxmsg,climsg,netconfmsg}')).each do |path|
          File.glob(File.join(path, 'bn-{qxmock-*.log,climock-*.log,netconfmock-*.log}')).each do |file|
            file = File.expand_path file
              lines = IO.readlines file

              if lines.size > info[file].to_i
                map[file] = [info[file].to_i, lines.size, lines[info[file].to_i..-1]]
              end
          end
        end

        map
      else
        nil
      end
    end
  end
end