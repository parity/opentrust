require_relative "lib/opentrust/version"

Gem::Specification.new do |s|
  s.name        = "opentrust"
  s.version     = OpenTrust::VERSION
  s.summary     = "Ruby client for the OpenTrust API"
  s.description = "Check mobile numbers against experiences shared by other Indian merchants, and share your own. A small, dependency-free client for https://opentrust.in."
  s.authors     = ["OpenTrust"]
  s.homepage    = "https://opentrust.in/docs"
  s.license     = "MIT"
  s.required_ruby_version = ">= 2.7"
  s.files       = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  s.metadata    = {
    "documentation_uri"      => "https://opentrust.in/docs",
    "rubygems_mfa_required"  => "true"   # pushing a release then always needs a one-time code, even with a stolen API key
  }
end
