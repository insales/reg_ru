Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'reg_ru'
  s.version     = '1.0.0'
  s.licenses    = ['MIT']
  s.summary     = "Ruby wrapper for reg.ru API."
  s.authors     = ["Vladimir Bedarev", "Dmitry Novotochinov"]
  s.files       = Dir[
                    "README.markdown",
                    "MIT-LICENSE",
                    "AUTHORS",
                    "Rakefile",
                    "lib/**/*",
                    "spec/**/*"
                  ]

  s.add_runtime_dependency 'activesupport'
end
