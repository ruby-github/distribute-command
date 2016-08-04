require 'net/smtp'

module Net
  module_function

  # opt
  #   admin
  #   authtype
  #   bcc
  #   cc
  #   file
  #   html
  #   port
  #   password
  #   subject
  #   text
  #   username
  def send_smtp address, from_addr, to_addrs, opt = {}
    address ||= '10.30.18.230'
    from_addr ||= 'admin@zte.com.cn'

    opt = {
      username: $smtp_username || 'ZhouYanQing181524',
      password: $smtp_password || 'smtp@2013',
      cc: $mail_cc,
      admin: $mail_admin
    }.merge (opt || {})

    if not $sendmail
      send_smtp_puts address, from_addr, to_addrs, opt

      return true
    end

    begin
      SMTP.start address, opt[:port] || 25, '127.0.0.1', opt[:username], opt[:password], opt[:authtype] || :login do |smtp|
        mail = MailFactory.new
        mail.from = from_addr.to_s
        mail.subject = opt[:subject].to_s

        if not opt[:text].nil?
          mail.text = opt[:text].to_s
        end

        if not opt[:html].nil?
          mail.html = opt[:html].to_s
        end

        addrs = []

        if not to_addrs.nil?
          addrs += to_addrs.to_array
          mail.to = to_addrs.to_array.join ', '
        end

        if not opt[:cc].nil?
          addrs += opt[:cc].to_array
          mail.cc = opt[:cc].to_array.join ', '
        end

        if not opt[:bcc].nil?
          addrs += opt[:bcc].to_array
          mail.bcc = opt[:bcc].to_array.join ', '
        end

        addrs.uniq!

        if addrs.empty?
          if not opt[:admin].nil?
            addrs = opt[:admin].to_array
          end

          if addrs.empty?
            return true
          end
        end

        if not opt[:file].nil?
          opt[:file].to_array.each do |file|
            mail.attach file.locale
          end
        end

        if block_given?
          yield mail
        end

        begin
          smtp.open_message_stream from_addr, addrs do |file|
            file.puts mail.to_s
          end

          Util::Logger::puts 'send mail to %s' % addrs.join(', ')

          true
        rescue
          Util::Logger::exception $!

          if not opt[:admin].nil?
            smtp.open_message_stream from_addr, opt[:admin].to_array do |file|
              file.puts mail.to_s
            end
          end

          false
        end
      end
    rescue
      Util::Logger::exception $!

      false
    end
  end

  def send_smtp_puts address, from_addr, to_addrs, opt = {}
    Util::Logger::puts ''
    Util::Logger::puts '=' * 60
    Util::Logger::puts ''

    if not to_addrs.nil?
      Util::Logger::puts "收件人: #{to_addrs.to_array.join(', ')}"
    end

    if not opt[:cc].nil?
      Util::Logger::puts "抄送: #{opt[:cc].to_array.join(', ')}"
    end

    if not opt[:bcc].nil?
      Util::Logger::puts "密送: #{opt[:bcc].to_array.join(', ')}"
    end

    if not opt[:file].nil?
      Util::Logger::puts "附件: #{opt[:file].to_array.join(', ')}"
    end

    Util::Logger::puts "主 题: #{opt[:subject].to_s}"

    if not opt[:text].nil?
      Util::Logger::puts ''
      Util::Logger::puts opt[:text].to_s
    end

    if not opt[:html].nil?
      Util::Logger::puts ''
      Util::Logger::puts opt[:html].to_s
    end

    Util::Logger::puts '=' * 60
  end

  class << self
    private :send_smtp_puts
  end
end