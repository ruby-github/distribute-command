module POM
  module_function

  def artifactid_paths dirname = nil
    dirname ||= '.'
    map = {}

    if File.file? File.join(dirname, 'pom.xml')
      Dir.chdir dirname do
        begin
          doc = REXML::Document.file 'pom.xml'

          REXML::XPath.each doc, '/project/artifactId' do |e|
            if OS::windows?
              map[e.text.to_s.strip.gsub('${prefix}', '')] = Dir.pwd
            else
              map[e.text.to_s.strip.gsub('${prefix}', 'lib')] = Dir.pwd
            end

            break
          end

          REXML::XPath.each doc, '//modules/module' do |e|
            map.deep_merge! artifactid_paths(e.text.to_s.strip)
          end
        rescue
        end
      end
    end

    map
  end

  def dirname path
    path = File.normalize path

    if File.file? path
      dirname = File.dirname path
    else
      dirname = path
    end

    size = dirname.split('/').size

    size.times do |i|
      if File.file? File.join(dirname, 'pom.xml')
        return dirname
      end

      dirname = File.dirname dirname
    end

    nil
  end

  def modules path, include_home = false
    path = File.normalize path

    if not File.file? File.join(path, 'pom.xml')
      return []
    end

    module_names = []

    begin
      doc = REXML::Document.file File.join(path, 'pom.xml')

      REXML::XPath.each doc, '//modules/module' do |e|
        module_name = e.text.to_s.nil

        if not module_name.nil?
          module_names += modules File.join(path, module_name), true
        end
      end
    rescue
    end

    if module_names.empty? or include_home
      module_names << path
    end

    module_names.uniq
  end

  def scm_info file, expand = true
    info = SCM::info file

    if expand
      if info.nil?
        dir = dirname file

        if not dir.nil?
          info = SCM::info dir
        end
      end

      if info.nil?
        scm_home = SCM::home

        if not scm_home.nil?
          info = SCM::info scm_home
        end
      end
    end

    if not info.nil?
      author = info[:author]
      mail = info[:mail]

      if author.to_s.nil.nil?
        if mail.to_s = ~ /@/
          author = $`
        else
          author = mail
        end
      end

      info[:author] = author
      info[:mail] = mail
    end

    info
  end
end

module POM
  module_function

  def cleanup xpath
    hash = {}
    docs = {}

    File.glob(xpath).each do |file|
      if not File.file? file
        next
      end

      if File.basename(file) != 'pom.xml'
        next
      end

      groupid = nil
      artifactid = nil

      begin
        doc = REXML::Document.file file
      rescue
        Util::Logger::execption $!

        next
      end

      REXML::XPath.each doc, '/project/groupId' do |e|
        groupid = e.text.to_s.nil

        next
      end

      REXML::XPath.each doc, '/project/artifactId' do |e|
        artifactid = e.text.to_s.nil

        next
      end

      dependencies = []

      REXML::XPath.each doc, '/project/dependencies/dependency' do |e|
        dependency_groupid = nil
        dependency_artifactid = nil

        REXML::XPath.each e, 'groupId' do |element|
          dependency_groupid = element.text.to_s.nil

          next
        end

        REXML::XPath.each e, 'artifactId' do |element|
          dependency_artifactid = element.text.to_s.nil

          next
        end

        dependencies << [dependency_groupid, dependency_artifactid]
      end

      hash[[groupid, artifactid]] = dependencies
      docs[doc] = file
    end

    docs.each do |doc, file|
      Util::Logger::puts file

      REXML::XPath.each doc, '/project/modules' do |e|
        modules = []

        REXML::XPath.each e, 'module' do |element|
          path = element.text.to_s.nil

          if not path.nil?
            modules << path
          end
        end

        e.children.each do |element|
          e.delete element
        end

        modules.sort!
        modules.uniq!

        modules.each do |path|
          element = REXML::Element.new 'module'
          element.text = path

          e << element
        end
      end

      REXML::XPath.each doc, '/project/dependencies' do |e|
        dependencies = []

        REXML::XPath.each e, 'dependency' do |dependency|
          groupid = nil
          artifactid = nil
          version = nil
          type = nil
          scope = nil

          REXML::XPath.each dependency, 'groupId' do |element|
            groupid = element.text.to_s.nil

            next
          end

          REXML::XPath.each dependency, 'artifactId' do |element|
            artifactid = element.text.to_s.nil

            next
          end

          REXML::XPath.each dependency, 'version' do |element|
            version = element.text.to_s.nil

            next
          end

          REXML::XPath.each dependency, 'type' do |element|
            type = element.text.to_s.nil

            next
          end

          REXML::XPath.each dependency, 'scope' do |element|
            scope = element.text.to_s.nil

            next
          end

          dependencies << [groupid, artifactid, version, type, scope]
        end

        e.children.each do |dependency|
          e.delete dependency
        end

        dependencies.sort_by! {|x| x.join ','}
        dependencies.uniq!

        depends = []

        dependencies.each do |dependency_info|
          found = false

          dependencies.each do |x|
            if dependency_info == x
              next
            end

            if dependency_include? [dependency_info[0], dependency_info[1]], [x[0], x[1]], hash
              found = true

              break
            end
          end

          if not found
            depends << dependency_info
          end
        end

        depends.each_with_index do |x, index|
          groupid, artifactid, version, type, scope = x

          if index > 0
            e.add_text "\n\n"
          end

          dependency = REXML::Element.new 'dependency'

          element = REXML::Element.new 'groupId'
          element.text = groupid

          dependency << element

          element = REXML::Element.new 'artifactId'
          element.text = artifactid

          dependency << element

          if not version.nil?
            element = REXML::Element.new 'version'
            element.text = version

            dependency << element
          end

          if not type.nil?
            element = REXML::Element.new 'type'
            element.text = type

            dependency << element
          end

          if not scope.nil?
            element = REXML::Element.new 'scope'
            element.text = scope

            dependency << element
          end

          e << dependency
        end
      end

      doc.to_file file
    end

    true
  end

  def dependency_include? artifact_info, dependency, hash = nil
    hash ||= {}

    if artifact_info == dependency
      true
    else
      if hash.has_key? dependency
        found = false

        hash[dependency].each do |dependency_info|
          if dependency_include? artifact_info, dependency_info, hash
            found = true

            break
          end
        end

        found
      else
        false
      end
    end
  end
end