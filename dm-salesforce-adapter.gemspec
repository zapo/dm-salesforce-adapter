$:.unshift "lib"
require "dm-salesforce-adapter/version"

Gem::Specification.new do |s|
  s.name = "dm-salesforce-adapter"
  s.version = SalesforceAdapter::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.markdown", "LICENSE"]
  s.summary = "A DataMapper 1.0x adapter to the Salesforce API"
  s.description = s.summary
  s.authors = ["Yehuda Katz", "Tim Carey-Smith", "Andy Delcambre", "Jordan Ritter"]
  s.email = "jpr5@cloudcrowd.com"
  s.homepage = "http://github.com/cloudcrowd/dm-salesforce-adapter"

  s.add_dependency "httpclient",     "=2.1.5.2"
  s.add_dependency "extlib",         "~> 0.9.15"
  s.add_dependency "data_objects",   "~> 0.10.2"
  s.add_dependency "dm-core",        "~> 1.0.2"
  s.add_dependency "dm-validations", "~> 1.0.2"
  s.add_dependency "dm-types",       "~> 1.0.2"
  s.add_dependency "soap4r",         "~> 1.5.8"

  s.require_path = 'lib'
  s.files = %w(LICENSE README.markdown Rakefile) + Dir.glob("lib/**/*")
end
