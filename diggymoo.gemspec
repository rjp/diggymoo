spec = Gem::Specification.new do |s| 
  s.name = "diggymoo"
  s.version = "0.2.4"
  s.author = "Rob Partington"
  s.email = "zimpenfish@gmail.com"
  s.homepage = "http://rjp.github.com/diggymoo"
  s.platform = Gem::Platform::RUBY
  s.summary = "Simple Twitter email digest"
  s.description = "Simple Twitter email digest"
  s.files = ['bin/diggy-fetcher.rb','bin/diggy-mailer.rb','lib/diggymoo.rb', 'email.txt']
  s.require_path = "lib"
  s.test_files = []
  s.has_rdoc = false
  s.add_dependency('twitter', '>= 0.5')
  s.add_dependency('haml', '>= 0.0')
  s.add_dependency('gdbm', '>= 0.0')
  s.add_dependency('mash', '>= 0.0')
  s.executables = ['diggy-fetcher.rb','diggy-mailer.rb']
end

