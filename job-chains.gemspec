$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "job-chains/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "job-chains"
  s.version     = JobChains::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of JobChains."
  s.description = "TODO: Description of JobChains."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.1.12"

  s.add_development_dependency "sqlite3"
end
