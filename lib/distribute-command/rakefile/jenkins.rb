require 'rake'

namespace :jenkins do
  task :autopatch do |t, args|
    status = true

    if not Jenkins::autopatch_monitor
      status = false
    end

    status.exit
  end
end