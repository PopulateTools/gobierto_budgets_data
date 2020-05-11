$:.push File.expand_path("../lib", __FILE__)
Gem::Specification.new do |s|
  s.name        = "gobierto_data"
  s.version     = "0.1.0"
  s.date        = "2018-05-29"
  s.summary     = "Gobierto Data utils"
  s.description = "This gem contains utilities to load data chunks in Gobierto"
  s.authors     = ["Fernando Blat"]
  s.email       = "fernando@populate.tools"
  s.files         = `git ls-files`.split("\n")
  s.test_files    = []
  s.executables   = []
  s.require_paths = ["lib"]
  s.homepage    = "https://github.com/PopulateTools/gobierto_data"
  s.license     = "MIT"
  s.add_runtime_dependency "aws-sdk-s3"
  s.add_runtime_dependency "actionpack"
  s.add_runtime_dependency "activesupport"
  s.add_runtime_dependency "elasticsearch"
  s.add_runtime_dependency "elasticsearch-extensions"
  s.add_runtime_dependency "oj", "~> 3.6"
  s.add_runtime_dependency "ine-places", "~> 0.3.0"
  s.add_runtime_dependency "rake", "~> 13.0"

  s.add_development_dependency "byebug"
end
