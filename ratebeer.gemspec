Gem::Specification.new do |s|
  s.name = "ratebeer"
  s.version = "0.0.3"
  s.default_executable = "ratebeer"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dan Meakin"]
  s.date = %q{2016-04-10}
  s.description = %q{RateBeer provides a way to access beer & brewery data from RateBeer.com.}
  s.email = %q{dan@danmeakin.com}
  s.files = Dir['lib/*.rb'] + Dir['bin/*'] + Dir['[A-Z]*'] + Dir['spec/**/*']
  s.require_paths = ['lib']
  s.summary = %q{Unofficial RateBeer API}
end
