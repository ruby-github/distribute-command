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