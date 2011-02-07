# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "drupistrano/version"

Gem::Specification.new do |s|
  s.name        = "drupistrano"
  s.version     = Drupistrano::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jorge Dias"]
  s.email       = ["jorge@mrdias.com"]
  s.homepage    = ""
  s.summary     = %q{Deployment Recipe for Drupal}
  s.description = %q{A Recipe to easily deploy Drupal Applications}

  s.rubyforge_project = "drupistrano"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency(%q<capistrano>, [">= 1.0.0"])
end
