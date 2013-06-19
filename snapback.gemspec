Gem::Specification.new do |gem|
  gem.name        = 'snapback'
  gem.version     = '0.0.1'
  gem.date        = '2013-06-19'
  gem.executables << 'snapback'
  gem.summary     = "Snapback"
  gem.description = "A simple logical volume database manager"
  gem.authors     = ["Bashkim Isai"]
  gem.email       = ''
  gem.files       = Dir["lib/**/*", "bin/*", "README*"]
  gem.homepage    = 'http://github.com/bashaus/snapback'
  
  # dependencies
  gem.add_dependency('mysql', '>= 2.9.1')
  gem.add_dependency('open4', '>= 1.3.0')
  gem.add_dependency('ruby-lvm', '>= 0.1.1')
  gem.add_dependency('colorize', '>= 0.5.8')
end