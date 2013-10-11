# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','snapback','version.rb'])
spec = Gem::Specification.new do |s| 
  s.name        = 'snapback'
  s.version     = Snapback::VERSION
  s.date        = '2013-09-09'
  s.authors     = ['Bashkim Isai']
  s.license     = 'MIT'
  s.homepage    = 'http://github.com/bashaus/snapback'
  s.platform    = Gem::Platform::RUBY
  s.summary     = 'Snapback'

  s.files = Dir['lib/**/*', 'bin/*', 'README*']

  s.require_paths << 'lib'
  s.bindir = 'bin'
  s.executables << 'snapback'

  s.add_development_dependency('aruba')

  s.add_runtime_dependency('gli','2.8.0')

  # dependencies
  s.add_dependency('mysql', '>= 2.9.1')
  s.add_dependency('open4', '>= 1.3.0')
  s.add_dependency('ruby-lvm', '>= 0.1.1')
  s.add_dependency('colorize', '~> 0.5.8')
end