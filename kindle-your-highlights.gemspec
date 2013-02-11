Gem::Specification.new do |s|
  s.name        = 'kindle-your-highlights'
  s.version     = '0.1.0'
  s.summary     = "Kindle your highlights"
  s.description = "Scrape highlights from kindle.amazon.com"
  s.authors     = ["parroty", "ftzeng"]
  s.email       = 'ftzeng@gmail.com'
  s.files       = ["lib/kindle-your-highlights.rb", "lib/kindle-your-highlights/kindle_format.rb"]
  s.homepage    = 'https://github.com/ftzeng/kindle-your-highlights'

  s.add_runtime_dependency 'nokogiri', '>= 1.5.0'

end
