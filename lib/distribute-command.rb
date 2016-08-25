# ----------------------------------------------------------
#
#                        全局变量
#
# ----------------------------------------------------------
#
# String
#
# $klocwork_http
# $username, $password
# $smtp_username, $smtp_password
# $branch, $home
#
# Filename
#
# $asn1_ignore_file, $asn1_sort_file
#
# Boolean
#
# $klocwork_build
# $logging
# $sendmail
# $xml_comment_indent, $xml_text_indent
# $x64
#
# Array
#
# $mail_admin, $mail_cc
#
# Hash
#
# $asn1_cmdcode
#
# Object
#
# $drb
#
# ---------------------------------------------------------

Dir.chdir __dir__ do
  Dir.glob('distribute-command/**/*.rb').each do |file|
    if File.basename(file) == 'java.rb'
      autoload :Java, file

      next
    end

    require file
  end
end

module Net
  ssh = Dir.glob(File.join(Gem.dir, 'gems/*/lib/net/ssh.rb')).sort.last

  if not ssh.nil?
    autoload :SSH, ssh
  end
end

def distributecommand file, tmpdir = nil, args = nil
  command = DistributeCommand::Command.new file, args

  exec = true

  if block_given?
    exec = yield command
  end

  if exec
    status = true

    if not command.exec
      status = false
    end

    if not tmpdir.nil?
      info = {
        'distributecommand'         => $distributecommand,
        'distributecommand_errors'  => $distributecommand_errors
      }

      YAML::dump_tmpfile info, 'distributecommand', tmpdir
    end

    status
  else
    true
  end
end