require 'rubygems'
require 'twitter'
require 'gdbm'
require 'sha1'
require 'spread.so'

# connect to the spreadery
sp = Spread.new("4803", "twittermoo")
sp.join('sport_say')

config = YAML::load(open(ENV['HOME'] + '/.twittermoo'))
 
twitter = Twitter::Base.new(config['email'], config['password'])

already_seen = GDBM.new('/data/rjp/db/mootwits.db')

twitter.timeline(:friends).each do |s|
    sha1 = SHA1.hexdigest(s.text + s.user.name)
#    already_seen[sha1] = "s"
end

loop {
    twitter.timeline(:friends).reverse.each do |s|
	    sha1 = SHA1.hexdigest(s.text + s.user.name)
	    if already_seen[sha1].nil? then
            ts = Time.parse(s.created_at)
            output = "<#{s.user.screen_name}> #{s.text} (#{ts.strftime('%Y%m%d %H%M%S')})"
            if s.text =~ /^@(\w+)\s/ then
                puts "? #{$1}"
                if twitter.friends.include?($1) then
    	            puts "+ #{output}"
#                    sp.multicast(output, 'bot_say', Spread::RELIABLE_MESS)
                else
                    puts "- #{output}"
                end
            else
    	        puts "+ #{output}"
#                sp.multicast(output, 'bot_say', Spread::RELIABLE_MESS)
            end
#            already_seen[sha1] = "s"
	    end
        sleep 20
    end

# clean out our incoming spread queue to avoid problems
    loop do
        messages = sp.poll
        if messages > 0 then
            junk = sp.receive
        else
            break
        end
    end
    sleep 300
}
