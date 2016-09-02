require 'distribute-command'

module Jenkins
  class Project
    def initialize path
      @path = path
    end

    def build args = nil
      args = {
        :actions            => nil,
        :description        => nil,
        :keep_dependencies  => false,
        :authorization      => nil,
        :logrotator_days    => 31,
        :logrotator_num     => -1,
        :parameters         => nil,
        :scm                => nil,
        :assigned_node      => nil,
        :canroam            => true,
        :disabled           => false,
        :downstream         => false,
        :upstream           => false,
        :triggers           => nil,     # :timer[:spec], :scm[:spec], :file[:spec,:directory,:files]
        :concurrent         => true,
        :builders           => nil,     # :bat, :shell, :ruby
        :publishers         => nil,
        :build_timeout      => 180,
        :timestamper        => true
      }.merge args || {}

      doc = REXML::Document.new '<project/>'

      if args.has_key? :actions
        doc.root << actions(args)
      end

      if args.has_key? :description
        doc.root << description(args)
      end

      if args.has_key? :keep_dependencies
        doc.root << keep_dependencies(args)
      end

      doc.root << properties(args)

      if args.has_key? :scm
        doc.root << scm(args)
      end

      if not args[:assigned_node].nil?
        doc.root << assigned_node(args)
      end

      if args.has_key? :canroam
        doc.root << canroam(args)
      end

      if args.has_key? :disabled
        doc.root << disabled(args)
      end

      if args.has_key? :downstream
        doc.root << downstream(args)
      end

      if args.has_key? :upstream
        doc.root << upstream(args)
      end

      if args.has_key? :triggers
        doc.root << triggers(args)
      end

      if args.has_key? :concurrent
        doc.root << concurrent(args)
      end

      doc.root << builders(args)

      if args.has_key? :publishers
        doc.root << publishers(args)
      end

      if args.has_key? :build_timeout or args.has_key? :timestamper
        doc.root << build_wrappers(args)
      end

      doc.to_file File.join(@path, 'config.xml')
    end

    private

    def actions args
      element = REXML::Element.new 'actions'

      element
    end

    def description args
      element = REXML::Element.new 'description'
      element.text = args[:description]

      element
    end

    def keep_dependencies args
      element = REXML::Element.new 'keepDependencies'
      element.text = args[:keep_dependencies].to_s.boolean false

      element
    end

    def properties args
      element = REXML::Element.new 'properties'

      if not args[:authorization].nil?
        element << authorization(args[:authorization])
      end

      element << logrotator(args[:logrotator_days].to_i, args[:logrotator_num].to_i)

      if not args[:parameters].nil? and not args[:parameters].empty?
        element << parameters_definition(args[:parameters])
      end

      element
    end

    def scm args
      element = REXML::Element.new 'scm'

      case args[:scm]
      when nil
        element.attributes['class'] = 'hudson.scm.NullSCM'
      else
      end

      element
    end

    def assigned_node args
      element = REXML::Element.new 'assignedNode'
      element.text = args[:assigned_node]

      element
    end

    def canroam args
      element = REXML::Element.new 'canRoam'
      element.text = args[:canroam].to_s.boolean true

      element
    end

    def disabled args
      element = REXML::Element.new 'disabled'
      element.text = args[:disabled].to_s.boolean false

      element
    end

    def downstream args
      element = REXML::Element.new 'blockBuildWhenDownstreamBuilding'
      element.text = args[:downstream].to_s.boolean false

      element
    end

    def upstream args
      element = REXML::Element.new 'blockBuildWhenUpstreamBuilding'
      element.text = args[:upstream].to_s.boolean false

      element
    end

    def triggers args
      element = REXML::Element.new 'triggers'

      if not args[:triggers].nil?
        if not args[:triggers][:timer].nil?
          e = REXML::Element.new 'hudson.triggers.TimerTrigger'

          spec_e = REXML::Element.new 'spec'
          spec_e.text = args[:triggers][:timer][:spec]
          e << spec_e

          element << e
        end

        if not args[:triggers][:scm].nil?
          e = REXML::Element.new 'hudson.triggers.SCMTrigger'

          spec_e = REXML::Element.new 'spec'
          spec_e.text = args[:triggers][:scm][:spec]
          e << spec_e

          ignore_e = REXML::Element.new 'ignorePostCommitHooks'
          ignore_e.text = false
          e << ignore_e

          element << e
        end

        if not args[:triggers][:file].nil?
          e = REXML::Element.new 'hudson.plugins.filesfoundtrigger.FilesFoundTrigger'
          e.attributes['plugin'] = 'files-found-trigger'

          spec_e = REXML::Element.new 'spec'
          spec_e.text = args[:triggers][:file][:spec]
          e << spec_e

          dir_e = REXML::Element.new 'directory'
          dir_e.text = args[:triggers][:file][:directory]
          e << dir_e

          files_e = REXML::Element.new 'files'
          files_e.text = args[:triggers][:file][:files]
          e << files_e

          e << REXML::Element.new('ignoredFiles')

          element << e
        end
      end

      element
    end

    def concurrent args
      element = REXML::Element.new 'concurrentBuild'
      element.text = args[:concurrent].to_s.boolean true

      element
    end

    def builders args
      element = REXML::Element.new 'builders'

      if not args[:builders].nil?
        if not args[:builders][:bat].nil?
          e = REXML::Element.new 'hudson.tasks.BatchFile'

          command_e = REXML::Element.new 'command'
          command_e.text = args[:builders][:bat]
          e << command_e

          element << e
        end

        if not args[:builders][:shell].nil?
          e = REXML::Element.new 'hudson.tasks.Shell'

          command_e = REXML::Element.new 'command'
          command_e.text = args[:builders][:shell]
          e << command_e

          element << e
        end

        if not args[:builders][:ruby].nil?
          e = REXML::Element.new 'hudson.plugins.ruby.Ruby'
          e.attributes['plugin'] = 'ruby'

          command_e = REXML::Element.new 'command'
          command_e.text = args[:builders][:ruby]
          e << command_e

          element << e
        end
      end

      element
    end

    def publishers args
      element = REXML::Element.new 'publishers'

      element
    end

    def build_wrappers args
      element = REXML::Element.new 'buildWrappers'

      if not args[:build_timeout].nil?
        if args[:build_timeout].to_i > 0
          element << build_timeout(args[:build_timeout].to_i)
        end
      end

      if not args[:timestamper].nil?
        element << timestamper
      end

      element
    end

    # ------------------------------------------------------

    def authorization usernames
      element = REXML::Element.new 'hudson.security.AuthorizationMatrixProperty'

      usernames.to_array.each do |username|
        e = REXML::Element.new 'permission'
        e.text = 'hudson.model.Item.Build:%s' % username
        element << e

        e = REXML::Element.new 'permission'
        e.text = 'hudson.model.Item.Cancel:%s' % username
        element << e

        e = REXML::Element.new 'permission'
        e.text = 'hudson.model.Item.Read:%s' % username
        element << e
      end

      element
    end

    def logrotator days = 31, num = -1
      element = REXML::Element.new 'jenkins.model.BuildDiscarderProperty'

      strategy_element = REXML::Element.new 'strategy'
      strategy_element.attributes['class'] = 'hudson.tasks.LogRotator'

      e = REXML::Element.new 'daysToKeep'
      e.text = days.to_i
      strategy_element << e

      e = REXML::Element.new 'numToKeep'
      e.text = num.to_i
      strategy_element << e

      e = REXML::Element.new 'artifactDaysToKeep'
      e.text = days.to_i
      strategy_element << e

      e = REXML::Element.new 'artifactNumToKeep'
      e.text = num.to_i
      strategy_element << e

      element << strategy_element

      element
    end

    def parameters_definition params
      element = REXML::Element.new 'hudson.model.ParametersDefinitionProperty'

      def_element = REXML::Element.new 'parameterDefinitions'

      params.each do |name, description, defaultvalue|
        if [true, false].include? defaultvalue
          bool_element = REXML::Element.new 'hudson.model.BooleanParameterDefinition'

          e = REXML::Element.new 'name'
          e.text = name
          bool_element << e

          e = REXML::Element.new 'description'
          e.text = description
          bool_element << e

          e = REXML::Element.new 'defaultValue'
          e.text = defaultvalue
          bool_element << e

          def_element << bool_element
        else
          str_element = REXML::Element.new 'hudson.model.StringParameterDefinition'

          e = REXML::Element.new 'name'
          e.text = name
          str_element << e

          e = REXML::Element.new 'description'
          e.text = description
          str_element << e

          e = REXML::Element.new 'defaultValue'
          e.text = defaultvalue
          str_element << e

          def_element << str_element
        end
      end

      element << def_element

      element
    end

    def build_timeout minute = 180
      element = REXML::Element.new 'hudson.plugins.build__timeout.BuildTimeoutWrapper'
      element.attributes['plugin'] = 'build-timeout'

      strategy_element = REXML::Element.new 'strategy'
      strategy_element.attributes['class'] = 'hudson.plugins.build_timeout.impl.AbsoluteTimeOutStrategy'

      e = REXML::Element.new 'timeoutMinutes'
      e.text = minute

      strategy_element << e
      element << strategy_element

      operation_element = REXML::Element.new 'operationList'

      e = REXML::Element.new 'hudson.plugins.build__timeout.operations.AbortOperation'

      operation_element << e
      element << operation_element

      element
    end

    def timestamper
      element = REXML::Element.new 'hudson.plugins.timestamper.TimestamperBuildWrapper'
      element.attributes['plugin'] = 'timestamper'

      element
    end
  end

  class CppCheck < Project
    def build args = nil
      args ||= {}

      args[:assigned_node] = 'linux'
      args[:parameters] = [
        ['home', '工作目录', 'cppcheck']
      ]

      args[:logrotator_days] = 7
      args[:logrotator_num] = 30

      super args
    end

    private

    def publishers args
      element = REXML::Element.new 'publishers'

      cppcheck_e = REXML::Element.new 'org.jenkinsci.plugins.cppcheck.CppcheckPublisher'
      cppcheck_e.attributes['plugin'] = 'cppcheck'
      cppcheck_config_e = REXML::Element.new 'cppcheckConfig'

      e = REXML::Element.new 'pattern'
      e.text = '${home}/**/cppcheck-result.xml'
      cppcheck_config_e << e

      e = REXML::Element.new 'ignoreBlankFiles'
      e.text = true
      cppcheck_config_e << e

      e = REXML::Element.new 'allowNoReport'
      e.text = true
      cppcheck_config_e << e

      cppcheck_e << cppcheck_config_e
      element << cppcheck_e

      element
    end
  end

  class Pipeline < Project
    def initialize path
      @path = path
      @jenkins_file_url = '/home/workspace/git/JenkinsFile'
    end

    def build args = nil
      args = {
        :actions            => nil,
        :description        => nil,
        :keep_dependencies  => false,
        :authorization      => nil,
        :logrotator_days    => 31,
        :logrotator_num     => -1,
        :parameters         => nil,
        :disabled           => false,
        :concurrent         => true,
        :script             => nil,
        :script_path        => nil,
        :triggers           => nil    # :timer
      }.merge args || {}

      doc = REXML::Document.new "<flow-definition plugin='workflow-job'/>"

      if args.has_key? :actions
        doc.root << actions(args)
      end

      if args.has_key? :description
        doc.root << description(args)
      end

      if args.has_key? :keep_dependencies
        doc.root << keep_dependencies(args)
      end

      doc.root << properties(args)

      doc.root << definition(args)

      if args.has_key? :triggers
        doc.root << triggers(args)
      end

      if args.has_key? :concurrent
        doc.root << concurrent(args)
      end

      doc.to_file File.join(@path, 'config.xml')
    end

    private

    def definition args
      element = REXML::Element.new 'definition'

      if args[:script_path]
        element.attributes['class'] = 'org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition'
        element.attributes['plugin'] = 'workflow-cps'

        scm_element = REXML::Element.new 'scm'
        scm_element.attributes['class'] = 'hudson.plugins.git.GitSCM'
        scm_element.attributes['plugin'] = 'git'

        e = REXML::Element.new 'configVersion'
        e.text = 2
        scm_element << e

        configs_e = REXML::Element.new 'userRemoteConfigs'
        config_e = REXML::Element.new 'hudson.plugins.git.UserRemoteConfig'
        e = REXML::Element.new 'url'
        e.text = @jenkins_file_url
        config_e << e
        configs_e << config_e
        scm_element << configs_e

        branches_e = REXML::Element.new 'branches'
        branch_e = REXML::Element.new 'hudson.plugins.git.BranchSpec'
        e = REXML::Element.new 'name'
        e.text = '*/master'
        branch_e << e
        branches_e << branch_e
        scm_element << branches_e

        e = REXML::Element.new 'doGenerateSubmoduleConfigurations'
        e.text = false
        scm_element << e

        e = REXML::Element.new 'submoduleCfg'
        e.attributes['class'] = 'list'
        scm_element << e

        e = REXML::Element.new 'extensions'
        scm_element << e

        element << scm_element

        script_path_element = REXML::Element.new 'scriptPath'
        script_path_element.text = args[:script_path]
        element << script_path_element
      else
        element.attributes['class'] = 'org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition'
        element.attributes['plugin'] = 'workflow-cps'

        e = REXML::Element.new 'script'
        e.text = args[:script]
        element << e

        e = REXML::Element.new 'sandbox'
        e.text = true
        element << e
      end

      element
    end
  end
end

module Jenkins
  class Base
    def initialize
      @cmdline = 'mvn deploy -fn -U -T 5'
      @cmdline_cpp = 'mvn deploy -fn -U -T 10 -Djobs=10'

      @args_logrotator = {
        :logrotator_days  => 31,
        :logrotator_num   => 150
      }

      @args_logrotator_command = {
        :logrotator_days  => 3,
        :logrotator_num   => 20
      }

      @args_logrotator_module = {
        :logrotator_days  => 7,
        :logrotator_num   => 30
      }

      @args_logrotator_compile_module = {
        :logrotator_days  => 7,
        :logrotator_num   => 500
      }
    end

    def build
      bn_build
      stn_build
    end

    private

    def bn_build
      parameters = [
        ['home', '工作目录', '/home/user/build/main'],
        ['agent', 'Agent名称', 'linux']
      ]

      parameters_test = [
        ['home',  '工作目录',   'd:/build/main'],
        ['agent', 'Agent名称',  'windows']
      ]

      {
        'bn_build'      => {
          :script_path  => 'bn/build.groovy',
          :parameters   => [
            ['update',  '版本更新', true],
            ['compile', '版本编译', true],
            ['install', '版本制作', true],
            ['check',   '版本检查', false],
            ['test',    '版本测试', false],
            ['force',   '全量编译', true],

            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', ''],
            ['type',            '版本类型',   '']
          ]
        },
        'bn_update'     => {
          :script_path  => 'bn/update.groovy',
          :parameters   => []
        },
        'bn_deploy'  => {
          :script_path  => 'bn/deploy.groovy',
          :parameters   => [
            ['version', '版本号', '']
          ]
        },
        'bn_compile'    => {
          :script_path  => 'bn/compile.groovy',
          :parameters   => [
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['version', '版本号',   '']
          ]
        },
        'bn_compile_cpp'=> {
          :script_path  => 'bn/compile_cpp.groovy',
          :parameters   => [
            ['cmdline', '编译命令', @cmdline_cpp],
            ['force',   '全量编译', true],
            ['version', '版本号',   '']
          ]
        },
        'bn_install'    => {
          :authorization=> ['bnbuild'],
          :script_path  => 'bn/install.groovy',
          :parameters   => [
            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', ''],
            ['type',            '版本类型',   '']
          ]
        },
        'bn_check'      => {
          :script_path  => 'bn/check.groovy',
          :parameters   => []
        },
        'bn_check_cpp'  => {
          :script_path  => 'bn/check_cpp.groovy',
          :parameters   => []
        },
        'bn_test'       => {
          :authorization=> ['bnbuild'],
          :script_path  => 'bn/test.groovy',
          :parameters   => [
            ['version', '版本号',     ''],
            ['reboot',  '重启测试机', false]
          ]
        },

        'bn_update_devtools'    => {
          :script_path  => 'bn/update_devtools.groovy',
          :parameters   => []
        },
        'bn_update_module'      => {
          :script_path  => 'bn/update_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        },
        'bn_compile_module'     => {
          :script_path  => 'bn/compile_module.groovy',
          :parameters   => [
            ['name',    '模块名称', ''],
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['retry',   '失败重试', true],
            ['dir',     '编译目录', ''],
            ['version', '版本号',   '']
          ]
        },
        'bn_compile_cpp_module' => {
          :script_path  => 'bn/compile_cpp_module.groovy',
          :parameters   => [
            ['name',    '模块名称', ''],
            ['cmdline', '编译命令', @cmdline_cpp],
            ['force',   '全量编译', true],
            ['retry',   '失败重试', true],
            ['dir',     '编译目录', ''],
            ['version', '版本号',   '']
          ]
        },
        'bn_install_uep'        => {
          :script_path  => 'bn/install_uep.groovy',
          :parameters   => [
            ['version', '版本号',   ''],
            ['type',    '版本类型', '']
          ]
        },
        'bn_install_module'     => {
          :script_path  => 'bn/install_module.groovy',
          :parameters   => [
            ['name',            '模块名称',   ''],
            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', ''],
            ['type',            '版本类型',   '']
          ]
        },
        'bn_check_module'       => {
          :script_path  => 'bn/check_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        },
        'bn_check_cpp_module'       => {
          :script_path  => 'bn/check_cpp_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        }
      }.each do |k, v|
        if k == 'bn_test'
          v[:parameters] = parameters_test + v[:parameters]
        else
          v[:parameters] = parameters + v[:parameters]
        end

        pipeline = Jenkins::Pipeline.new k

        if k.include? '_module'
          if k.include? '_compile_'
            pipeline.build v.merge(@args_logrotator_compile_module)
          else
            pipeline.build v.merge(@args_logrotator_module)
          end
        else
          pipeline.build v.merge(@args_logrotator)
        end
      end

      parameters = [
        ['home', '工作目录', 'd:/build/main'],
        ['agent', 'Agent名称', 'windows']
      ]

      {
        'bn_build_win'              => {
          :script_path  => 'bn/build_win.groovy',
          :parameters   => [
            ['update',  '版本更新', true],
            ['compile', '版本编译', true],
            ['install', '版本制作', true],
            ['check',   '版本检查', false],
            ['test',    '版本测试', false],
            ['force',   '全量编译', true],

            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', ''],
            ['type',            '版本类型',   '']
          ]
        },
        'bn_compile_win'            => {
          :script_path  => 'bn/compile_win.groovy',
          :parameters   => [
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['version', '版本号',   '']
          ]
        },
        'bn_compile_cpp_win'        => {
          :script_path  => 'bn/compile_cpp_win.groovy',
          :parameters   => [
            ['cmdline', '编译命令', @cmdline_cpp],
            ['force',   '全量编译', true],
            ['version', '版本号',   '']
          ]
        },
        'bn_compile_module_win'     => {
          :script_path  => 'bn/compile_module_win.groovy',
          :parameters   => [
            ['name',    '模块名称', ''],
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['retry',   '失败重试', true],
            ['dir',     '编译目录', ''],
            ['version', '版本号',   '']
          ]
        },
        'bn_compile_cpp_module_win' => {
          :script_path  => 'bn/compile_cpp_module_win.groovy',
          :parameters   => [
            ['name',    '模块名称', ''],
            ['cmdline', '编译命令', @cmdline_cpp],
            ['force',   '全量编译', true],
            ['retry',   '失败重试', true],
            ['dir',     '编译目录', ''],
            ['version', '版本号',   '']
          ]
        }
      }.each do |k, v|
        v[:parameters] = parameters + v[:parameters]

        pipeline = Jenkins::Pipeline.new k

        if k.include? '_module'
          if k.include? '_compile_'
            pipeline.build v.merge(@args_logrotator_compile_module)
          else
            pipeline.build v.merge(@args_logrotator_module)
          end
        else
          pipeline.build v.merge(@args_logrotator)
        end
      end

      cppcheck = Jenkins::CppCheck.new 'bn_cppcheck'
      cppcheck.build

      args = {
        :authorization    => ['bnbuild'],
        :logrotator_days  => 3,
        :logrotator_num   => 20,
        :script_path      => 'bn/command.groovy',
        :parameters       => [
          ['home',      '工作目录',   'bn/daily/windows'],
          ['configure', '配置文件',   'installation.xml'],
          ['version',   '版本号',     ''],
          ['reboot',    '重启测试机', false]
        ]
      }

      pipeline = Jenkins::Pipeline.new 'bn_command'
      pipeline.build args.merge(@args_logrotator_command)

      parameters = [
        ['home', '工作目录', '/home/user/build/main'],
        ['agent', 'Agent名称', 'kloc']
      ]

      {
        'bn_build_kloc'       => {
          :concurrent   => false,
          :script_path  => 'bn/build_kloc.groovy',
          :parameters   => [
            ['update',  '版本更新', true],
            ['compile', '版本编译', true],
            ['force',   '全量编译', true]
          ]
        },
        'bn_kloc'             => {
          :concurrent   => false,
          :script_path  => 'bn/kloc.groovy',
          :parameters   => []
        },
        'bn_kloc_cpp'         => {
          :concurrent   => false,
          :script_path  => 'bn/kloc_cpp.groovy',
          :parameters   => []
        },
        'bn_kloc_ignore'      => {
          :script_path  => 'bn/kloc_ignore.groovy',
          :parameters   => []
        },
        'bn_kloc_module'      => {
          :script_path  => 'bn/kloc_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        },
        'bn_kloc_cpp_module'  => {
          :script_path  => 'bn/kloc_cpp_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        }
      }.each do |k, v|
        v[:parameters] = parameters + v[:parameters]

        pipeline = Jenkins::Pipeline.new k
        pipeline.build v.merge(@args_logrotator_module)
      end
    end

    def stn_build
      parameters = [
        ['home',  '工作目录',   '/home/user/build/stn/main'],
        ['agent', 'Agent名称',  'linux']
      ]

      parameters_test = [
        ['home',  '工作目录',   'f:/build/stn/main'],
        ['agent', 'Agent名称',  'windows']
      ]

      {
        'stn_build'   => {
          :script_path  => 'stn/build.groovy',
          :parameters   => [
            ['update',  '版本更新', true],
            ['compile', '版本编译', true],
            ['install', '版本制作', true],
            ['check',   '版本检查', false],
            ['test',    '版本测试', false],
            ['force',   '全量编译', true],

            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', '']
          ]
        },
        'stn_update'  => {
          :script_path  => 'stn/update.groovy',
          :parameters   => []
        },
        'stn_deploy'  => {
          :script_path  => 'stn/deploy.groovy',
          :parameters   => [
            ['version', '版本号', '']
          ]
        },
        'stn_compile' => {
          :script_path  => 'stn/compile.groovy',
          :parameters   => [
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['version', '版本号',   '']
          ]
        },
        'stn_install' => {
          :authorization=> ['stnbuild'],
          :script_path  => 'stn/install.groovy',
          :parameters   => [
            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', '']
          ]
        },
        'stn_check'   => {
          :script_path  => 'stn/check.groovy',
          :parameters   => []
        },
        'stn_test'    => {
          :authorization=> ['stnbuild'],
          :script_path  => 'stn/test.groovy',
          :parameters   => [
            ['version', '版本号',     ''],
            ['reboot',  '重启测试机', true]
          ]
        },

        'stn_update_module' => {
          :script_path  => 'stn/update_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        },
        'stn_compile_module'=> {
          :script_path  => 'stn/compile_module.groovy',
          :parameters   => [
            ['name',    '模块名称', ''],
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['retry',   '失败重试', true],
            ['dir',     '编译目录', ''],
            ['version', '版本号',   '']
          ]
        },
        'stn_install_uep'   => {
          :script_path  => 'stn/install_uep.groovy',
          :parameters   => [
            ['version', '版本号', '']
          ]
        },
        'stn_install_module'=> {
          :script_path  => 'stn/install_module.groovy',
          :parameters   => [
            ['name',            '模块名称',   ''],
            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', '']
          ]
        },
        'stn_check_module'  => {
          :script_path  => 'stn/check_module.groovy',
          :parameters   => [
            ['name', '模块名称', '']
          ]
        }
      }.each do |k, v|
        if k == 'stn_test'
          v[:parameters] = parameters_test + v[:parameters]
        else
          v[:parameters] = parameters + v[:parameters]
        end

        pipeline = Jenkins::Pipeline.new k

        if k.include? '_module'
          if k.include? '_compile_'
            pipeline.build v.merge(@args_logrotator_compile_module)
          else
            pipeline.build v.merge(@args_logrotator_module)
          end
        else
          pipeline.build v.merge(@args_logrotator)
        end
      end

      parameters = [
        ['home', '工作目录', 'f:/build/stn/main'],
        ['agent', 'Agent名称', 'windows']
      ]

      {
        'stn_build_win'         => {
          :script_path  => 'stn/build_win.groovy',
          :parameters   => [
            ['update',  '版本更新', true],
            ['compile', '版本编译', true],
            ['install', '版本制作', true],
            ['check',   '版本检查', false],
            ['test',    '版本测试', false],
            ['force',   '全量编译', true],

            ['version',         '版本号',     ''],
            ['display_version', '显示版本号', '']
          ]
        },
        'stn_compile_win'       => {
          :script_path  => 'stn/compile_win.groovy',
          :parameters   => [
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['version', '版本号',   '']
          ]
        },
        'stn_compile_module_win'=> {
          :script_path  => 'stn/compile_module_win.groovy',
          :parameters   => [
            ['name',    '模块名称', ''],
            ['cmdline', '编译命令', @cmdline],
            ['force',   '全量编译', true],
            ['retry',   '失败重试', true],
            ['dir',     '编译目录', ''],
            ['version', '版本号',   '']
          ]
        }
      }.each do |k, v|
        v[:parameters] = parameters + v[:parameters]

        pipeline = Jenkins::Pipeline.new k

        if k.include? '_module'
          if k.include? '_compile_'
            pipeline.build v.merge(@args_logrotator_compile_module)
          else
            pipeline.build v.merge(@args_logrotator_module)
          end
        else
          pipeline.build v.merge(@args_logrotator)
        end
      end

      args = {
        :authorization    => ['stnbuild'],
        :logrotator_days  => 3,
        :logrotator_num   => 20,
        :script_path      => 'stn/command.groovy',
        :parameters       => [
          ['home',      '工作目录',   'stn/daily/windows'],
          ['configure', '配置文件',   'installation.xml'],
          ['version',   '版本号',     ''],
          ['reboot',    '重启测试机', false]
        ]
      }

      pipeline = Jenkins::Pipeline.new 'stn_command'
      pipeline.build args.merge(@args_logrotator)
    end
  end

  class Build
    def initialize
      @args_logrotator = {
        :logrotator_days  => 31,
        :logrotator_num   => 150
      }
    end

    def build name = nil
      bn_build name
      stn_build name
    end

    private

    def bn_build name = nil
      name ||= 'main'

      parameters = [
        ['update',  '版本更新', true],
        ['compile', '版本编译', true],
        ['install', '版本制作', true],
        ['check',   '版本检查', true],
        ['test',    '版本测试', true],
        ['force',   '全量编译', true],

        ['version',         '版本号',     ''],
        ['display_version', '显示版本号', ''],
        ['type',            '版本类型',   '']
      ]

      {
        'bn_build_%s_linux' % name  => {
          :authorization=> ['bnbuild'],
          :script_path  => 'bn/build_main.groovy',
          :triggers     => {
            :timer  => {
              :spec => '0 0,13 * * 1-5'
            }
          },
          :parameters   => [
            ['home', '工作目录', '/home/user/build/%s' % name],
            ['agent', 'Agent名称', 'linux']
          ]
        },
        'bn_build_%s_solaris' % name  => {
          :script_path  => 'bn/build_main.groovy',
          :triggers     => {
            :timer  => {
              :spec => '0 0 * * 1-5'
            }
          },
          :parameters   => [
            ['home', '工作目录', '/home/user/build/%s' % name],
            ['agent', 'Agent名称', 'solaris']
          ]
        },
        'bn_build_%s_windows' % name  => {
          :script_path  => 'bn/build_main_win.groovy',
          :triggers     => {
            :timer  => {
              :spec => '0 22 * * 0-4'
            }
          },
          :parameters   => [
            ['home', '工作目录', 'd:/build/%s' % name],
            ['agent', 'Agent名称', 'windows']
          ]
        },
        'bn_build_%s_windows32' % name  => {
          :script_path  => 'bn/build_main.groovy',
          :triggers     => {
            :timer  => {
              :spec => '0 2 * * 1-5'
            }
          },
          :parameters   => [
            ['home', '工作目录', 'e:/build/%s' % name],
            ['agent', 'Agent名称', 'windows']
          ]
        }
      }.each do |k, v|
        v[:parameters] = v[:parameters] + parameters
        v[:concurrent] = false

        pipeline = Jenkins::Pipeline.new k
        pipeline.build v.merge(@args_logrotator)
      end
    end

    def stn_build name = nil
      name ||= 'main'

      parameters = [
        ['update',  '版本更新', true],
        ['compile', '版本编译', true],
        ['install', '版本制作', true],
        ['check',   '版本检查', true],
        ['test',    '版本测试', true],
        ['force',   '全量编译', true],

        ['version',         '版本号',     ''],
        ['display_version', '显示版本号', '']
      ]

      {
        'stn_build_%s_linux' % name  => {
          :authorization=> ['stnbuild'],
          :script_path  => 'stn/build_main.groovy',
          :triggers     => {
            :timer  => {
              :spec => '30 0,16 * * *'
            }
          },
          :parameters   => [
            ['home', '工作目录', '/home/user/build/stn/%s' % name],
            ['agent', 'Agent名称', 'linux']
          ]
        },
        'stn_build_%s_windows' % name  => {
          :script_path  => 'stn/build_main_win.groovy',
          :triggers     => {
            :timer  => {
              :spec => '0 0 * * 1-5'
            }
          },
          :parameters   => [
            ['home', '工作目录', 'f:/build/stn/%s' % name],
            ['agent', 'Agent名称', 'windows']
          ]
        }
      }.each do |k, v|
        v[:parameters] = v[:parameters] + parameters
        v[:concurrent] = false

        pipeline = Jenkins::Pipeline.new k
        pipeline.build v.merge(@args_logrotator)
      end
    end
  end

  class Dashboard
    def initialize
      @args_logrotator = {
        :logrotator_days  => 3,
        :logrotator_num   => 3
      }
    end

    def build
      bn_build
      stn_build
    end

    private

    def bn_build
      parameters = [
        ['list',    '变更列表', ''],
        ['authors', '变更人员', '']
      ]

      [
        ['iptn-1', true, true],
        ['iptn-2', true, true],
        ['iptn-3', true, true],
        ['e2e-1', true, true],
        ['e2e-2', true, true],
        ['e2e-3', true, true],
        ['naf', true, true],
        ['nanjing-1', true, false],
        ['nanjing-2', true, false],
        ['nanjing-3', true, false],
        ['nanjing-4', true, false],
        ['wdm-1', true, false],
        ['wdm-2', false, true],
        ['wdm-3', true, false],
        ['wdm-4', false, true],
        ['wdm-5', false, true]
      ].each do |module_name, java, cpp|
        ['compile', 'test', 'check', 'deploy'].each_with_index do |name, index|
          if java
            args = {
              :parameters => parameters,
              :concurrent => false,
              :script_path=> 'bn/dashboard/%s/%s_%s.groovy' % [module_name, index + 1, name]
            }

            pipeline = Jenkins::Pipeline.new '%s_%s_%s' % [index + 1, module_name, name]
            pipeline.build args.merge(@args_logrotator)
          end

          if cpp
            args = {
              :parameters => parameters,
              :concurrent => false,
              :script_path=> 'bn/dashboard/cpp_%s/%s_%s.groovy' % [module_name, index + 1, name]
            }

            pipeline = Jenkins::Pipeline.new '%s_%s_%s_cpp' % [index + 1, module_name, name]
            pipeline.build args.merge(@args_logrotator)
          end
        end

        if java
          args = {
            :parameters => parameters,
            :concurrent => false,
            :script_path=> 'bn/dashboard/%s_dashboard.groovy' % module_name,
          }

          pipeline = Jenkins::Pipeline.new '%s_dashboard' % module_name
          pipeline.build args.merge(@args_logrotator)
        end

        if cpp
          args = {
            :parameters => parameters,
            :concurrent => false,
            :script_path=> 'bn/dashboard/%s_dashboard_cpp.groovy' % module_name,
          }

          pipeline = Jenkins::Pipeline.new '%s_dashboard_cpp' % module_name
          pipeline.build args.merge(@args_logrotator)
        end
      end

      args = {
        :parameters => [
          ['home',    '工作目录',  '/home/user/build/main'],
          ['agent',   'Agent名称', 'dashboard'],
          ['cmdline', '编译命令',  'mvn deploy -fn -U -T 5 -Djobs=5']
        ],
        :concurrent => false,
        :script_path=> 'bn/dashboard/cron.groovy',
        :triggers   => {
          :timer  => {
            :spec => '0 3 * * *'
          }
        }
      }

      pipeline = Jenkins::Pipeline.new 'dashboard_cron'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :parameters => [],
        :concurrent => false,
        :script_path=> 'bn/dashboard/polling.groovy',
        :triggers   => {
          :scm  => {
            :spec => 'H/10 * * * *'
          }
        }
      }

      pipeline = Jenkins::Pipeline.new 'dashboard_bn_polling'
      pipeline.build args.merge(@args_logrotator)
    end

    def stn_build
      parameters = [
        ['list',    '变更列表', ''],
        ['authors', '变更人员', '']
      ]

      ['compile', 'test', 'check', 'deploy'].each_with_index do |name, index|
        args = {
          :parameters => parameters,
          :concurrent => false,
          :script_path=> 'stn/dashboard/stn/%s_%s.groovy' % [index + 1, name],
        }

        pipeline = Jenkins::Pipeline.new '%s_stn_%s' % [index + 1, name]
        pipeline.build args.merge(@args_logrotator)
      end

      args = {
        :parameters => parameters,
        :concurrent => false,
        :script_path=> 'stn/dashboard/stn_dashboard.groovy',
      }

      pipeline = Jenkins::Pipeline.new 'stn_dashboard'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :parameters => [],
        :concurrent => false,
        :script_path=> 'stn/dashboard/polling.groovy',
        :triggers   => {
          :scm  => {
            :spec => 'H/10 * * * *'
          }
        }
      }

      pipeline = Jenkins::Pipeline.new 'dashboard_stn_polling'
      pipeline.build args.merge(@args_logrotator)
    end
  end

  class Patch
    def initialize
      @bn_init = false
      @stn_init = false

      @args_logrotator = {
        :logrotator_days  => 3,
        :logrotator_num   => 10
      }

      @args_logrotator_module = {
        :logrotator_days  => 3,
        :logrotator_num   => 30
      }
    end

    def bn_build names, osnames = nil
      if not @bn_init
        @bn_init = true

        args = {
          :authorization=> ['bnbuild'],
          :script_path  => 'bn/patch_install.groovy',
          :parameters   => [
            ['os',              'OS名称(windows, windows32, linux, solaris)',   'windows'],
            ['name',            '补丁名称(例如dev/20160801, release/20160606)', ''],
            ['version',         '版本号',       ''],
            ['display_version', '显示版本号',   ''],
            ['sp_next',         '下一个SP补丁', false],
            ['type',            '版本类型',     '']
          ]
        }

        pipeline = Jenkins::Pipeline.new 'bn_patch_install'
        pipeline.build args.merge(@args_logrotator)

        args = {
          :script_path  => 'bn/patch_module.groovy',
          :parameters   => [
            ['os',          'OS名称',   'windows'],
            ['name',        '补丁名称', ''],
            ['module_name', '模块名称', '']
          ]
        }

        pipeline = Jenkins::Pipeline.new 'bn_patch_module'
        pipeline.build args.merge(@args_logrotator_module)

        args = {
          :script_path  => 'bn/patch.groovy',
          :parameters   => [
            ['os',    'OS名称(windows, windows32, linux, solaris)',   'windows'],
            ['name',  '补丁名称(例如dev/20160801, release/20160606)', ''],
          ]
        }

        pipeline = Jenkins::Pipeline.new 'bn_patch'
        pipeline.build args.merge(@args_logrotator_module)
      end

      osnames ||= [:linux, :solaris, :windows, :windows32]

      names.to_array.each do |name|
        osnames.to_array.each do |osname|
          line = [
            'timestamps {',
            '  stage "补丁制作"',
            '  build job: "bn_patch", parameters: [[$class: "StringParameterValue", name: "os", value: "%s"],[$class: "StringParameterValue", name: "name", value: "%s"]]' % [osname.to_s, name],
            '}'
          ]

          args = {
           :concurrent  => false,
           :triggers    => {
              :file => {
                :spec     => 'H/5 * * * *',
                :directory=> File.join('/home/workspace/os', osname.to_s, name, 'build/xml'),
                :files    => '*/*.xml'
              }
            },
           :script      => line.join("\n")
          }

          pipeline = Jenkins::Pipeline.new 'bn_patch_%s_%s' % [File.basename(name), osname]
          pipeline.build args.merge(@args_logrotator)
        end
      end
    end

    def stn_build names
      if not @stn_init
        @stn_init = true

        args = {
          :authorization=> ['stnbuild'],
          :script_path  => 'stn/patch_install.groovy',
          :parameters   => [
            ['name',            '补丁名称(例如dev/20160727_stn, release/20160601_stn)', ''],
            ['version',         '版本号',       ''],
            ['display_version', '显示版本号',   ''],
            ['sp_next',         '下一个SP补丁', false]
          ]
        }

        pipeline = Jenkins::Pipeline.new 'stn_patch_install'
        pipeline.build args.merge(@args_logrotator)

        args = {
          :script_path  => 'stn/patch_module.groovy',
          :parameters   => [
            ['name', '补丁名称', '']
          ]
        }

        pipeline = Jenkins::Pipeline.new 'stn_patch_module'
        pipeline.build args.merge(@args_logrotator_module)

        args = {
          :script_path  => 'stn/patch.groovy',
          :parameters   => [
            ['name', '补丁名称(dev/20160727_stn, release/20160601_stn)', '']
          ]
        }

        pipeline = Jenkins::Pipeline.new 'stn_patch'
        pipeline.build args.merge(@args_logrotator_module)
      end

      names.to_array.each do |name|
        line = [
          'timestamps {',
          '  stage "补丁制作"',
          '  build job: "stn_patch", parameters: [[$class: "StringParameterValue", name: "name", value: "%s"]]' % name,
          '}'
        ]

        args = {
         :concurrent  => false,
         :triggers    => {
            :file => {
              :spec     => 'H/5 * * * *',
              :directory=> File.join('/home/workspace/os/windows_stn', name, 'build/xml'),
              :files    => '*/*.xml'
            }
          },
         :script      => line.join("\n")
        }

        pipeline = Jenkins::Pipeline.new 'stn_patch_%s' % File.basename(name)
        pipeline.build args.merge(@args_logrotator)
      end
    end
  end
end

module Jenkins
  class Tools
    def initialize
      @args_logrotator = {
        :logrotator_days  => 3,
        :logrotator_num   => 10
      }
    end

    def build
      args = {
        :concurrent  => false,
        :triggers    => {
          :file => {
            :spec     => 'H/5 * * * *',
            :directory=> '/home/workspace/auto',
            :files    => 'source/*/*/*.xml'
          }
        },
        :script_path  => 'tools/autopatch.groovy'
      }

      pipeline = Jenkins::Pipeline.new 'autopatch'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :script_path  => 'tools/bn_patch_init.groovy',
        :parameters   => [
            ['name',        '补丁名称(例如dev/20160801, release/20160606)', ''],
            ['version',     '版本号',       ''],
            ['uep_version', 'UEP版本号',    ''],
            ['branch',      '分支名称',     ''],
            ['windows',     'windows系统',  false],
            ['windows32',   'windows32系统',false],
            ['linux',       'linux系统',    false],
            ['solaris',     'solaris系统',  false]
          ]
      }

      pipeline = Jenkins::Pipeline.new 'bn_patch_init'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :script_path  => 'tools/stn_patch_init.groovy',
        :parameters   => [
            ['name',        '补丁名称例如(dev/20160727_stn, release/20160601_stn)', ''],
            ['version',     '版本号',     ''],
            ['uep_version', 'UEP版本号',  ''],
            ['oscp_version','OSCP版本号', ''],
            ['branch',      '分支名称',   '']
          ]
      }

      pipeline = Jenkins::Pipeline.new 'stn_patch_init'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :script_path  => 'tools/scm_change.groovy',
        :triggers     => {
          :timer  => {
            :spec => '0 3 1,16 * *'
          }
        }
      }

      pipeline = Jenkins::Pipeline.new 'scm_change'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :script_path  => 'tools/log_search.groovy',
        :triggers     => {
          :timer  => {
            :spec => '0 3 1 * *'
          }
        }
      }

      pipeline = Jenkins::Pipeline.new 'log_search'
      pipeline.build args.merge(@args_logrotator)

      args = {
        :authorization=> ['bnbuild'],
        :script_path  => 'tools/autotest_update.groovy',
        :triggers     => {
          :timer  => {
            :spec => '0 22 * * *'
          }
        }
      }

      pipeline = Jenkins::Pipeline.new 'autotest_update'
      pipeline.build args.merge(@args_logrotator)
    end
  end
end

if $0 == __FILE__
  File.mkdir 'jobs'

  Dir.chdir 'jobs' do
    build = Jenkins::Base.new
    build.build

    build = Jenkins::Build.new
    build.build

    build = Jenkins::Dashboard.new
    build.build

    build = Jenkins::Tools.new
    build.build

    build = Jenkins::Patch.new

    # IPTN工程版本

    # -- 2014 --
    build.bn_build ['release/20140630', 'release/20141208'], [:linux, :solaris, :windows32]

    # -- 2015 --
    build.bn_build ['release/20150601', 'release/20151207']

    # -- 2016 --
    build.bn_build ['release/20160606']

    # IPTN开发版本
    build.bn_build ['dev/20160314', 'dev/20160417_wdm', 'dev/20160524_MTN', 'dev/20160611', 'dev/20160704'], [:windows, :windows32]
    build.bn_build ['dev/20160627_MTN'], [:windows]

    build.bn_build ['dev/20160801', 'dev/20160822']

    # STN工程版本
    build.stn_build ['release/20160601_stn']

    # STN开发版本
    build.stn_build ['dev/20160727_stn', 'dev/20160824_stn']
  end
end
