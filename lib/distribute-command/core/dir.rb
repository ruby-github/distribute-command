require 'tmpdir'

class Dir
  class << self
    alias __pwd__ pwd
    alias __tmpdir__ tmpdir
  end

  def self.pwd
    Dir.__pwd__.utf8
  end

  def self.tmpdir
    dir = Dir.__tmpdir__.utf8

    if OS::windows?
      if File.directory? 'C:/'
        dir = 'C:/Temp'
      end
    end

    dir
  end
end