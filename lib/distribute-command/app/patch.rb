module Patch
  class Bn
    def initialize build_home, code_home
      @build_home = File.expand_path build_home
      @code_home = File.expand_path code_home
    end

    def patch home
      if not File.directory? home
        Util::Logger::error 'no such directory - %s' % home

        return false
      end

      $logging = true

      Dir.chdir home do
        File.lock 'create.id' do
          File.tmpdir do |tmpdir|
            $errors = nil
            $loggers = nil

            if not File.move '*.{xml,zip}', tmpdir, true do |file|
                Util::Logger::puts file

                file
              end

              send_smtp nil, nil, subject: '<PATCH 通知>移动XML文件到临时文件夹失败'

              return false
            end

            status = true

            command_list = []

            time = Time.now

            File.glob(File.join(tmpdir, '*.xml')).sort {|x, y| File.mtime(x) <=> File.mtime(y)}.each_with_index do |file, index|
              $errors = nil
              $loggers = nil

              filename = File.basename(file).utf8

              Util::Logger::cmdline '[patch:exec] %s' % filename

              list = load file

              if list.nil?
                account, cc_account = account_info nil, file
                send_smtp account, cc_account, file: file, subject: '<PATCH 通知>解析XML文件失败, 请尽快处理'

                command_list << ['%s:%s' % [filename, '解析XML文件失败'], false]

                status = false

                next
              end

              if list.empty?
                command_list << ['%s:%s' % [filename, '空补丁'], true]

                next
              end

              map = {}

              list.each_with_index do |info, i|
                if not info[:attr][:os].nil?
                  if not info[:attr][:os].include? OS::name.to_s
                    next
                  end
                end

                if build info, File.join(tmpdir, index.to_s, i.to_s)
                  map[i] = true

                  if File.directory? File.join(tmpdir, index.to_s, i.to_s)
                    Dir.chdir File.join(tmpdir, index.to_s, i.to_s) do
                      File.glob('patch/**/*.xml').each do |xml_file|
                        Util::Logger::puts '[CHECK] %s' % xml_file

                        begin
                          REXML::Document.file xml_file
                        rescue
                          Util::Logger::exception $!

                          map[i] = false

                          status = false
                        end
                      end
                    end
                  end
                else
                  map[i] = false

                  status = false
                end
              end

              if not map.values.include? false
                File.lock File.join(@build_home, 'patch/patch', 'create.id') do
                  list.each_index do |i|
                    if not map.has_key? i
                      next
                    end

                    id = get_id

                    if File.move File.join(tmpdir, index.to_s, i.to_s), File.join(@build_home, 'patch/patch', id), true
                      map[i] = id
                    else
                      map[i] = false

                      status = false
                    end
                  end
                end
              end

              account, cc_account = account_info list.first[:info]

              map.each do |index, value|
                case value
                when true
                  send_smtp account, cc_account, info: list[index], subject: '<PATCH 通知>补丁制作成功, 但关联补丁制作失败, 请尽快处理'

                  command_list << ['%s(%s):%s' % [filename, index, '补丁制作成功, 但关联补丁制作失败'], nil]
                when false
                  send_smtp account, cc_account, info: list[index], subject: '<PATCH 通知>补丁制作失败, 请尽快处理'

                  command_list << ['%s(%s):%s' % [filename, index, '补丁制作失败'], false]
                else
                  if File.glob(File.join(@build_home, 'patch/patch', value, 'patch/*/*/*')).empty?
                    send_smtp account, cc_account, info: list[index], subject: '<PATCH 通知>补丁制作成功, 但没有输出文件(补丁号: %s)' % value, id: value

                    command_list << ['%s(%s):%s' % [filename, index, '补丁制作成功, 但没有输出文件(补丁号: %s)' % value], true]
                  else
                    send_smtp account, cc_account, info: list[index], subject: '<PATCH 通知>补丁制作成功, 请验证(补丁号: %s)' % value, id: value

                    command_list << ['%s(%s):%s' % [filename, index, '补丁制作成功(补丁号: %s)' % value], true]
                  end
                end
              end
            end

            Util::Logger::summary command_list, ((Time.now - time) * 1000).to_i / 1000.0

            status
          end
        end
      end
    end

    private

    # [
    #   {
    #     attr:
    #       home: home
    #       os:
    #         - os
    #       script:
    #         - type
    #       zip: name
    #     delete:
    #       - name
    #     source:
    #       - name
    #     compile:
    #       name: clean
    #     deploy:
    #       deploy:
    #         name:
    #           - type
    #       delete:
    #         name:
    #           - type
    #     info:
    #       name: value
    #   }
    # ]
    def load file
      file = File.normalize file

      begin
        doc = REXML::Document.file file

        if doc.root.attributes['version'].to_s.strip != '2.0'
          Util::Logger::error '补丁申请单格式错误, 请使用新补丁申请单(版本号2.0)'

          return nil
        end

        list = []
        status = true

        REXML::XPath.each(doc, '/patches/patch') do |e|
          map = {
            :attr => {
              :home   => File.normalize(e.attributes['name'].to_s.strip).nil,
              :os     => nil,
              :script => nil,
              :zip    => File.join(File.dirname(file), '%s.zip' % File.basename(file, '.*'))
            },
            :delete   => [],
            :source   => [],
            :compile  => {},
            :deploy   => {
              :deploy => {},
              :delete => {}
            },
            :info     => {
              '提交人员'  => nil,
              '变更版本'  => nil,
              '变更类型'  => nil,
              '变更描述'  => nil,
              '关联故障'  => nil,
              '影响分析'  => nil,
              '依赖变更'  => nil,
              '走查人员'  => nil,
              '走查结果'  => nil,
              '自测结果'  => nil,
              '变更来源'  => nil,
              '开发经理'  => nil,
              '抄送人员'  => nil
            }
          }

          script = e.attributes['script'].to_s.nil

          if not script.nil?
            map[:attr][:script] = script.split(',').map { |x| x.strip }
          end

          os = e.attributes['os'].to_s.nil

          if not os.nil?
            map[:attr][:os] = os.split(',').map { |x| x.strip }
          end

          if map[:attr][:home].nil?
            Util::Logger::error '%s: patch节点的name属性不能为空' % e.xpath

            status = false
          else
            if not modules.keys.include?(File.dirname(map[:attr][:home]))
              Util::Logger::error '%s: patch节点的name属性不是合法的模块名称 - %s' % [e.xpath, map[:attr][:home]]

              status = false
            end
          end

          if not map[:attr][:os].nil?
            if not (map[:attr][:os] - ['windows', 'linux', 'solaris']).empty?
              Util::Logger::error '%s: patch节点的os属性值错误, 只能包含windows, linux, solaris' % e.xpath

              status = false
            end
          end

          if not map[:attr][:script].nil?
            if not File.file? map[:attr][:zip]
              Util::Logger::error '%s: 找不到增量脚本对应的zip文件 - %s' % [e.xpath, map[:attr][:zip]]

              status = false
            end
          end

          REXML::XPath.each(e, 'delete/attr') do |element|
            name = element.attributes['name'].to_s.nil

            if not name.nil?
              map[:delete] << File.normalize(name)
            else
              Util::Logger::error '%s: delete下attr节点的name属性不能为空' % element.xpath

              status = false
            end
          end

          map[:delete].uniq!

          REXML::XPath.each(e, 'source/attr') do |element|
            name = element.attributes['name'].to_s.nil

            if not name.nil?
              map[:source] << File.normalize(name)
            else
              Util::Logger::error '%s: source下attr节点的name属性不能为空' % element.xpath

              status = false
            end
          end

          map[:source].uniq!

          REXML::XPath.each(e, 'compile/attr') do |element|
            name = element.attributes['name'].to_s.nil
            clean = element.attributes['clean'].to_s.nil

            if not name.nil?
              name = File.normalize name

              if name =~ /^code\//
                clean ||= true
              end

              map[:compile][name] = clean.to_s.boolean false
            else
              Util::Logger::error '%s: compile下attr节点的name属性不能为空' % element.xpath

              status = false
            end
          end

          REXML::XPath.each(e, 'deploy') do |element|
            REXML::XPath.each(element, 'deploy/attr') do |e_deploy|
              name = e_deploy.attributes['name'].to_s.strip.nil

              if not name.nil?
                name = File.normalize name

                case
                when name =~ /^(code|code_c|sdn)\/build\/output\//
                  dest = $'
                  type = e_deploy.attributes['type'].to_s.strip.nil || default_type

                  if dest =~ /^ums-(\w+)/
                    if ['nms', 'lct'].include? $1
                      type = $1

                      dest.gsub! 'ums-%s' % $1, 'ums-client'
                    end
                  end

                  if valid_type? type
                    types = type.split(',').map { |x| x.strip }.uniq

                    if types.include? 'service'
                      types << 'ems'
                    end

                    map[:deploy][:deploy][name] = types.uniq
                  else
                    Util::Logger::error '%s: type值非法 - %s' % [e_deploy.xpath, type]

                    status = false
                  end
                when name =~ /^installdisk\//
                  dest = e_deploy.text.to_s.strip.nil

                  if not dest.nil?
                    dest = File.normalize dest
                    type = e_deploy.attributes['type'].to_s.strip.nil || default_type

                    if valid_type? type
                      types = type.split(',').map { |x| x.strip }.uniq

                      if types.include? 'service'
                        types << 'ems'
                      end

                      map[:deploy][:deploy]['%s:%s' % [name, dest]] = types.uniq
                    else
                      Util::Logger::error '%s: type值非法 - %s' % [e_deploy.xpath, type]

                      status = false
                    end
                  else
                    Util::Logger::error '%s: installdisk目录下的文件, 必须提供输出路径' % e_deploy.xpath

                    status = false
                  end
                else
                  Util::Logger::error '%s: 源文件必须以code/build/output, sdn/build/output, code_c/build/output或installdisk开始' % e_deploy.xpath

                  status = false
                end
              else
                Util::Logger::error '%s: deploy/deploy节点下的attr子节点的name属性不能为空' % e_deploy.xpath

                status = false
              end
            end

            REXML::XPath.each(element, 'delete/attr') do |e_delete|
              name = e_delete.attributes['name'].to_s.strip.nil

              if not name.nil?
                name = File.normalize name
                type = e_delete.attributes['type'].to_s.strip.nil || default_type

                if name =~ /^ums-(\w+)/
                  if not ['client', 'server'].include? $1
                    Util::Logger::error '%s: deploy/delete节点下的attr子节点的name属性错误, 根目录应该为ums-client或ums-server' % e_delete.xpath

                    status = false
                  end
                end

                if valid_type? type
                  types = type.split(',').map { |x| x.strip }.uniq

                  if types.include? 'service'
                    types << 'ems'
                  end

                  map[:deploy][:delete][name] = types.uniq
                else
                  Util::Logger::error '%s: type值非法 - %s' % [e_delete.xpath, type]

                  status = false
                end
              else
                Util::Logger::error '%s: deploy/delete节点下的attr子节点的name属性不能为空' % e_delete.xpath

                status = false
              end
            end
          end

          REXML::XPath.each(e, 'info/attr') do |element|
            name = element.attributes['name'].to_s.strip.nil
            value = element.text.to_s.strip

            if not name.nil?
              if ['提交人员', '走查人员', '开发经理', '抄送人员'].include? name
                value.gsub! '\\', '/'
              end

              map[:info][name] = value
            else
              Util::Logger::error '%s: info节点下的attr子节点的name属性不能为空' % element.xpath

              status = false
            end
          end

          ['提交人员', '变更版本', '变更类型', '变更描述', '关联故障', '影响分析', '依赖变更', '自测结果', '变更来源', '开发经理', '抄送人员'].each do |x|
            if map[:info][x].nil?
              Util::Logger::error '%s: info节点缺少[%s]' % [e.xpath, x]

              status = false
            end

            case x
            when '变更类型'
              if not ['需求', '优化', '故障'].include? map[:info][x]
                Util::Logger::error '%s: info节点的[%s]必须是需求, 优化 or 故障' % [e.xpath, x]

                status = false
              end
            when '变更描述'
              if map[:info][x].to_s.bytesize < 20
                Util::Logger::error '%s: info节点的[%s]必须最少10个汉字或20个英文字母, 当前字节数: %s' % [e.xpath, x, map[:info][x].to_s.bytesize]

                status = false
              end
            when '关联故障'
              if map[:info][x].to_s !~ /^[\d,\s]+$/
                Util::Logger::error '%s: info节点的[%s]必须是数字' % [e.xpath, x]

                status = false
              end
            when '变更来源'
              if map[:info][x].to_s.strip.empty?
                Util::Logger::error '%s: info节点的[%s]不能为空' % [e.xpath, x]

                status = false
              end
            when '走查人员', '抄送人员'
              map[:info][x] = map[:info][x].to_s.split(',').map { |val| val.strip }.uniq
            else
            end
          end

          list << map
        end

        if status
          list
        else
          nil
        end
      rescue
        Util::Logger::exception $!

        nil
      end
    end

    def build info, tmpdir
      if not File.directory? File.join(@build_home, 'code')
        Util::Logger::error 'no such directory - %s' % File.join(@build_home, 'code')

        return false
      end

      if not File.directory? @code_home
        Util::Logger::error 'no such directory - %s' % @code_home

        return false
      end

      tmpdir = File.expand_path tmpdir

      package = modules[File.dirname(info[:attr][:home])]

      if package.nil?
        Util::Logger::error 'package is nil'

        return false
      end

      if not info[:delete].nil?
        Dir.chdir File.join(@build_home, 'code') do
          info[:delete].each do |name|
            file = File.join info[:attr][:home], expandname(name)

            if not File.delete file do |path|
                Util::Logger::puts path

                path
              end

              return false
            end
          end
        end
      end

      if not info[:source].nil?
        Dir.chdir @code_home do
          File.lock File.join(File.dirname(info[:attr][:home]), 'create.id') do
            if not SCM::cleanup info[:attr][:home]
              return false
            end

            if not SCM::update info[:attr][:home], nil, nil, ($username || 'u3build'), ($password || 'u3build')
              return false
            end
          end

          info[:source].each do |name|
            file = File.join info[:attr][:home], name

            if not File.copy file, File.join(@build_home, 'code', file) do |src, dest|
                Util::Logger::puts src

                [src, dest]
              end

              return false
            end
          end
        end
      end

      if not info[:compile].nil?
        Dir.chdir File.join(@build_home, 'code') do
          info[:compile].each do |name, clean|
            dirname = File.join info[:attr][:home], name

            update_pom_version dirname

            if clean
              Compile::mvn dirname, 'mvn clean -fn -U'
            end

            if dirname.include? '/code_c/'
              if not Compile::mvn dirname, 'mvn deploy -fn -U -Djobs=5', false, true, subject: '<PATCH 通知>补丁编译失败, 请尽快处理'
                return false
              end
            else
              if not Compile::mvn dirname, 'mvn deploy -fn -U', false, true, subject: '<PATCH 通知>补丁编译失败, 请尽快处理'
                return false
              end
            end
          end
        end
      end

      if not info[:deploy].nil?
        if not info[:deploy][:deploy].nil?
          Dir.chdir File.join(@build_home, 'code') do
            info[:deploy][:deploy].each do |name, types|
              if name =~ /^(sdn|code|code_c)\/build\/output\// or name =~ /^installdisk\//
                if name =~ /^(sdn|code|code_c)\/build\/output\//
                  src_file = File.join info[:attr][:home], expandname(name)
                  dest = expandname $'

                  if dest =~ /^ums-(\w+)/
                    if ['nms', 'lct'].include? $1
                      dest.gsub! 'ums-%s' % $1, 'ums-client'
                    end
                  end
                else
                  src, dest = name.split ':', 2

                  src_file = File.join info[:attr][:home], expandname(src)
                  dest = expandname dest
                end

                types.each do |type|
                  dest_file = File.join tmpdir, 'patch', package, type, dest

                  if not File.copy src_file, dest_file do |src, dst|
                      Util::Logger::puts src

                      [src, dst]
                    end

                    return false
                  end

                  if File.file? src_file
                    src_debuginfo = nil
                    dest_debuginfo = nil

                    if File.extname(src_file).downcase == '.dll'
                      src_debuginfo = File.join File.dirname(src_file), '%s.pdb' % File.basename(src_file, '.*')
                      dest_debuginfo = File.join File.dirname(dest_file), '%s.pdb' % File.basename(dest_file, '.*')
                    end

                    if File.extname(src_file).downcase == '.so'
                      src_debuginfo = File.join File.dirname(src_file), '%s.debuginfo' % File.basename(src_file)
                      dest_debuginfo = File.join File.dirname(dest_file), '%s.debuginfo' % File.basename(dest_file)
                    end

                    if not src_debuginfo.nil?
                      if File.file? src_debuginfo
                        if not File.copy src_debuginfo, dest_debuginfo do |src, dst|
                            Util::Logger::puts src

                            [src, dst]
                          end

                          return false
                        end
                      end
                    end
                  end
                end
              end
            end

            if not info[:deploy][:delete].nil?
              paths = []

              info[:deploy][:delete].each do |name, types|
                types.each do |type|
                  paths << File.join(tmpdir, 'patch', package, type)
                end
              end

              paths.uniq!

              if not File.mkdir paths do |path|
                  Util::Logger::puts path
                end

                return false
              end
            end
          end
        end
      end

      if not info[:attr][:script].nil?
        if not File.file? info[:attr][:zip]
          Util::Logger::error '找不到增量补丁包对应的zip文件: %s' % info[:attr][:zip]

          return false
        end

        begin
          zip = ZipFile.new info[:attr][:zip]
        rescue
          Util::Logger::exception $!

          return false
        end

        if not zip.unzip File.join(tmpdir, 'zip')
          return false
        end

        install = nil

        File.glob(File.join(tmpdir, 'zip', '**/install/dbscript-patch/ums-db-update-info.xml')).each do |file|
          install = File.dirname File.dirname(file)

          break
        end

        if install.nil?
          Util::Logger::error '增量补丁包中找不到install/dbscript-patch/ums-db-update-info.xml'

          return false
        end

        prefix = 'install'

        if install =~ /\/(pmu|ppu)\//
          prefix = File.join $1, $'
        end

        info[:attr][:script].each do |type|
          if not File.copy File.join(install, 'dbscript-patch'),
            File.join(tmpdir, 'patch', package, type, prefix, 'dbscript-patch') do |src_file, dest_file|
              Util::Logger::puts src_file

              [src_file, dest_file]
            end

            return false
          end
        end
      end

      to_xml info, File.join(tmpdir, '%s_%s.xml' % [Time.now.strftime('%Y%m%d'), author_info(info[:info])])

      true
    end

    def account_info info, file = nil
      account = nil
      cc_account = []

      if info.nil?
        if not file.nil?
          if File.file? file
            doc = nil

            begin
              doc = REXML::Document.file file
            rescue
              doc = nil
            end

            if doc.nil?
              IO.readlines(file).each do |line|
                line = line.utf8

                if line =~ /<\s*attr\s*.*提交人员.*>(.*)</
                  if $1.strip =~ /\d+$/
                    account = '%s@zte.com.cn' % $&
                  end

                  next
                end

                if line =~ /<\s*attr\s*.*抄送人员.*>(.*)</
                  $1.split(',').each do |string|
                    string.strip!

                    if string =~ /\d+$/
                      cc_account << '%s@zte.com.cn' % $&
                    end
                  end

                  next
                end

                if line =~ /<\s*attr\s*.*开发经理.*>(.*)</
                  if $1.strip =~ /\d+$/
                    cc_account << '%s@zte.com.cn' % $&
                  end

                  next
                end
              end
            else
              REXML::XPath.each doc, '/patches/patch/info/attr' do |e|
                name = e.attributes['name'].to_s.strip
                value = e.text.to_s.strip

                case name
                when '提交人员'
                  if value =~ /\d+$/
                    account = '%s@zte.com.cn' % $&
                  end
                when '抄送人员'
                  value.split(',').each do |string|
                    if string =~ /\d+$/
                      cc_account << '%s@zte.com.cn' % $&
                    end
                  end
                when '开发经理'
                  if value =~ /\d+$/
                    cc_account << '%s@zte.com.cn' % $&
                  end
                else
                end
              end
            end
          end
        end
      else
        if info.has_key? '提交人员'
          if info['提交人员'].to_s =~ /\d+$/
            account = '%s@zte.com.cn' % $&
          end
        end

        if info.has_key? '抄送人员'
          info['抄送人员'].each do |string|
            if string =~ /\d+$/
              cc_account << '%s@zte.com.cn' % $&
            end
          end
        end

        if info.has_key? '开发经理'
          if info['开发经理'].to_s =~ /\d+$/
            cc_account << '%s@zte.com.cn' % $&
          end
        end
      end

      [account, cc_account.sort.uniq]
    end

    def author_info info
      if not info.nil?
        author = info['提交人员'].to_s.strip

        author.gsub! '/', ''
        author.gsub! '\\', ''

        author
      else
        nil
      end
    end

    def get_id
      id = '%s_0000' % Time.now.strftime('%Y%m%d')

      File.glob(File.join(@build_home, 'patch/patch', '%s_*' % Time.now.strftime('%Y%m%d'))).sort.each do |name|
        if File.basename(name) =~ /^\d{8}_\d{4}$/
          id = File.basename name
        end
      end

      id.next
    end

    def to_xml info, file
      doc = REXML::Document.new "<patches version='2.0'/>"

      element = REXML::Element.new 'patch'
      element.attributes['name'] = info[:attr][:home]

      if not info[:attr][:script].nil?
        element.attributes['script'] = info[:attr][:script].join ', '
      end

      if not info[:attr][:os].nil?
        element.attributes['os'] = info[:attr][:os].join ', '
      end

      if not info[:delete].nil?
        delete_element = REXML::Element.new 'delete'

        info[:delete].each do |name|
          e = REXML::Element.new 'attr'
          e.attributes['name'] = name

          delete_element << e
        end

        element << delete_element
      end

      if not info[:source].nil?
        source_element = REXML::Element.new 'source'

        info[:source].each do |name|
          e = REXML::Element.new 'attr'
          e.attributes['name'] = name

          source_element << e
        end

        element << source_element
      end

      if not info[:compile].nil?
        compile_element = REXML::Element.new 'compile'

        info[:compile].each do |name, clean|
          e = REXML::Element.new 'attr'
          e.attributes['name'] = name
          e.attributes['clean'] = clean

          compile_element << e
        end

        element << compile_element
      end

      if not info[:deploy].nil?
        deploy_element = REXML::Element.new 'deploy'

        if not info[:deploy][:deploy].nil?
          e_deploy = REXML::Element.new 'deploy'

          info[:deploy][:deploy].each do |name, types|
            e = REXML::Element.new 'attr'

            if name.start_with? 'installdisk'
              src, dest = name.split ':', 2

              e.attributes['name'] = src
              e.text = dest
            else
              e.attributes['name'] = name
            end

            e.attributes['type'] = types.join ', '

            e_deploy << e
          end

          deploy_element << e_deploy
        end

        if not info[:deploy][:delete].nil?
          e_delete = REXML::Element.new'delete'

          info[:deploy][:delete].each do |name, types|
            e = REXML::Element.new 'attr'
            e.attributes['name'] = name
            e.attributes['type'] = types.join ', '

            e_delete << e
          end

          deploy_element << e_delete
        end

        element << deploy_element
      end

      info_element = REXML::Element.new 'info'

      info[:info].each do |name, value|
        e = REXML::Element.new 'attr'
        e.attributes['name'] = name

        if value.is_a? Array
          e.text = value.join ', '
        else
          e.text = value
        end

        info_element << e
      end

      element << info_element

      doc.root << element
      doc.to_file file

      true
    end

    def expandname filename
      filename = File.normalize filename

      dirname = File.dirname filename
      basename = File.basename filename, '.*'

      if OS::windows?
        case File.extname(filename).downcase
        when '.sh'
          filename = File.join dirname, '%s.bat' % basename
        when '.so'
          if basename =~ /^lib(.*)$/
            filename = File.join dirname, '%s.dll' % $1
          else
            filename = File.join dirname, '%s.dll' % basename
          end
        else
        end
      else
        case File.extname(filename).downcase
        when '.bat'
          filename = File.join dirname, '%s.sh' % basename
        when '.dll', '.lib'
          filename = File.join dirname, 'lib%s.so' % basename
        when '.exe'
          filename = File.join dirname, basename
        else
        end
      end

      filename = File.normalize filename
    end

    def valid_type? type = nil
      type.to_s.split(',').each do |name|
        if not ['ems', 'nms', 'lct', 'update', 'upgrade', 'service'].include? name.strip
          return false
        end
      end

      true
    end

    def modules
      {
        'Interface'   => 'interface',
        'BN_Platform' => 'platform',
        'U31_E2E'     => 'e2e',
        'BN_NECOMMON' => 'necommon',
        'BN_UCA'      => 'uca',
        'NAF_XMLFILE' => 'xmlfile',
        'BN_NAF'      => 'naf',
        'BN_SDH'      => 'sdh',
        'BN_WDM'      => 'wdm',
        'BN_PTN'      => 'ptn',
        'BN_PTN2'     => 'ptn2',
        'BN_IP'       => 'ip'
      }
    end

    def default_type
      'ems'
    end

    def update_pom_version home
      if not ENV['POM_VERSION'].nil?
        version = ENV['POM_VERSION']

        if not version.end_with? '-SNAPSHOT'
          version = '%s-SNAPSHOT' % version
        end

        file = File.join home, 'pom.xml'

        if File.file? file
          begin
            doc = REXML::Document.file file

            REXML::XPath.each doc, '/project/parent/version' do |e|
              text = e.text.to_s.strip

              if version != text
                if not ['1.0-SNAPSHOT', '2.0-SNAPSHOT', '3.0-SNAPSHOT', '4.0-SNAPSHOT', '5.0-SNAPSHOT'].include? text
                  e.text = version

                  doc.to_file file
                end
              end

              break
            end
          rescue
          end
        end
      end
    end

    # args
    #   id
    #
    #   subject
    #   info
    #   file
    def send_smtp account, cc_account, args = {}
      account ||= cc_account

      if account.nil?
        return true
      end

      share_name = '.'
      ip = System::ip '192.168.'

      if Dir.pwd =~ /\/(release|dev)\//
        name = $'.split('/').first

        if name.include? '_stn'
          share_name = 'stn_%s_%s' % [$1, name.gsub('_stn', '')]
        else
          share_name = '%s_%s' % [$1, name]

          if OS::windows?
            if $x64
              share_name = 'x64_%s' % share_name
            end
          end
        end
      end

      lines = []

      if ENV.has_key? 'BUILD_URL'
        http = File.join ENV['BUILD_URL'], 'console'

        lines <<  'Jenkins日志: <font color = "blue"><a href="%s">%s</a></font><br>' % [http, http]
        lines << '<br>'
      end

      lines << '操作系统: <font color = "blue">%s</font><br>' % OS::name
      lines << '当前目录: <font color = "blue">%s</font><br>' % Dir.pwd.gsub('/', '\\')

      if args[:id]
        dirname = File.join '//%s' % ip, share_name, 'patch', args[:id]
        lines << '补丁位置: <a href = "file:%s"><font color = "red">%s</font></a><br>' % [dirname, dirname.gsub('/', '\\')]
      else
        cc_account ||= []
        cc_account += ($mail_cc || []).to_array
      end

      if not $errors.nil?
        lines << '<br>'

        $errors.each do |line|
          lines << '%s<br>' % line.rstrip
        end
      end

      lines << '<br>'

      Net::send_smtp nil, nil, account, cc: cc_account do |mail|
        subject = args[:subject] || '<PATCH 通知>补丁制作失败, 请尽快处理'

        author = nil

        if args[:info]
          author = author_info args[:info][:info]
          subject += '_%s' % author
        end

        if $x64
          mail.subject = '%s(%s-x64)' % [subject, OS::name]
        else
          mail.subject = '%s(%s)' % [subject, OS::name]
        end

        mail.html = lines.join "\n"

        if args[:info]
          File.tmpdir do |dir|
            filename = File.join dir, '%s_%s.xml' % [Time.now.strftime('%Y%m%d'), author]
            to_xml args[:info], filename
            mail.attach filename.locale
          end
        end

        if args[:file]
          mail.attach args[:file].locale
        end

        if not $loggers.nil?
          File.tmpdir do |dir|
            filename = File.join dir, 'build.log'

            File.open filename, 'w' do |file|
              $loggers.each do |line|
                file.puts line.rstrip.locale
              end
            end

            mail.attach filename.locale
          end
        end
      end
    end
  end

  class Stn < Bn
    private

    def valid_type? type = nil
      type.to_s.split(',').each do |name|
        if not ['stn'].include? name.strip
          return false
        end
      end

      true
    end

    def modules
      {
        'u3_interface'    => 'u3_interface',
        'sdn_interface'   => 'interface',
        'sdn_framework'   => 'framework',
        'sdn_application' => 'application',
        'sdn_nesc'        => 'nesc',
        'sdn_tunnel'      => 'tunnel',
        'CTR-ICT'         => 'ict',
        'SPTN-E2E'        => 'e2e',
        'sdn_installation'=> 'installation'
      }
    end

    def default_type
      'stn'
    end

    def update_pom_version home
    end
  end
end