# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'recurrent/version'

Gem::Specification.new do |s|
  s.name         = "recurrent"
  s.version      = Recurrent::VERSION
  s.platform     = Gem::Platform::RUBY
  s.license      = "MIT"
  s.authors      = ["Adam Kittelson"]
  s.email        = ["adam@zencoder.com"]
  s.homepage     = "http://github.com/zencoder/recurrent"
  s.summary      = "Task scheduler that doesn't need to bootstrap your Rails environment every time it executes a task the way running a rake task via cron does."
  s.description  = "Task scheduler that doesn't need to bootstrap your Rails environment every time it executes a task the way running a rake task via cron does."

  s.add_dependency "ice_cube", "0.16.3"
  s.add_dependency "activesupport"
  s.add_dependency "i18n"
  s.add_dependency "trollop"
  s.add_development_dependency "rspec"
  s.add_development_dependency "timecop"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-doc"
  s.executables << "recurrent"
  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = "lib"
end
