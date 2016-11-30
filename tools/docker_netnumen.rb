require 'distribute-command'

class Installation
  def initialize
  end

  def install installation = nil, home = nil
    installation ||= '/tmp/installation'
    home ||= '/netnumen/ems'

    File.delete home

    Dir.chdir installation do
      file = 'conf/silenceinstall-for-localhost.xml'

      if File.file? file
        update_silenceinstall file

        if CommandLine::cmdline 'sh setup.sh /tmp silenceinstall-for-localhost.xml false' do |line, stdin, wait_thr|
            Util::Logger::puts line
          end

          settings home
        end
      else
        false
      end
    end
  end

  private

  def docker_ip
    ip = '127.0.0.1'

    begin
      hostname = IO.read('/etc/hostname').strip

      IO.readlines('/etc/hosts').each do |line|
        line.strip!

        if line.include? hostname
          ip = line.split(/\s+/).first
        end
      end
    rescue
    end

    ip
  end

  # ENV
  #   netnumen_ems_locale
  #   netnumen_db
  def update_silenceinstall file
    args = {
      'to_path'     => file,
      'install_home'=> '/netnumen/ems',
      'ems_locale'  => (ENV['netnumen_ems_locale'] || 'zh_CN'),
      'server'      => true,
      'db'          => (ENV['netnumen_db'] || 'mysql:%s:3306::root:mysql' % docker_ip),
      'ip'          => docker_ip
    }

    DistributeCommand::Callback::netnumen_update_silenceinstall args
  end

  # ENV
  #   netnumen_main_ip
  #   netnumen_anodes
  #   netnumen_cnodes
  def settings home = nil
    home ||= '/netnumen/ems'

    main_ip = ENV['netnumen_main_ip'].to_s.nil

    if not main_ip.nil?
      args = {
        'home'    => home,
        'main_ip' => main_ip
      }

      DistributeCommand::Function::netnumen_sptn_settings args
    end

    anodes = ENV['netnumen_anodes'].to_s.nil
    cnodes = ENV['netnumen_cnodes'].to_s.nil

    if not anodes.nil? or not cnodes.nil?
      args = {
        'home'    => home,
        'ip'      => docker_ip,
        'anodes'  => anodes,
        'cnodes'  => cnodes
      }

      DistributeCommand::Function::netnumen_sptn_cluster_settings args
    end
  end
end

if $0 == __FILE__
  install = Installation.new
  install.install
end