require 'rubygems'
require 'twitter'
require 'gdbm'
require 'sha1'

config = YAML::load(open(ENV['HOME'] + '/.twittermoo'))
 
twitter = Twitter::Base.new(config['email'], config['password'])

already_seen = GDBM.new('/data/rjp/db/mootwits.db')

twitter.timeline(:friends).each do |s|
    sha1 = SHA1.hexdigest(s.text + s.user.name)
#    already_seen[sha1] = "s"
end

loop {
    twitter.timeline(:friends).each do |s|
	    sha1 = SHA1.hexdigest(s.text + s.user.name)
	    if already_seen[sha1].nil? then
            output = "<#{s.user.screen_name}> #{s.text}"
            puts "* #{output}"
            if s.text =~ /^@(\w+)\s/ then
                puts "? #{$1}"
                if twitter.friends.include?($1) then
    	            puts "+ #{output}"
                else
                    puts "- #{output}"
                end
            else
    	        puts "+ #{output}"
            end
#            already_seen[sha1] = "s"
	    end
#        sleep 20
    end
    sleep 300
}
