require 'rubygems'
require 'twitter'
require 'gdbm'
require 'sha1'
require 'optparse'
require 'socket'
require 'json'
require 'haml'

template = File.read('email.txt')
engine = Haml::Engine.new(template)

# fix for ruby's utterly braindead timeout handling
# http://jerith.livejournal.com/40063.html

$options = {
    :once => true,
    :dbfile => ENV['HOME'] + '/.twittermoo.db',
    :config => ENV['HOME'] + '/.twittermoo',
    :verbose => nil,
    :max => 100,    # the maximum number to look back
    :page => 20    # how many to fetch at a time
}

OptionParser.new do |opts|
  opts.banner = "Usage: twittermoo.rb [-v] [-p port] [-h host] [-d dbfile] [-c config] [-o] [-w N] [-p N] [-e N]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    $options[:verbose] = v
  end

  opts.on("-m", "--max N", Integer, "Maximum number of tweets to consider") do |p|
    $options[:max] = p
  end

  opts.on("-p", "--page N", Integer, "How many tweets to check at once") do |p|
    $options[:page] = p
  end

  opts.on("-d", "--dbfile DBFILE", String, "dbfile") do |p|
    $options[:dbfile] = p
  end

  opts.on("-c", "--config CONFIG", String, "config file") do |p|
    $options[:config] = p
  end
end.parse!

# TODO move this to something like log4r if they have it
def log(x)
    if $options[:verbose] then
        puts *x
    end
end

def dopp_colour(name)
    dopp = SHA1.hexdigest(name)
	r = (128 + (dopp[0..1].hex)/2).to_s(16)
	g = (128 + (dopp[2..3].hex)/2).to_s(16)
	b = (128 + (dopp[4..5].hex)/2).to_s(16)
    return [r,g,b].join()
end

# have we seen this twit before?
def seen(twit)
    if $already_seen.nil? then
        $already_seen = GDBM.new($options[:dbfile])
    end
    return $already_seen[twit.id.to_s(16)]
end

def update_seen(twit)
    if $already_seen.nil? then
        $already_seen = GDBM.new($options[:dbfile])
    end
    $already_seen[twit.id.to_s(16)] = 'p'
end

# this is very lame
def fetch_timeline(twitter, perpage, max)
    log "T fetching current timeline"
    fetched = 0
    page = 0
    tl = []
    attempts = 5
    loop do
        begin
            while fetched < max do
                log "T fetching #{perpage}, page #{page}"
                pl = twitter.home_timeline(:count => perpage, :page => page)
                oldest = pl[-1]
                tl.push(*pl)
                if seen(oldest) then
                    log "Y timeline fetched successfully, #{tl.size} items"
                    return tl # we've overlapped, return
                end
                fetched = fetched + perpage
                page = page + 1
            end
            log "Y timeline didn't overlap after #{max}"
            return tl
        rescue Timeout::Error
            log "E $!"
            attempts = attempts - 1
            if attempts == 0 then
                log "too many failures, bailing for 120s"
                sleep 120
                attempts = 5
            else
                log "transient failure, sleeping for 30s"
                sleep 30
            end
        rescue
            raise $!
            sleep 10
        end
    end
end

config = YAML::load(open($options[:config]))

# allow settings of options from the config file
unless config['options'].nil? then
    options.merge!(config['options'])
end

oauth = Twitter::OAuth.new(config['consumer_key'], config['consumer_secret'])
# try and force OOB
oauth.set_callback_url('oob');
bits = YAML::load(open(ENV['HOME'] + '/.twittermoo.json'));
if (bits.nil? or bits[:acc].nil?) then # already authorised
	r = oauth.request_token();
    puts "You have no auth tokens, please visit this URL for your PIN:"
	p r.authorize_url;
	puts "Enter the PIN:";
	pin = $stdin.gets.chomp
	puts "PIN IS [#{pin}]"
	rat = r.get_access_token(:oauth_verifier => pin);
	File.open(ENV['HOME'] + "/.twittermoo.json", "w") do |f|
	    bits = { :pin => pin, :req => r, :acc => rat }
	    f.puts bits.to_yaml
	end
    puts "Continuing with new authentication tokens"
end

log "authing with " + [bits[:acc].token, bits[:acc].secret].join(' ')

# hardcode these in the config because we run as one user
oauth.authorize_from_access(bits[:acc].token, bits[:acc].secret)

twitter = Twitter::Base.new(oauth)

log "L entering main loop"
loop {
if false then
    log "T fetching direct messages since #{prev_time}"

    begin
	    twitter.direct_messages().each do |s|
	      log "D #{s.id} #{s.text}"
	      xtime = Time.parse(s.created_at)
	      if xtime > prev_time then
	          prev_time = xtime # this is kinda lame
	      end
	    end
    rescue Timeout::Error => e
        puts "timeout error #{e}"
        sleep 15
        retry
    rescue => e
        puts "something went wrong #{e}"
        sleep 15
        retry
    end
end

    tl = fetch_timeline(twitter, $options[:page], $options[:max])
    log "Y timeline fetched successfully, #{tl.size} items"

# FIXME need to check if we have a gap between this fetch and the previous

    posts = []

    tl.reverse.each do |s|
        status = seen(s)
        if status.nil? then
            log "N +/#{s.id} #{s.user.name} #{s.text[0..6]}..."
            ts = Time.parse(s.created_at)
            s.created_at = ts
# convert @mentions into links to twitter pages
            s.text.gsub!(/@(\w+)/) {|i| "<a href='http://twitter.com/#{$1}/'>@#{$1}</a>"}
# provide a dopplr-like colour for highlighting
            s.dopp = dopp_colour(s.user.screen_name)
            posts.push s
            update_seen(s)
        else
            if status != 'p' then
                log "O #{status}/#{s.id} #{s.user.name} #{s.text[0..6]}..."
            end
            update_seen(s)
        end
    end

	File.open(ENV['HOME'] + "/.twittermoo.last", "w") do |f|
        f.puts posts.inspect
    end

    puts engine.render(Object.new, {
        :boundary => "kjhkjfdshkjhkjh23khekjhskjdhfjd",
        :posts => posts
    })

    if $options[:once].nil? then
        log "S #{Time.now}"
        sleep $options[:every]
    else
        break
    end
}

