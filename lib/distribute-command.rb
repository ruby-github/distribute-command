# ----------------------------------------------------------
#
#                        全局变量
#
# ----------------------------------------------------------
#
# String
#
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