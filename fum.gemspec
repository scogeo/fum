# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fum/version"

Gem::Specification.new do |s|
  s.name        = "fum"
  s.version     = Fum::VERSION
  s.authors     = ["George Scott", "RumbleWare Inc."]
  s.email       = ["foss@rumbleware.com"]
  s.homepage    = "http://github.com/rumbleware/fum"
  s.summary     = "Management tool for AWS Elastic Beanstalk"
  s.description = "fum helps you manage your AWS Elastic Beanstalk environments"

  s.rubyforge_project = "fum"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "fog", "~>1.4.0"
  s.add_runtime_dependency "json", "~>1.6.5"

end
