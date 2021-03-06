# ----------------------------------------------------------
#
#                        全局变量
#
# ----------------------------------------------------------
#
# String
#
#   $klocwork_http
#
#   $username, $password
#   $smtp_username, $smtp_password
#
#   $version, $display_version, $nfm_version
#   $branch, $home, $code_home, $build_home, $devtools_home
#   $installation_home, $installation_uep, $fi2cpp_home, $license_home
#
#   $bn_metric_id_e2e, $bn_metric_id_iptn, $bn_metric_id_iptn_nj, $bn_metric_id_naf, $bn_metric_id_wdm, $stn_metric_id
#
# Filename
#
#   $asn1_ignore_file, $asn1_sort_file
#
# Boolean
#
#   $exception_backtrace
#   $klocwork_build
#
#   $logging
#   $sendmail
#   $xml_comment_indent, $xml_text_indent
#   $x64
#
#   $metric
#
# Array
#
#   $mail_admin, $mail_cc
#
# Hash
#
#   $asn1_cmdcode
#
# Time
#
#   $start_date, $finish_date
#
# Object
#
#   $drb
#
# ---------------------------------------------------------

$exception_backtrace = true

Dir.chdir __dir__ do
  Dir.glob('distribute-command/**/*.rb').each do |file|
    if file == 'distribute-command/util/java.rb'
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
  if file.nil?
    if tmpdir.nil?
      file = 'command.xml'
    else
      file = File.join tmpdir, 'command.xml'
    end
  end

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
        'status'                    => status,
        'distributecommand'         => $distributecommand,
        'distributecommand_errors'  => $distributecommand_errors
      }

      YAML::dump_tmpfile info, 'command', tmpdir
    end

    status
  else
    true
  end
end