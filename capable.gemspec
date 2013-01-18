# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capable/version"

Gem::Specification.new do |s|
  s.name        = "capable"
  s.version     = Capable::VERSION
  s.authors     = ["Hong"]
  s.email       = ["hong@hybridgroup.com"]
  s.homepage    = ""
  s.summary     = %q{Capable: What's this capable of?}
  s.description = %q{This is primarily used for sharing models/modules (and somewhat limitedly views) across similar subprojects.}

  s.rubyforge_project = "capable"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
end
