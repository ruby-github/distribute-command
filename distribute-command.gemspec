Gem::Specification.new do |s|
  s.name                  = 'distribute-command'
  s.version               = '0.0.1'
  s.authors               = 'jack'
  s.date                  = '2016-08-01'
  s.summary               = 'distribute command'
  s.description           = 'distribute command'

  s.files                 = Dir.glob('{bin,doc,lib,tools}/**/*') + ['distribute-command.gemspec', 'README.md']
  s.executables           = ['drb']
  s.require_path          = 'lib'
  s.required_ruby_version = '>= 2.1.0'
end