# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name             = "dm-salesforce-adapter"
  s.version          = '1.1.0'
  s.platform         = Gem::Platform::RUBY
  s.has_rdoc         = true
  s.extra_rdoc_files = [ "README.markdown", "LICENSE" ]
  s.summary          = "A DataMapper 1.1.x adapter to the Salesforce API"
  s.description      = s.summary
  s.authors          = [ "Jordan Ritter", "Tim Carey-Smith", "Andy Delcambre", "Yehuda Katz" ]
  s.email            = "jpr5@serv.io"
  s.homepage         = "http://github.com/cloudcrowd/dm-salesforce-adapter"

  s.add_dependency "data_objects"
  s.add_dependency "dm-core"
  s.add_dependency "dm-validations"
  s.add_dependency "dm-types"
  s.add_dependency 'savon'
  s.add_dependency 'httpclient'

  s.require_path = 'lib'
  s.files        = %w(LICENSE README.markdown Rakefile) + Dir.glob("lib/**/*")
end