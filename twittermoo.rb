require 'rubygems'
require 'twitter'
require 'gdbm'
require 'sha1'
require 'spread.so'
require 'chronic'

# connect to the spreadery
sp = Spread.new("4803", "twittermoo")
sp.join('sport_say')

config = YAML::load(open(ENV['HOME'] + '/.twittermoo'))
 
httpauth = Twitter::HTTPAuth.new(config['email'], config['password'])
twitter = Twitter::Base.new(httpauth)

already_seen = GDBM.new('/data/rjp/db/mootwits.db')

puts "B fetching current timeline and ignoring"
twitter.friends_timeline().each do |s|
    sha1 = SHA1.hexdigest(s.text + s.user.name)
    xtime = Time.parse(s.created_at)
    threshold = Chronic.parse('one hour ago')
    if xtime < threshold then
        already_seen[sha1] = "s"
    end
end

prev_time = Time.now - 3600
puts "L entering main loop"
loop {

    puts "T fetching direct messages since #{prev_time}"

    twitter.direct_messages().each do |s|
      puts "D #{s.id} #{s.text}"
      xtime = Time.parse(s.created_at)
      if xtime > prev_time then
          prev_time = xtime # this is kinda lame
      end
    end

    puts "T fetching current timeline"
    tl = []
    attempts = 5
    loop do
        begin
            tl = twitter.friends_timeline()
            puts "Y timeline fetched successfully, #{tl.size} items"
            sleep 5
            break
        rescue Timeout::Error, Twitter::CantConnect
            puts "E $!"
            attempts = attempts - 1
            if attempts == 0 then
                puts "too many failures, bailing for 120s"
                sleep 120
                attempts = 5
            else
                puts "transient failure, sleeping for 30s"
                sleep 30
            end
        rescue
            raise $!
            sleep 10
        end
    end

    puts "Y timeline fetched successfully, #{tl.size} items"

    tl.reverse.each do |s|
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
                if output.length > 250 then
                    $stderr.puts "#{output[0..250]}..."
                    exit;
                end
                    sp.multicast(output, 'bot_say', Spread::RELIABLE_MESS)
                else
                    puts "- #{output}"
                end
            else
    	        puts "+ #{output}"
                if output.length > 250 then
                    $stderr.puts "#{output[0..250]}..."
                    exit;
                end
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

    puts "S #{Time.now}"
    sleep 300

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

}
