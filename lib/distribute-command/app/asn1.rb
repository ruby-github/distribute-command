require 'stringio'
require 'yaml'

COMPARE_HTML_FILE = 'compare.html'
ASN1_IGNORE_YAML_FILE = 'asn1_ignore.yml'
ASN1_SORT_YAML_FILE = 'asn1_sort.yml'

module Zip
  autoload :File, 'zip'
end

module ASN1
  class Any
    attr_accessor :classname, :path, :ignore, :match
    attr_accessor :value

    def == other_any
      if @ignore
        true
      else
        if other_any.nil?
          set_state nil, nil

          false
        else
          if @classname != other_any.classname
            set_state false, nil
            other_any.set_state false, nil

            false
          else
            if @value == other_any.value
              set_state true, nil
              other_any.set_state true, nil

              true
            else
              set_state false, nil
              other_any.set_state false, nil

              false
            end
          end
        end
      end
    end

    def set_state match, ignore
      @match = match
      @ignore = ignore
    end

    def set_ignore path, condition = nil, force = false
      if force
        @ignore = true
      else
        if not @path.nil?
          if @path.to_s.gsub(/\[\d+\]/, '') == path
            if condition.nil?
              @ignore = true
            else
              @ignore = true ###
            end
          end
        end
      end
    end

    def set_sort_keys sort_keys
      if @value.respond_to? :set_sort_keys
        @value.set_sort_keys sort_keys
      end
    end

    def get key
      if @value.is_a? Sequence
        @value.get key
      else
        nil
      end
    end

    def to_string
      @value.to_string
    end

    def to_html
      if @value.respond_to? :to_html
        str = @value.to_html
      else
        str = @value.to_string
      end

      if @ignore
        '<font style = "background:gray">%s</font>' % str
      else
        if @match.nil?
          '<font style = "background:#00ffff">%s</font>' % str
        else
          if @match
            str
          else
            '<font style = "background:red">%s</font>' % str
          end
        end
      end
    end
  end

  class Choice
    attr_accessor :classname, :path, :ignore
    attr_accessor :klass, :name, :value

    def == other_choice
      if @ignore
        true
      else
        if other_choice.nil?
          set_state nil, nil

          false
        else
          if @classname != other_choice.classname
            set_state false, nil
            other_choice.set_state false, nil

            false
          else
            if @name != other_choice.name
              set_state false, nil
              other_choice.set_state false, nil

              false
            else
              @value == other_choice.value
            end
          end
        end
      end
    end

    def set_state match, ignore
      @value.set_state match, ignore
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s.gsub(/\[\d+\]/, '') == path
        if condition.nil?
          force = true
        else
          force = true ###
        end
      end

      if force
        @ignore = true
      end

      @value.set_ignore path, condition, force
    end

    def set_sort_keys sort_keys
      @value.set_sort_keys sort_keys
    end

    def to_string
      lines = [
        '{ -- CHOICE -- %s' % @classname
      ]

      ('%s = %s' % [@name.to_string, @value.to_string]).each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << '}'
      lines.join "\n"
    end

    def to_html
      lines = [
        '{ -- CHOICE -- <font color = "white">%s</font>' % @classname
      ]

      ('%s = %s' % [@name.to_string, @value.to_html]).each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << '}'
      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift

      classname = nil

      if line =~ /--\s*CHOICE\s*--/
        classname = $'.strip
      end

      lines.pop

      depth = 0

      name = nil
      value = nil
      asn = nil

      asn_lines = []

      lines.each do |line|
        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            asn_lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end

            if $` =~ /\s*=/
              name = $`.strip
            end
          end

          depth += 1
        end

        if depth > 0
          asn_lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              value = asn.load asn_lines.join("\n")
            end
          end
        end
      end

      {
        :type       => :choice,
        :classname  => classname,
        :name       => name,
        :value      => value
      }
    end
  end

  class Sequence < Hash
    attr_accessor :classname, :path, :ignore

    def == other_sequence
      if @ignore
        true
      else
        if other_sequence.nil?
          set_state nil, nil

          false
        else
          if @classname != other_sequence.classname
            set_state false, nil
            other_sequence.set_state false, nil

            false
          else
            status = true

            each do |k, v|
              if v != other_sequence[k]
                status = false
              end
            end

            other_sequence.each do |k, v|
              if has_key? k
                next
              end

              v.set_state nil, nil
              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      each do |k, v|
        v.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s.gsub(/\[\d+\]/, '') == path
        if condition.nil?
          force = true
        else
          force = true ###
        end
      end

      if force
        @ignore = true
      end

      each do |k, v|
        v.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
      each do |k, v|
        v.set_sort_keys sort_keys
      end
    end

    def get key
      name, key = key.split '.', 2

      if has_key? name
        if key.nil?
          self[name]
        else
          if self[name].respond_to? :get
            self[name].get key
          else
            nil
          end
        end
      else
        nil
      end
    end

    def to_string
      lines = []

      each do |k, v|
        list = []

        ('%s = %s' % [k.to_string, v.to_string]).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE -- %s' % @classname
      lines << '}'
      lines.join "\n"
    end

    def to_html
      lines = []

      each do |k, v|
        list = []

        ('%s = %s' % [k.to_string, v.to_html]).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE -- <font color = "white">%s</font>' % @classname
      lines << '}'
      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift

      classname = nil

      if line =~ /--\s*SEQUENCE\s*--/
        classname = $'.strip
      end

      lines.pop

      hash = {}
      depth = 0

      asn_lines = []
      asn = nil
      asn_name = nil

      lines.each do |line|
        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            asn_lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end

            if $` =~ /\s*=/
              asn_name = $`.strip
            end
          end

          depth += 1
        end

        if depth > 0
          asn_lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              hash[asn_name] = asn.load asn_lines.join("\n")
            end
          end
        end

        if depth == 0
          if line =~ /\s*=\s*/
            hash[$`.strip] = $'.strip.chomp ','
          end
        end
      end

      {
        :type       => :sequence,
        :classname  => classname,
        :hash       => hash
      }
    end
  end

  class SequenceList < Array
    attr_accessor :classname, :path, :ignore, :sort_key

    def == other_sequence_list
      if @ignore
        true
      else
        if other_sequence_list.nil?
          set_state nil, nil

          false
        else
          if @classname != other_sequence_list.classname
            set_state false, nil
            other_sequence_list.set_state false, nil

            false
          else
            if not empty? and @sort_key and not first.get(@sort_key).nil?
              is_numeric = false

              klass = Java.import first.get(@sort_key).classname

              if klass.number?
                is_numeric = true
              else
                if not klass.java_variables['value'].nil? and klass.java_variables['value'].number?
                  is_numeric = true
                end
              end

              map = {}

              each do |sequence|
                if is_numeric
                  value = sequence.get(@sort_key).to_s.to_f
                else
                  value = sequence.get(@sort_key).to_string
                end

                map[value] ||= []
                map[value] << sequence
              end

              other_map = {}

              other_sequence_list.each do |sequence|
                if is_numeric
                  value = sequence.get(@sort_key).to_s.to_f
                else
                  value = sequence.get(@sort_key).to_string
                end

                other_map[value] ||= []
                other_map[value] << sequence
              end

              self.clear
              other_sequence_list.clear

              map.keys.sort.each do |k|
                list = map[k]
                other_list = other_map[k]

                if other_list.nil?
                  next
                end

                size = [list.size, other_list.size].min

                size.times do
                  self << list.shift
                  other_sequence_list << other_list.shift
                end

                if list.empty?
                  map.delete k
                end

                if other_list.empty?
                  other_map.delete k
                end
              end

              map.keys.sort.each do |k|
                map[k].each do |sequence|
                  self << sequence
                end
              end

              other_map.keys.sort.each do |k|
                other_map[k].each do |sequence|
                  other_sequence_list << sequence
                end
              end
            end

            status = true

            each_with_index do |sequence, index|
              if sequence != other_sequence_list[index]
                status = false
              end
            end

            if size < other_sequence_list.size
              other_sequence_list[size..-1].each do |sequence|
                sequence.set_state nil, nil
              end

              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      each do |sequence|
        sequence.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s.gsub(/\[\d+\]/, '') == path
        if condition.nil?
          force = true
        else
          force = true ###
        end
      end

      if force
        @ignore = true
      end

      each do |sequence|
        sequence.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
      if not empty?
        sequence_classname = first.classname

        sort_keys.each do |classname, path|
          if sequence_classname == classname
            @sort_key = path

            break
          end
        end
      end

      each do |sequence|
        sequence.set_sort_keys sort_keys
      end
    end

    def to_string
      lines = []

      each do |sequence|
        if sequence.kind_of? Sequence
          prefix = INDENT
        else
          prefix = ''
        end

        list = []

        (prefix + sequence.to_string).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE OF -- %s' % @classname
      lines << '}'
      lines.join "\n"
    end

    def to_html
      lines = []

      each do |sequence|
        if sequence.kind_of? Sequence
          prefix = INDENT
        else
          prefix = ''
        end

        list = []

        (prefix + sequence.to_html).each_line do |line|
          list << INDENT + line.rstrip
        end

        lines << list.join("\n")
      end

      if not lines.empty?
        lines = [
          lines.join(",\n")
        ]
      end

      lines.unshift '{ -- SEQUENCE OF -- <font color = "white">%s</font>' % @classname
      lines << '}'
      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift

      classname = nil

      if line =~ /--\s*SEQUENCE\s*OF\s*--/
        classname = $'.strip
      end

      lines.pop

      array = []
      depth = 0

      asn_lines = []
      asn = nil

      lines.each do |line|
        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            asn_lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end
          end

          depth += 1
        end

        if depth > 0
          asn_lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              array << asn.load(asn_lines.join("\n"))
            end
          end
        end
      end

      {
        :type       => :sequence_of,
        :classname  => classname,
        :array      => array
      }
    end
  end

  class LineSequenceList < SequenceList
    def to_string
      lines = []

      each do |any|
        list = []

        any.to_string.each_line do |line|
          list << line.rstrip
        end

        lines << list.join("\n")
      end

      lines.join "\n"
    end

    def to_html
      lines = []

      each do |any|
        list = []

        any.to_html.each_line do |line|
          list << line.rstrip
        end

        lines << list.join("\n")
      end

      lines.join "\n"
    end

    def load str
      str.lines.map { |line| line.rstrip }
    end
  end

  class CliSequenceList < LineSequenceList
    def to_string
      lines = ['[']

      super.each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << ']'

      lines.join "\n"
    end

    def to_html
      lines = ['[']

      super.each_line do |line|
        lines << INDENT + line.rstrip
      end

      lines << ']'

      lines.join "\n"
    end

    def load str
      lines = str.lines.map { |line| line.rstrip }
      line = lines.shift
      lines.pop

      lines
    end
  end

  class Asn1
    attr_reader :classname, :opt

    @@tags = {}

    # opt
    #     :name
    #     :ne
    #     :cmdcode
    #     :time
    #     :data
    #     :file
    #     :lines
    def initialize opt
      @opt = opt
      @data = (@opt[:data].join(' ').split(/\s/) - ['']).map {|x| x.to_i 16}
      @classname = get_classname

      if @opt[:name].nil?
        @opt[:name] = @opt[:ne]
      end

      @asn1 = nil
      @java_asn1 = nil

      @match = nil
      @ignore = nil
      @ignore_paths = nil
      @sort_keys = nil
    end

    def validate?
      if @classname.nil?
        Util::Logger::error 'not found classname'

        @asn1 = line_sequence @data
      else
        @java_asn1 = decode

        if @java_asn1.nil?
          Util::Logger::error 'not parse asn1 data - %s' % @classname

          @asn1 = line_sequence @data
        end
      end

      true
    end

    def asn1
      if @asn1.nil? and not @java_asn1.nil?
        @asn1 = to_ruby @java_asn1

        if not @match.nil? or not @ignore.nil?
          set_state @match, @ignore
        end

        if not @ignore_paths.nil?
          set_ignore @ignore_paths
        end

        if not @sort_keys.nil?
          set_sort_keys @sort_keys
        end
      end

      @asn1
    end

    def == other_asn1
      if other_asn1.nil?
        set_state nil, nil

        false
      else
        if @classname != other_asn1.classname
          set_state false, nil
          other_asn1.set_state false, nil

          false
        else
          asn1 == other_asn1.asn1
        end
      end
    end

    def set_state match, ignore
      if @asn1.nil?
        @match = match
        @ignore = ignore
      else
        @asn1.set_state match, ignore

        @match = nil
        @ignore = nil
      end
    end

    def set_ignore paths_info
      if @asn1.nil?
        @ignore_paths = paths_info
      else
        paths_info.each do |path, condition|
          @asn1.set_ignore path, condition
        end

        @ignore_paths = nil
      end
    end

    def set_sort_keys sort_keys
      if @asn1.nil?
        @sort_keys = sort_keys
      else
        @asn1.set_sort_keys sort_keys

        @sort_keys = nil
      end
    end

    def ne
      @opt[:ne] || @opt[:name]
    end

    def cmdcode
      @opt[:cmdcode] || @classname
    end

    def to_string
      asn1.to_string
    end

    def to_html
      if asn1.respond_to? :to_html
        asn1.to_html
      else
        asn1.to_string
      end
    end

    def self.load str
      depth = 0
      lines = []

      info = nil
      asn = nil

      str.lines.each do |line|
        line.rstrip!

        if line.empty?
          next
        end

        if line =~ /\s*{\s*--\s*(SEQUENCE\s+OF|SEQUENCE|CHOICE)\s*--/
          if depth == 0
            lines = []

            case $1
            when 'CHOICE'
              asn = Choice.new
            when 'SEQUENCE'
              asn = Sequence.new
            else
              asn = SequenceList.new
            end
          end

          depth += 1
        end

        if depth > 0
          lines << line
        end

        if line.strip.start_with? '}'
          depth -= 1

          if depth == 0
            if not asn.nil?
              info = asn.load lines.join("\n")
            end
          end
        end
      end

      info
    end

    def self.import paths, clear = false
      if clear
        @@tags = {}
      end

      paths.to_array.each do |path|
        path = File.normalize path

        if File.basename(path) == 'asn.jar'
          Java.include path
        end
      end

      paths.to_array.each do |path|
        path = File.normalize path

        if File.basename(path) == 'asn.jar'
          next
        end

        Java.include path

        Zip::File.open(path) do |zipfile|
          zipfile.entries.each do |name|
            name = name.to_s

            if File.extname(name) != '.class'
              next
            end

            name = File.basename name.gsub('/', '.'), '.class'

            begin
              tag = Java.import(name).new.getT.to_i

              if tag > 0
                @@tags[tag] = name
              end
            rescue
            end
          end
        end
      end
    end

    private

    def get_classname
      classname = nil

      if @data.size > 2
        tag = @data[0] * 256 + @data[1]
        classname = @@tags[tag]
      end

      if not @opt[:cmdcode].nil?
        if not $asn1_cmdcode.nil?
          if $asn1_cmdcode.has_key? @opt[:cmdcode]
            classname = $asn1_cmdcode[@opt[:cmdcode]]
          end
        end
      end

      classname
    end

    def decode
      java_asn1 = nil

      begin
        decoder = Java.import('com.ibm.asn1.ASN1TlvDecoder').new @data

        java_asn1 = Java.import(@classname).new
        java_asn1.qxdecode decoder
      rescue
        Util::Logger::exception $!

        #java_asn1 = nil
      end

      java_asn1
    end

    def to_ruby asn1, klass = nil, path = nil
      if asn1.nil?
        any = Any.new
        any.path = path

        if klass.is_a? Rjb::Rjb_JavaClass
          any.classname = klass.name
        end

        return any
      end

      klass ||= asn1.klass

      if klass.asn1_variables.empty?
        if Java.import('java.util.List').isInstance asn1
          # SequenceList

          sequence_list = SequenceList.new
          sequence_list.classname = klass.name
          sequence_list.path = path

          _klass = nil
          asn1.size.times do |i|
            _asn1 = asn1.get i

            if _asn1
              _klass = _asn1.klass
              sequence = to_ruby _asn1, _klass, '%s[%s]' % [sequence_list.path, i]
              sequence_list << sequence
            else
              sequence = Sequence.new
              sequence.classname = nil
              sequence.path = '%s[%s]' % [sequence_list.path, i]

              sequence_list << sequence
            end
          end

          sequence_list
        else
          # Any

          any = Any.new
          any.classname = klass.name
          any.path = path

          if asn1.is_a? Rjb::Rjb_JavaProxy
            begin
              any.value = asn1.to_string
            rescue
              any.value = nil
            end
          else
            any.value = asn1
          end

          any
        end
      else
        if klass.asn1_variables['choiceId'].class.to_s == 'Rjb::Int'
          # Choice

          choice = Choice.new
          choice.classname = klass.name
          choice.path = path

          if choice.path.nil?
            choice_path = ''
          else
            choice_path = choice.path + '.'
          end

          klass.java_constants.each do |name, _klass|
            if asn1.get_field(name).to_s == asn1.choiceId.to_s
              choice_cid = name

              klass.java_variables.each do |name, _klass|
                if name.downcase + '_cid' == choice_cid.downcase
                  choice.klass = _klass
                  choice.name = name
                  choice.value = to_ruby asn1.get_field(choice.name), choice.klass, choice_path + choice.name

                  break
                end
              end

              break
            end
          end

          choice
        else
          # Sequence

          sequence = Sequence.new
          sequence.classname = klass.name
          sequence.path = path

          if sequence.path.nil?
            sequence_path = ''
          else
            sequence_path = sequence.path + '.'
          end

          klass.asn1_variables.each do |name, _klass|
            sequence[name] = to_ruby asn1.get_field(name), _klass, sequence_path + name
          end

          sequence
        end
      end
    end

    def line_sequence lines
      cur_lines = []

      line = []
      lines.each_with_index do |x, i|
        if i % 10 == 0
          if not line.empty?
            cur_lines << line.join(' ')
          end

          line = []
        end

        line << x.to_s(16).rjust(2, '0')
      end

      if not line.empty?
        cur_lines << line.join(' ')
      end

      asn1 = LineSequenceList.new

      cur_lines.each do |line|
        any = Any.new
        any.value = line.to_s.strip

        asn1 << any
      end

      asn1
    end
  end

  class Cli < Asn1
    # opt
    #     :name
    #     :ne
    #     :classname
    #     :cmdcode
    #     :time
    #     :data
    #     :file
    #     :lines
    def initialize opt
      @opt = opt
      @data = @opt[:data]
      @classname = @opt[:classname] || 'commandline'

      if @opt[:name].nil?
        @opt[:name] = @opt[:ne]
      end
    end

    def validate?
      @asn1 = to_ruby @data

      true
    end

    def set_sort_keys sort_keys
      nil
    end

    def self.load str
      depth = 0
      lines = []

      info = nil
      asn = nil

      str.lines.each do |line|
        line.rstrip!

        if line.empty?
          next
        end

        if line.strip == '['
          if depth == 0
            lines = []

            asn = CliSequenceList.new
          end

          depth += 1
        end

        if depth > 0
          lines << line
        end

        if line.strip == ']'
          depth -= 1

          if depth == 0
            if not asn.nil?
              info = asn.load lines.join("\n")
            end
          end
        end
      end

      info
    end

    private

    def to_ruby lines
      asn1 = CliSequenceList.new

      lines.each do |line|
        any = Any.new

        if line.is_a? Array
          any.value = line.first.to_s
        else
          any.value = line.to_s.strip
        end

        asn1 << any
      end

      asn1
    end
  end
end

module ASN1
  # xml
  # 1) get
  #
  #    <rpc xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  #      <get>
  #        <filter type="subtree">
  #          ....
  #        </filter>
  #      </get>
  #
  #      <get-config>
  #        <filter type="subtree">
  #          ....
  #        </filter>
  #      </get-config>
  #
  #      <get-next xmlns="http://www.zte.com.cn/zxr10/netconf/protocol/ns">
  #        <filter type="subtree">
  #          ....
  #        </filter>
  #      </get-next>
  #    </rpc>
  #
  # 2) set
  #
  #    <rpc xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  #      <edit-config>
  #        <config>
  #          ....
  #        </config>
  #      </edit-config>
  #    </rpc>
  #
  # 3) action
  #
  #    <rpc xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  #      <action xmlns="http://www.zte.com.cn/zxr10/netconf/protocol/ns">
  #        <object>
  #          ...
  #        </object>
  #      </action>
  #    </rpc>
  #
  class XML < Asn1
    # opt
    #     :name
    #     :ne
    #     :cmdcode
    #     :time
    #     :data
    #     :file
    #     :lines
    def initialize opt
      @opt = opt
      @data = nil
      @classname = get_classname

      if @opt[:name].nil?
        @opt[:name] = @opt[:ne]
      end

      @hash_asn1 = nil
      @asn1 = nil

      @match = nil
      @ignore = nil
      @ignore_paths = nil
      @sort_keys = nil
    end

    def validate?
      if not @data.nil?
        @hash_asn1 = @data.to_hash
      end

      true
    end

    def asn1
      if @asn1.nil? and not @hash_asn1.nil?
        @asn1 = to_ruby File.basename(@classname), @hash_asn1

        if not @match.nil? or not @ignore.nil?
          set_state @match, @ignore
        end

        if not @ignore_paths.nil?
          set_ignore @ignore_paths
        end

        if not @sort_keys.nil?
          set_sort_keys @sort_keys
        end
      end

      @asn1
    end

    def == other_asn1
      if other_asn1.nil?
        set_state nil, nil

        false
      else
        if @classname != other_asn1.classname
          set_state false, nil
          other_asn1.set_state false, nil

          false
        else
          asn1 == other_asn1.asn1
        end
      end
    end

    def set_state match, ignore
      if @asn1.nil?
        @match = match
        @ignore = ignore
      else
        @asn1.set_state match, ignore

        @match = nil
        @ignore = nil
      end
    end

    def set_ignore paths_info
      if @asn1.nil?
        @ignore_paths = paths_info
      else
        paths_info.each do |path, condition|
          @asn1.set_ignore path, condition
        end

        @ignore_paths = nil
      end
    end

    def set_sort_keys sort_keys
      if @asn1.nil?
        @sort_keys = sort_keys
      else
        @asn1.set_sort_keys sort_keys

        @sort_keys = nil
      end
    end

    def to_string
      asn1.to_string
    end

    def to_html
      if asn1.respond_to? :to_html
        asn1.to_html
      else
        asn1.to_string
      end
    end

    private

    def get_classname
      classname = nil

      if @opt[:data].size > 6
        begin
          doc = REXML::Document.new @opt[:data].join("\n")

          REXML::XPath.each doc, '/rpc/*/config | /rpc/*/filter | /rpc/*/object' do |e|
            e.each_element do |element|
              @data = element

              break
            end

            break
          end
        rescue
        end
      end

      if not @data.nil?
        classname = '%s/%s' % [@data.attributes['xmlns'], @data.name]
      end

      classname
    end

    def to_ruby name, hash, path = nil
      xml_element = XMLElement.new name

      if path.nil?
        xml_element.path = name
      else
        xml_element.path = '%s.%s' % [path, name]
      end

      if not hash[:elements].nil? and not hash[:elements].empty?
        hash[:elements].each do |k, v|
          xml_element_list = XMLElementList.new k
          xml_element_list.path = '%s.%s' % [xml_element.path, k]

          v.each do |x|
            xml_element_list << to_ruby(k, x, xml_element.path)
          end

          xml_element.elements[k] = xml_element_list
        end
      end

      if not hash[:attributes].nil? and not hash[:attributes].empty?
        xml_element.attributes = XMLAttributes.new
        xml_element.attributes.path = xml_element.path

        hash[:attributes].each do |k, v|
          xml_element.attributes[k] = XMLText.new v
          xml_element.attributes[k].path = '%s.%s' % [xml_element.path, k]
        end
      end

      if not hash[:text].nil?
        xml_element.text = XMLText.new hash[:text]
        xml_element.text.path = xml_element.path
      end

      xml_element
    end
  end

  class XMLElement
    attr_reader :name
    attr_accessor :elements, :attributes, :text
    attr_accessor :path, :ignore, :match

    def initialize name
      @name = name

      @elements = {}
      @attributes = nil
      @text = nil
    end

    def == other_element
      if @ignore
        true
      else
        if other_element.nil?
          set_state nil, nil

          false
        else
          if @name != other_element.name
            set_state false, nil
            other_element.set_state false, nil

            false
          else
            status = true

            @elements.each do |k, v|
              if v != other_element.elements[k]
                status = false
              end
            end

            other_element.elements.each do |k, v|
              if @elements.has_key? k
                next
              end

              v.set_state nil, nil
              status = false
            end

            if @attributes != other_element.attributes
              status = false
            end

            if @text != other_element.text
              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      @match = match
      @ignore = ignore
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s == path
        force = true
      end

      if force
        @ignore = true
      end

      @elements.each do |k, v|
        v.set_ignore path, condition, force
      end

      if not @attributes.nil?
        @attributes.set_ignore path, condition, force
      end

      if not @text.nil?
        @text.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
    end

    def to_string
      lines = []

      str = @name

      if not @attributes.nil?
        str += ' ' + @attributes.to_string
      end

      if @elements.empty?
        lines << '<%s>%s</%s>' % [str, @text.to_string, @name]
      else
        lines << '<%s>' % str

        @elements.keys.sort.each do |k|
          @elements[k].to_string.each_line do |line|
            lines << (INDENT + line).rstrip
          end
        end

        lines << '</%s>' % @name
      end

      lines.join "\n"
    end

    def to_html
      lines = []

      str = @name

      if not @attributes.nil?
        str += ' ' + @attributes.to_html
      end

      if @elements.empty? and not @text.nil?
        lines << '<'.escapes + str + '>'.escapes + @text.to_html + '</'.escapes + @name + '>'.escapes
      else
        lines << '<'.escapes + str + '>'.escapes

        @elements.keys.sort.each do |k|
          @elements[k].to_html.each_line do |line|
            lines << (INDENT + line).rstrip
          end
        end

        lines << '</'.escapes + @name + '>'.escapes
      end

      lines.join "\n"
    end

    def get key
      name, key = key.split '.', 2

      if name == @name
        if key.nil?
          if @text.nil?
            return to_string
          else
            return @text.value
          end
        end

        if not @attributes.nil?
          @attributes.each do |k, v|
            if key == k
              return v
            end
          end
        end

        @elements.each do |k, v|
          val = v.get '%s.%s' % [v.name, key]

          if not val.nil?
            return val
          end
        end
      end

      nil
    end
  end

  class XMLElementList < Array
    attr_reader :name
    attr_accessor :path, :ignore, :match, :sort_key

    def initialize name
      @name = name
    end

    def == other_element_list
      if @ignore
        true
      else
        if other_element_list.nil?
          set_state nil, nil

          false
        else
          if @name != other_element_list.name
            set_state false, nil
            other_element_list.set_state false, nil

            false
          else
            if not empty? and not @sort_key.nil?
              # map = {}
              #
              # each do |element|
              #   if @sort_key.split('.').first != element.name
              #     next
              #   end
              #
              #   element.elements.each do |k, v|
              #     value = v.get @sort_key
              #
              #     map[k] ||= []
              #     map[k][value] ||= []
              #     map[k][value] << v
              #   end
              # end
              #
              # other_map = {}
              #
              # other_element_list.each do |element|
              #   element.elements.each do |k, v|
              #     value = v.get @sort_key
              #
              #     other_map[k] ||= []
              #     other_map[k][value] ||= []
              #     other_map[k][value] << v
              #   end
              # end
              #
              # map.keys.sort.each do |k|
              #   list = map[k]
              #   other_list = other_map[k]
              #
              #   if other_list.nil?
              #     next
              #   end
              #
              #   size = [list.size, other_list.size].min
              #
              #   size.times do
              #     self << list.shift
              #     other_element_list << other_list.shift
              #   end
              #
              #   if list.empty?
              #     map.delete k
              #   end
              #
              #   if other_list.empty?
              #     other_map.delete k
              #   end
              # end
              #
              # map.keys.sort.each do |k|
              #   map[k].each do |element|
              #     self << element
              #   end
              # end
              #
              # other_map.keys.sort.each do |k|
              #   other_map[k].each do |element|
              #     other_element_list << element
              #   end
              # end
            end

            status = true

            each_with_index do |element, index|
              if element != other_element_list[index]
                status = false
              end
            end

            if size < other_element_list.size
              other_element_list[size..-1].each do |element|
                element.set_state nil, nil
              end

              status = false
            end

            status
          end
        end
      end
    end

    def set_state match, ignore
      each do |element|
        element.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s == path
        force = true
      end

      if force
        @ignore = true
      end

      each do |element|
        element.set_ignore path, condition, force
      end
    end

    def set_sort_keys sort_keys
    end

    def to_string
      lines = []

      each do |element|
        element.to_string.each_line do |line|
          lines << line.rstrip
        end
      end

      lines.join "\n"
    end

    def to_html
      lines = []

      each do |element|
        element.to_html.each_line do |line|
          lines << line.rstrip
        end
      end

      lines.join "\n"
    end

    def get key
      name, key = key.split '.', 2

      if name == @name
        if key.nil?
          return to_string
        else
          each do |element|
            return element.get(key)
          end
        end
      end

      nil
    end
  end

  class XMLAttributes < Hash
    attr_accessor :path, :ignore

    def initialize
    end

    def == other_attributes
      if @ignore
        true
      else
        if other_attributes.nil?
          set_state nil, nil

          false
        else
          status = true

          each do |k, v|
            if v != other_attributes[k]
              status = false
            end
          end

          other_attributes.each do |k, v|
            if has_key? k
              next
            end

            v.set_state nil, nil
            status = false
          end

          status
        end
      end
    end

    def set_state match, ignore
      each do |k, v|
        v.set_state match, ignore
      end
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s == path
        force = true
      end

      if force
        @ignore = true
      end

      each do |k, v|
        v.set_ignore path, condition, force
      end
    end

    def to_string
      str = ''
      size = 0

      keys.sort.each do |k|
        line = "%s = '%s'" % [k.to_string, self[k].to_string]
        size += line.bytesize

        str += ' %s' % line

        if size >= 60
          str += "\n  "
          size = 0
        end
      end

      str.rstrip
    end

    def to_html
      str = ''
      size = 0

      keys.sort.each do |k|
        line = "%s = '%s'" % [k.to_string, self[k].to_html]
        size += line.bytesize

        str += ' %s' % line

        if size >= 60
          str += "\n  "
          size = 0
        end
      end

      str.rstrip
    end
  end

  class XMLText
    attr_reader :value
    attr_accessor :path, :ignore, :match

    def initialize value
      @value = value
    end

    def == other_text
      if @ignore
        true
      else
        if other_text.nil?
          set_state nil, nil

          false
        else
          if @value == other_text.value
            set_state true, nil
            other_text.set_state true, nil

            true
          else
            set_state false, nil
            other_text.set_state false, nil

            false
          end
        end
      end
    end

    def set_state match, ignore
      @match = match
      @ignore = ignore
    end

    def set_ignore path, condition = nil, force = false
      if @path.to_s == path
        force = true
      end

      if force
        @ignore = true
      end
    end

    def to_string
      @value.to_string
    end

    def to_html
      str = @value.to_string

      if @ignore
        '<font style = "background:gray">%s</font>' % str
      else
        if @match.nil?
          '<font style = "background:#00ffff">%s</font>' % str
        else
          if @match
            str
          else
            '<font style = "background:red">%s</font>' % str
          end
        end
      end
    end
  end
end

module ASN1
  class Asn1Compare < Hash
    attr_accessor :name, :ignore, :sort_keys

    def initialize
      @ignore = {}
      @sort_keys = {}
    end

    def compare asn1, other_asn1
      if asn1.nil? or other_asn1.nil?
        if not asn1.nil? or not other_asn1.nil?
          self[@name] ||= []
          self[@name] << [false, asn1, other_asn1]

          false
        else
          true
        end
      else
        if asn1.classname == other_asn1.classname
          dup_asn1 = asn1.dclone
          dup_other_asn1 = other_asn1.dclone

          @ignore.each do |classname, paths_info|
            if classname == asn1.classname
              dup_asn1.set_ignore paths_info
              dup_other_asn1.set_ignore paths_info
            end
          end

          dup_asn1.set_sort_keys @sort_keys
          dup_other_asn1.set_sort_keys @sort_keys

          if dup_asn1 == dup_other_asn1
            self[@name] ||= []
            self[@name] << [true, dup_asn1, dup_other_asn1]

            true
          else
            self[@name] ||= []
            self[@name] << [false, dup_asn1, dup_other_asn1]

            false
          end
        else
          self[@name] ||= []
          self[@name] << [false, asn1, other_asn1]

          false
        end
      end
    end

    def compare_list asn1_list, other_asn1_list, is_clear = false, cmdcodes = nil
      asn1_hash = list2hash asn1_list
      other_asn1_hash = list2hash other_asn1_list

      asn1_hash.each do |ne, cmdcode_list|
        other_cmdcode_list = other_asn1_hash[ne]

        if other_cmdcode_list.nil?
          cmdcode_list.each do |cmdcode, list|
            list.each do |asn1|
              compare asn1, nil
            end
          end
        else
          cmdcode_list.each do |cmdcode, list|
            other_list = other_cmdcode_list[cmdcode]

            if other_list.nil?
              list.each do |asn1|
                compare asn1, nil
              end
            else
              list.each_with_index do |asn1, index|
                compare asn1, other_list[index]
              end

              if other_list.size > list.size
                other_list[list.size..-1].each do |asn1|
                  compare nil, asn1
                end
              end
            end
          end
        end
      end

      (other_asn1_hash.keys - asn1_hash.keys).each do |ne|
        cmdcode_list = other_asn1_hash[ne]

        cmdcode_list.each do |cmdcode, list|
          list.each do |asn1|
            compare nil, asn1
          end
        end
      end

      if is_clear
        clear cmdcodes
      end
    end

    def clear cmdcodes = nil
      each do |name, list|
        list.delete_if do |status, asn1, other_asn1|
          if asn1.nil?
            if cmdcodes.nil? or other_asn1.nil?
              true
            else
              cmdcodes.include? other_asn1.opt[:cmdcode]
            end
          else
            false
          end
        end
      end
    end

    def compare_results
      map = {}

      each.each do |name, list|
        map[name] = true

        list.each do |status, asn1, other_asn1|
          if not status
            if asn1.nil? or other_asn1.nil?
              map[name] = nil
            else
              if map[name]
                map[name] = false
              end
            end
          end
        end
      end

      map
    end

    def save filename = nil, home = nil, template = false
      filename ||= 'qxnew.log'
      home = File.expand_path home || '.'

      each do |name, list|
        if list.empty?
          next
        end

        File.open File.join(home, name, filename), 'w' do |f|
          list.each do |status, asn1, other_asn1|
            if template
              if asn1.nil?
                next
              end

              f.puts asn1.opt[:lines].locale
            else
              if other_asn1.nil?
                next
              end

              f.puts other_asn1.opt[:lines].locale
            end

            f.puts
          end
        end
      end

      true
    end

    def load_ignore file
      begin
        map = YAML::load_file file

        if map.kind_of? Hash
          @ignore = map
        end

        true
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def load_sort_keys file
      begin
        map = YAML::load_file file

        if map.kind_of? Hash
          @sort_keys = map
        end

        true
      rescue
        Util::Logger::exception $!

        false
      end
    end

    def to_html file
      File.open file, 'w' do |f|
        # head
        f.puts '<html>'
        f.puts '%s<head>' % INDENT
        f.puts '%s<title>ASN1 Compare</title>' % (INDENT * 2)
        f.puts '%s<style type = "text/css">' % (INDENT * 2)

        css =<<-STR
      table caption {
        text-align    : left;
        font-weight   : bold;
        font-size     : 15px;
      }

      table th {
        text-align    : left;
        vertical-align: top;
        font-weight   : 100;
        font-style    : italic;
        font-size     : 15px;
      }

      table td {
        text-align    : left;
        vertical-align: top;
        font-size     : 15px;
      }

      table pre {
        width         : 580px;
        margin        : 10px 0px 10px 0px;
        padding       : 10px;
        border        : 1px dashed #666;
        font-size     : 13px;
      }
        STR

        f.puts INDENT * 3 + css.strip
        f.puts '%s</style>' % (INDENT * 2)
        f.puts '%s</head>' % INDENT

        # body
        f.puts '%s<body>' % INDENT

        # summary
        index = 1

        each do |name, list|
          if not name.nil?
            if index > 1
              f.puts
            end

            f.puts '%s<h4>%s</h4><br/>' % [INDENT * 2, name.to_s.escapes]
          end

          f.puts '%s<table>' % (INDENT * 2)

          list.each_with_index do |asn1_info, idx|
            if idx > 0
              f.puts
            end

            status, asn1, other_asn1 = asn1_info

            ne = nil
            classname = nil
            cmdcode = nil
            time = nil

            if not asn1.nil?
              ne = asn1.opt[:name].to_s
              classname = asn1.classname
              cmdcode = asn1.opt[:cmdcode]

              if not asn1.opt[:time].nil?
                time = asn1.opt[:time].to_s_with_usec
              end
            end

            if not other_asn1.nil?
              classname ||= other_asn1.classname
              cmdcode ||= other_asn1.opt[:cmdcode]

              if ne != other_asn1.opt[:name]
                ne = '%s(%s)' % [ne, other_asn1.opt[:name]]
              end

              if not other_asn1.opt[:time].nil?
                time = '%s(%s)' % [time.to_s, other_asn1.opt[:time].to_s_with_usec]
              else
                time = time.to_s
              end
            end

            if not cmdcode.nil?
              cmdcode = '0x%s(%s)' % [cmdcode.to_s(16), cmdcode]
            end

            str = [ne, classname.to_s.split('.').last, cmdcode, time].join(', ').escapes

            f.puts '%s<tr><td>' % (INDENT * 3)

            if status
              f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :black, str]
            else
              if asn1.nil? or other_asn1.nil?
                if asn1.nil?
                  f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :teal, str]
                else
                  f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, '#00ffff', str]
                end
              else
                f.puts '%s<b>%s</b> <a name = "s_asn1_%s" href = "#asn1_%s"><font color = "%s">%s</font></a>' % [INDENT * 4, index, index, index, :red, str]
              end
            end

            f.puts '%s</td></tr>' % (INDENT * 3)

            index += 1
          end

          f.puts '%s</table>' % (INDENT * 2)
        end

        f.puts
        f.puts '%s<hr color = "gray"/><br/>' % (INDENT * 2)

        # detail
        index = 1

        each do |name, list|
          list.each do |status, asn1, other_asn1|
            f.puts

            f.puts '%s<table>' % (INDENT * 2)

            # caption
            f.puts '%s<caption><a name = "asn1_%s">ASN1: %s</a>  <a href = "#s_asn1_%s"><font color = "blue">back</font></a></caption>' % [INDENT * 3, index, index, index]
            f.puts

            f.puts '%s<tr>' % (INDENT * 3)
            f.puts '%s<th>' % (INDENT * 4)
            f.puts '<pre>'

            if asn1.nil?
              f.puts '-'
            else
              f.puts 'ne        : %s' % asn1.opt[:name]
              f.puts 'classname : %s' % asn1.classname

              if not asn1.opt[:cmdcode].nil?
                f.puts 'cmdcode   : 0x%s(%s)' % [asn1.opt[:cmdcode].to_s(16),  asn1.opt[:cmdcode]]
              else
                f.puts 'cmdcode   : '
              end

              if not asn1.opt[:time].nil?
                f.puts 'time      : %s' % asn1.opt[:time].to_s_with_usec
              else
                f.puts 'time      : '
              end

              if not asn1.opt[:file].nil?
                lines = File.normalize(asn1.opt[:file]).wrap 70
                f.puts 'file      : %s' % lines.shift

                lines.each do |line|
                  f.puts '            %s' % line
                end
              end
            end

            f.puts '</pre>'
            f.puts '%s</th>' % (INDENT * 4)

            f.puts

            f.puts '%s<th>' % (INDENT * 4)
            f.puts '<pre>'

            if other_asn1.nil?
              f.puts '-'
            else
              f.puts 'ne        : %s' % other_asn1.opt[:name]
              f.puts 'classname : %s' % other_asn1.classname

              if not other_asn1.opt[:cmdcode].nil?
                f.puts 'cmdcode   : 0x%s(%s)' % [other_asn1.opt[:cmdcode].to_s(16), other_asn1.opt[:cmdcode]]
              else
                f.puts 'cmdcode   : '
              end

              if not other_asn1.opt[:time].nil?
                f.puts 'time      : %s' % other_asn1.opt[:time].to_s_with_usec
              else
                f.puts 'time      : '
              end

              if not other_asn1.opt[:file].nil?
                lines = File.normalize(other_asn1.opt[:file]).wrap 70
                f.puts 'file      : %s' % lines.shift

                lines.each do |line|
                  f.puts '            %s' % line
                end
              end
            end

            f.puts '</pre>'
            f.puts '%s</th>' % (INDENT * 4)
            f.puts '%s</tr>' % (INDENT * 3)

            f.puts

            f.puts '%s<tr>' % (INDENT * 3)
            f.puts '%s<td>' % (INDENT * 4)
            f.puts '<pre>'

            if not asn1.nil?
              f.puts asn1.to_html
            end

            f.puts '</pre>'
            f.puts '%s</td>' % (INDENT * 4)

            f.puts

            f.puts '%s<td>' % (INDENT * 4)
            f.puts '<pre>'

            if not other_asn1.nil?
              f.puts other_asn1.to_html
            end

            f.puts '</pre>'
            f.puts '%s</td>' % (INDENT * 4)
            f.puts '%s</tr>' % (INDENT * 3)

            f.puts '%s</table>' % (INDENT * 2)

            index += 1
          end
        end

        f.puts '%s<br/><br/>' % (INDENT * 2)
        f.puts '%s</body>' % INDENT

        # tail
        f.puts '</html>'
      end

      GC.start

      true
    end

    private

    def list2hash asn1_list
      asn1_hash = {}

      asn1_list.each do |asn1|
        asn1_hash[asn1.ne] ||= {}
        asn1_hash[asn1.ne][asn1.cmdcode] ||= []
        asn1_hash[asn1.ne][asn1.cmdcode] << asn1
      end

      asn1_hash
    end
  end
end

module ASN1
  class Compare < Asn1Compare
    @@asn1compare = false

    def compare_html path
      path = File.expand_path path

      if File.directory? path
        if File.file? File.join(path, QUICKTEST_FILENAME_CHECK)
          asn1_list = get_asn1_list_from_file File.join(path, QUICKTEST_FILENAME_CHECK), file: QUICKTEST_FILENAME_CHECK

          if File.file? File.join(path, QUICKTEST_FILENAME_LOG)
            other_asn1_list = get_asn1_list_from_file File.join(path, QUICKTEST_FILENAME_LOG), file: QUICKTEST_FILENAME_LOG
          else
            other_asn1_list = []
          end

          compare_list asn1_list, other_asn1_list, true
        end

        if File.file? File.join(path, QUICKTEST_FILENAME_QX)
          asn1_list = get_asn1_list_from_file File.join(path, QUICKTEST_FILENAME_QX), file: QUICKTEST_FILENAME_QX

          if File.file? File.join(path, QUICKTEST_FILENAME_MSG)
            other_asn1_list = get_asn1_list_from_file File.join(path, QUICKTEST_FILENAME_MSG), file: QUICKTEST_FILENAME_MSG
          else
            other_asn1_list = []
          end

          asn1_list.sort! {|x, y| x.opt[:time] <=> y.opt[:time]}
          other_asn1_list.sort! {|x, y| x.opt[:time] <=> y.opt[:time]}

          compare_list asn1_list, other_asn1_list, true
        end

        if File.file? File.join(path, QUICKTEST_FILENAME_QTP)
          lines = [
            '[QTP LOG]'
          ]

          lines += IO.readlines File.join(path, QUICKTEST_FILENAME_QTP)
          asn1_list = get_asn1_list lines, file: QUICKTEST_FILENAME_QTP

          if File.file? File.join(path, QUICKTEST_FILENAME_QTP_NEW)
            lines = [
              '[QTP LOG]'
            ]

            lines += IO.readlines File.join(path, QUICKTEST_FILENAME_QTP_NEW)
            other_asn1_list = get_asn1_list lines, file: QUICKTEST_FILENAME_QTP_NEW
          else
            other_asn1_list = []
          end

          compare_list asn1_list, other_asn1_list, true
        end

        to_html File.join(path, COMPARE_HTML_FILE)
      end

      true
    end

    # info
    #   execute:
    #     ip:
    #       home:
    #       paths:
    #         path: path_info
    #   compare:
    #     ip:
    #       home:
    #       paths:
    #         path: path_info
    #   success:
    #     ip:
    #       home:
    #       paths:
    #         path: path_info
    def self.compare_index_html info, file
      File.open file, 'w' do |f|
        # head
        f.puts '<html>'
        f.puts '%s<head>' % INDENT
        f.puts '%s<title>index</title>' % (INDENT * 2)
        f.puts '%s<style type = "text/css">' % (INDENT * 2)

        css =<<-STR
      table caption {
        text-align    : left;
        font-weight   : bold;
        font-size     : 15px;
      }

      table th {
        text-align    : left;
        vertical-align: top;
        font-weight   : 100;
        font-style    : italic;
        font-size     : 15px;
      }

      table td {
        text-align    : left;
        vertical-align: top;
        font-size     : 15px;
      }

      table pre {
        width         : 580px;
        margin        : 10px 0px 10px 0px;
        padding       : 10px;
        border        : 1px dashed #666;
        font-size     : 13px;
      }
        STR

        f.puts INDENT * 3 + css.strip
        f.puts '%s</style>' % (INDENT * 2)
        f.puts '%s</head>' % INDENT

        # body
        f.puts '%s<body>' % INDENT

        if not info['execute'].nil?
          if not info['execute'].empty?
            f.puts '%s<br/><br/><h1>执行失败用例</h1>' % (INDENT * 2)
            f.puts '%s<hr color = "gray"/><br/>' % (INDENT * 2)
            f.puts

            info['execute'].each do |ip, ip_info|
              if not ip.nil?
                f.puts '%s<br/><h3>%s</h3><br/>' % [INDENT * 2, ip]
              end

              home = ip_info['home']

              f.puts '%s<table>' % (INDENT * 2)

              ip_info['paths'].each do |path, path_info|
                f.puts '%s<tr><td>' % (INDENT * 3)

                if home.nil?
                  href = File.join path, 'compare.html'
                else
                  href = File.join home, path, 'compare.html'
                end

                if path_info['compare']
                  f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, :black, path]
                else
                  f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, :red, path]
                end

                f.puts '%s</td></tr>' % (INDENT * 3)
              end

              f.puts '%s</table>' % (INDENT * 2)
            end

            f.puts
          end
        end

        if not info['expired'].nil?
          if not info['expired'].empty?
            f.puts '%s<br/><br/><h1>执行失败用例(超时)</h1>' % (INDENT * 2)
            f.puts '%s<hr color = "gray"/><br/>' % (INDENT * 2)
            f.puts

            info['expired'].each do |ip, ip_info|
              if not ip.nil?
                f.puts '%s<br/><h3>%s</h3><br/>' % [INDENT * 2, ip]
              end

              home = ip_info['home']

              f.puts '%s<table>' % (INDENT * 2)

              ip_info['paths'].each do |path, path_info|
                f.puts '%s<tr><td>' % (INDENT * 3)

                if home.nil?
                  href = File.join path, 'compare.html'
                else
                  href = File.join home, path, 'compare.html'
                end

                if path_info['compare']
                  f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, :black, path]
                else
                  f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, :red, path]
                end

                f.puts '%s</td></tr>' % (INDENT * 3)
              end

              f.puts '%s</table>' % (INDENT * 2)
            end

            f.puts
          end
        end

        if not info['compare'].nil?
          if not info['compare'].empty?
            f.puts '%s<br/><br/><h1>比较失败用例</h1>' % (INDENT * 2)
            f.puts '%s<hr color = "gray"/><br/>' % (INDENT * 2)
            f.puts

            info['compare'].each do |ip, ip_info|
              if not ip.nil?
                f.puts '%s<br/><h3>%s</h3><br/>' % [INDENT * 2, ip]
              end

              home = ip_info['home']

              f.puts '%s<table>' % (INDENT * 2)

              ip_info['paths'].each do |path, path_info|
                f.puts '%s<tr><td>' % (INDENT * 3)

                if home.nil?
                  href = File.join path, 'compare.html'
                else
                  href = File.join home, path, 'compare.html'
                end

                if path_info['compare'].nil?
                  f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, '#00ffff', path]
                else
                  f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, :red, path]
                end

                f.puts '%s</td></tr>' % (INDENT * 3)
              end

              f.puts '%s</table>' % (INDENT * 2)
            end

            f.puts
          end
        end

        if not info['success'].nil?
          if not info['success'].empty?
            f.puts '%s<br/><br/><h1>测试成功用例</h1>' % (INDENT * 2)
            f.puts '%s<hr color = "gray"/><br/>' % (INDENT * 2)
            f.puts

            info['success'].each do |ip, ip_info|
              if not ip.nil?
                f.puts '%s<br/><h3>%s</h3><br/>' % [INDENT * 2, ip]
              end

              home = ip_info['home']

              f.puts '%s<table>' % (INDENT * 2)

              ip_info['paths'].each do |path, path_info|
                f.puts '%s<tr><td>' % (INDENT * 3)

                if home.nil?
                  href = File.join path, 'compare.html'
                else
                  href = File.join home, path, 'compare.html'
                end

                f.puts '%s<b>%s</b> <a href = "%s"><font color = "%s">%s</font></a>' % [INDENT * 4, path_info['index'], href, :black, path]

                f.puts '%s</td></tr>' % (INDENT * 3)
              end

              f.puts '%s</table>' % (INDENT * 2)
            end

            f.puts
          end
        end

        f.puts '%s<br/><br/>' % (INDENT * 2)
        f.puts '%s</body>' % INDENT

        # tail
        f.puts '</html>'
      end

      true
    end

    private

    def get_asn1_list_from_file file, opt = nil
      opt ||= {}

      if not opt.has_key? :file
        opt[:file] = File.normalize file
      end

      get_asn1_list IO.readlines(file), opt
    end

    def get_asn1_list lines, opt = nil
      list = []

      cur_lines = []

      lines.each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        if line =~ /com\.zte\.ican\.util\.TDebugPrn\.msg\.(qx|cli|netconf)/ or line =~ /[\\\/]log[\\\/]qxmsg.*\.hex/ or line =~ /\[\s*INFO\s*\].*用例【(.+)】开始执行/ or line =~ /^\[.+\]$/
          asn1 = get_asn1 cur_lines, opt

          if not asn1.nil?
            list << asn1
          end

          cur_lines = []
        end

        cur_lines << line
      end

      asn1 = get_asn1 cur_lines, opt

      if not asn1.nil?
        list << asn1
      end

      list
    end

    def get_asn1 lines, opt = {}
      __lines__ = lines.dclone
      line = lines.shift

      asn1 = nil

      case
      when line =~ /(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s*,\s*(\d+)\s+INFO\s*\[com\.zte\.ican\.util\.TDebugPrn\.msg\.(qx|cli|netconf)/
        time = Time.mktime $1, $2, $3, $4, $5, $6, $7.to_i * 1000

        case $8
        when 'qx'
          line = lines.shift

          if line =~ /LABEL\s*=\s*(.+)\s+ME\s*=\s*(.+)\s+CMDCODE\s*=\s*([0-9a-fA-FxX]+)/
            opt = opt.merge({
              #:name     => '%s(%s)' % [$1, $2]
              :ne       => $1,
              :cmdcode  => $3.to_i(16),
              :time     => time,
              :data     => lines,
              :lines    => __lines__
            })

            asn1 = ASN1::Asn1.new opt
          end
        when 'cli'
          lines.delete_if {|x| x =~ /^=+\s*(CmdStart|CmdEnd|CMDSTART|CMDEND)\s*=+$/}

          line = lines.shift

          case
          when line =~ /value\s*=\s*(.+),\s*label\s*=\s*(.+),\s*ip\s*=\s*(.+)/
            opt = opt.merge({
              #:name     => '%s(%s)' % [$2, $1],
              :ne       => $2,
              :cmdcode  => nil,
              :time     => time,
              :data     => lines,
              :lines    => __lines__
            })

            asn1 = ASN1::Cli.new opt
          when line =~ /ME\s+is\s+(.+),\s*userlabel\s+is\s+(.+),\s*ip\s+is\s+(.+),\s*command\s+code\s*=\s*([0-9a-fA-FxX]+)/
            opt = opt.merge({
              #:name     => [$2, $1],
              :ne       => $2,
              :cmdcode  => $4.to_i(16),
              :time     => time,
              :data     => lines,
              :lines    => __lines__
            })

            asn1 = ASN1::Cli.new opt
          end
        when 'netconf'
          line = lines.shift

          if line =~ /LABEL\s*=\s*(.+)\s+ME\s*=\s*(.+)\s+CMDCODE\s*=\s*([0-9a-fA-FxX]+)/
            opt = opt.merge({
              #:name     => '%s(%s)' % [$1, $2]
              :ne       => $1,
              :cmdcode  => nil,
              :time     => time,
              :data     => lines,
              :lines    => __lines__
            })

            asn1 = ASN1::XML.new opt
          end
        end
      when line =~ /[\\\/]log[\\\/]qxmsg[\\\/]\[(\d{4})-(\d{2})-(\d{2})\s+(\d{2})_(\d{2})_(\d{2})_(\d+)\]-\[(\d+)\]\[down\]-\[(.+)\].*\.hex/
        time = Time.mktime $1, $2, $3, $4, $5, $6, $7

        opt = opt.merge({
          #:name     => $9,
          :ne       => $9,
          :cmdcode  => $8.to_i,
          :time     => time,
          :data     => lines,
          :lines    => __lines__
        })

        asn1 = ASN1::Asn1.new opt
      when line =~ /(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)\s+\[\s*INFO\s*\].*用例【(.+)】开始执行/
        name = $7
        time = Time.mktime $1, $2, $3, $4, $5, $6

        __lines__ = []

        lines.each do |line|
          if line =~ /\[\s*CHECK\s*\]\s*-\s*/
            __lines__ << $'.strip.split(']', 2).last.strip.gsub(' ', '')
          end
        end

        opt = opt.merge({
          :name       => 'quicktest check',
          :classname  => name,
          :time       => time,
          :data       => __lines__,
          :lines      => lines
        })

        asn1 = ASN1::Cli.new opt
      when line =~ /^\[(.+)\]$/
        name = $1.to_s.strip
        time = Time.now

        if name =~ /^\d+_/
          classname = $'.strip
        else
          classname = name
        end

        if name.upcase =~ /^\d+_([0-9A-F]+)@$/
          cmdcode = $1.to_i 16
        else
          cmdcode = nil
        end

        if name.upcase =~ /\d_([0-9A-F]+)@/
          cmdcode = $1.to_i 16
        else
          cmdcode = nil
        end

        opt = opt.merge({
          :name       => 'agent qx(%s)' % name,
          :classname  => classname,
          :cmdcode    => cmdcode,
          :time       => time,
          :data       => lines,
          :lines      => lines
        })

        asn1 = ASN1::Cli.new opt
      end

      if asn1.nil?
        nil
      else
        ignore = false

        if not opt[:start_time].nil?
          if asn1.opt[:time] < opt[:start_time]
            ignore = true
          end
        end

        if not opt[:finish_time].nil?
          if asn1.opt[:time] > opt[:finish_time]
            ignore = true
          end
        end

        if ignore
          nil
        else
          begin
            if asn1.validate?
              asn1
            else
              nil
            end
          rescue
            Util::Logger::exception $!

            nil
          end
        end
      end
    end

    def get_asn1_check_from_file file
      lines = []

      IO.readlines(file).each do |line|
        line = line.utf8.strip

        if line.empty?
          next
        end

        lines << line
      end

      name = nil
      time = nil
      __lines__ = []

      lines.each do |line|
        if line =~ /\[\s*CHECK\s*\]\s*-\s*/
          __lines__ << $'.strip.split(']', 2).last.strip.gsub(' ', '')
        end

        if name.nil?
          if line =~ /(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)\s+\[\s*(INFO|CHECK)\s*\]\s*-\s*\[(.*)\]/
            name = $8
            time = Time.mktime $1, $2, $3, $4, $5, $6
          end
        end
      end

      opt = {
        :file       => File.normalize(file),
        :name       => 'quicktest check',
        :classname  => name,
        :time       => time,
        :data       => __lines__,
        :lines      => lines
      }

      asn1 = ASN1::Cli.new opt

      if asn1.nil?
        nil
      else
        begin
          if asn1.validate?
            asn1
          else
            nil
          end
        rescue
          Util::Logger::exception $!

          nil
        end
      end
    end
  end
end