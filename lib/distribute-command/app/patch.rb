module Patch
  class Bn
    def initialize home, source_home, devtools_home, output_home
    end

    def patch name
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
    #     source:
    #       - name
    #     delete:
    #       - name
    #     compile:
    #       name:
    #         clean: false
    #         cmdline: cmdline
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
            :source   => [],
            :delete   => [],
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

          script = e.attributes['script'].to_s.strip.nil

          if not script.nil?
            map[:attr][:script] = script.split(',').map { |x| x.strip }
          end

          os = e.attributes['os'].to_s.strip.nil

          if not os.nil?
            map[:attr][:os] = os.split(',').map { |x| x.strip }
          end

          if map[:attr][:home].nil?
            Util::Logger::error '%s: patch节点的name属性不能为空' % e.xpath

            status = false
          else
            if not module_names.include?(File.dirname(map[:attr][:home]))
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

          REXML::XPath.each(e, 'source/attr') do |element|
            name = element.attributes['name'].to_s.strip.nil

            if not name.nil?
              map[:source] << File.normalize(name)
            else
              Util::Logger::error '%s: source节点下的attr子节点的name属性不能为空' % element.xpath

              status = false
            end
          end

          REXML::XPath.each(e, 'delete/attr') do |element|
            name = element.attributes['name'].to_s.strip.nil

            if not name.nil?
              map[:delete] << File.normalize(name)
            else
              Util::Logger::error '%s: delete节点下的attr子节点的name属性不能为空' % element.xpath

              status = false
            end
          end

          map[:delete].uniq!

          REXML::XPath.each(e, 'compile') do |element|
            map[:compile] ||= {}

            REXML::XPath.each(element, 'attr') do |e_cmdline|
              name = e_cmdline.attributes['name'].to_s.strip.nil
              clean = e_cmdline.attributes['clean'].to_s.strip.nil

              if not name.nil?
                name = File.normalize name

                if name =~ /^code\//
                  clean ||= 'true'
                end

                clean = clean.to_s.boolean false

                map[:compile][name] ||= {
                  :clean    => clean,
                  :cmdline  => nil
                }
              else
                Util::Logger::error '%s: compile节点下的attr子节点的name属性和attr子节点的值不能为空' % e_cmdline.xpath

                status = false
              end
            end

            map[:compile].each do |name, cmdline_info|
              if not cmdline_info[:compile].nil?
                map[:compile][name][:compile].uniq!
              end
            end
          end

          REXML::XPath.each(e, 'deploy') do |element|
            REXML::XPath.each(element, 'deploy/attr') do |e_deploy|
              name = e_deploy.attributes['name'].to_s.strip.nil

              if not name.nil?
                name = File.normalize name

                case
                when name =~ /^(code|code_c)\/build\/output\//
                  dest = $'
                  type = e_deploy.attributes['type'].to_s.strip.nil || 'ems'

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
                    type = e_deploy.attributes['type'].to_s.strip.nil || 'ems'

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
                  Util::Logger::error '%s: 源文件必须以code/build/output, code_c/build/output或installdisk开始' % e_deploy.xpath

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
                type = e_delete.attributes['type'].to_s.strip.nil || 'ems'

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

    def module_names
      [
        'Interface',
        'BN_Platform',
        'U31_E2E',
        'BN_NECOMMON',
        'BN_UCA',
        'NAF_XMLFILE',
        'BN_NAF',
        'BN_SDH',
        'BN_WDM',
        'BN_PTN',
        'BN_PTN2',
        'BN_IP'
      ]
    end
  end
end