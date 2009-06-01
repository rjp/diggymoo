require 'rake'

spec = Gem::Specification.new do |s| 
  s.name = "twittermoo"
  s.version = "0.0.1"
  s.author = "Rob Partington"
  s.email = "zimpenfish@gmail.com"
  s.homepage = "http://rjp.github.com/twittermoo"
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple Twitter-to-Socket gateway"
  s.files = FileList["{bin,lib}/**/*"].to_a
  s.require_path = "lib"
  s.test_files = []
  s.has_rdoc = false
end

