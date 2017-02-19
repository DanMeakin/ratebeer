# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'ratebeer'
  s.version = '0.1.1'
  s.default_executable = 'ratebeer'

  if s.respond_to? :required_rubygems_version=
    s.required_rubygems_version = Gem::Requirement.new('>= 0')
  end
  s.authors = ['Dan Meakin']
  s.date = '2016-07-30'
  s.description = 'RateBeer provides a way to access information from \
                  \RateBeer.com.'
  s.email = 'dan@danmeakin.com'
  s.files = Dir['lib/**/*.rb'] + Dir['bin/*'] + Dir['[A-Z]*'] + Dir['spec/**/*']
  s.require_paths = ['lib']
  s.summary = 'Unofficial RateBeer API'
  s.add_runtime_dependency('nokogiri')
  s.add_runtime_dependency('i18n')
end
