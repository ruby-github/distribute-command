if $0	== __FILE__
	file = '/etc/sysconfig/network-scripts/ifcfg-eth0'

	if File.file?	file
		mac_addr = nil
		str	=	`ifconfig	-a`

		eth0_start = false

		str.lines.each do	|line|
			line.strip!

			if line.empty?
				eth0_start = false

				next
			end

			if line =~ /^eth0\s*:\s*/
				eth0_start = true

				next
			end

			if eth0_start
				if line	=~ /^ether\s+([0-9a-fA-F:]+)/
					mac_addr = $1.upcase
				end
			end
		end

		if not mac_addr.nil?
			update = false

			lines	=	[]

			IO.readlines(file).each	do |line|
				line.strip!

				if line	=~ /HWADDR\s*=\s*["']*([0-9a-fA-F:]+)["']*/
					if $1.upcase !=	mac_addr
						line = 'HWADDR="%s"' % mac_addr
					end
				end

				lines	<< line
			end

			if update
				puts 'update ifcfg-eth0	HWADDR:	%s'	%	mac_addr

				File.open	file,	'w'	do |f|
					f.puts lines
				end

				system '/etc/init.d/network	restart'
			end
		end
	end
end
