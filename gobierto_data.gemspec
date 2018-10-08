Gem::Specification.new do |s|
  s.name        = "gobierto_data"
  s.version     = "0.0.1"
  s.date        = "2018-05-29"
  s.summary     = "Gobierto Data utils"
  s.description = "This gem contains utilities to load data chunks in Gobierto"
  s.authors     = ["Fernando Blat"]
  s.email       = "fernando@populate.tools"
  s.files       = Dir["lib/*.rb"]
  s.homepage    = "https://github.com/PopulateTools/gobierto_data"
  s.license     = "MIT"
  s.add_runtime_dependency "aws-sdk", "~> 2.11", ">= 2.11.45"
  s.add_runtime_dependency "actionpack", ">= 5.0.0.1"
  s.add_runtime_dependency "activesupport", ">= 5.0.0"
  s.add_runtime_dependency "elasticsearch", "~> 6.0", ">= 6.0.2"
  s.add_runtime_dependency "elasticsearch-extensions", "~> 0.0.27"
  s.add_runtime_dependency "oj", "~> 3.5", ">= 3.5.0"
  s.add_runtime_dependency "ine-places", "~> 0.3.0"

  s.add_development_dependency "byebug", "~> 10.0", ">= 10.0.2"
end
