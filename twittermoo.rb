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

puts "B fetching current timeline and ignoring"
twitter.timeline(:friends).each do |s|
    sha1 = SHA1.hexdigest(s.text + s.user.name)
    already_seen[sha1] = "s"
end

puts "L entering main loop"
loop {
    puts "T fetching current timeline"
    twitter.timeline(:friends).reverse.each do |s|
	    sha1 = SHA1.hexdigest(s.text + s.user.name)
        status = already_seen[sha1]
	    if status.nil? then
            puts "N +/#{sha1} #{s.user.name} #{s.text[0..6]}..."
            ts = Time.parse(s.created_at)
            output = "<#{s.user.screen_name}> #{s.text} (#{ts.strftime('%Y%m%d %H%M%S')})"
            if s.text =~ /^@(\w+)\s/ then
                puts "? #{$1}"
                if 1 then # twitter.friends.include?($1) then
    	            puts "+ #{output}"
                    sp.multicast(output, 'bot_say', Spread::RELIABLE_MESS)
                else
                    puts "- #{output}"
                end
            else
    	        puts "+ #{output}"
                sp.multicast(output, 'bot_say', Spread::RELIABLE_MESS)
            end
            already_seen[sha1] = "p"
            sleep 20
        else
            if status != 'p' then
                puts "O #{status}/#{sha1} #{s.user.name} #{s.text[0..6]}..."
            end
            already_seen[sha1]='p'
	    end
    end

# clean out our incoming spread queue to avoid problems
#    messages = 1
#    while messages > 0 do
#        messages = sp.poll
#        if messages > 0 then
#            junk = sp.receive
#        else
#            break
#        end
#    end

    puts "S #{Time.now}"
    sleep 300
}
