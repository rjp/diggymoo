#! /usr/bin/env ruby
require 'rubygems'
require 'diggymoo'

# TODO move this to something like log4r if they have it
def log(x)
    if $options[:verbose] then
        puts *x
    end
end

# have we seen this twit before?
def seen(twit)
    return $redis.sismember(dbkey('seen'), twit.id)
end

def update_seen(twit)
    $redis.sadd(dbkey('seen'), twit.id)
end

# this is very lame
def fetch_timeline(twitter, perpage, max)
    log "T fetching current timeline"
    fetched = 0
    page = 1
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
    tl = fetch_timeline(twitter, $options[:page], $options[:max])
    log "Y timeline fetched successfully, #{tl.size} items"

# FIXME need to check if we have a gap between this fetch and the previous

    posts = []

    tl.reverse.each do |s|
        status = seen(s)
        if status == false then
            log "N +/#{s.id} #{s.user.name} #{s.text[0..6]}..."
            ts = Time.parse(s.created_at)
            s.created_at = ts
# convert @mentions into links to twitter pages
            s.text.gsub!(/@(\w+)/) {|i| "<a href='http://twitter.com/#{$1}/'>@#{$1}</a>"}
            j = {
                :status_id => s.id, :when => s.created_at, :favorited => s.favorited, 
                :protected => s.protected, :from_screen => s.user.screen_name, 
                :from_name => s.user.name, :to_screen => s.in_reply_to_screen_name,
                :to_id => s.in_reply_to_status_id, :text => s.text, :source => s.source,
                :avatar => s.user.profile_image_url
            }
            q = j.to_a.flatten
            $redis.hmset(dbkey("twit:"+s.id.to_s), *q)
            queue = $redis.get(dbkey('curqueue')) || 0
            $redis.sadd(dbkey('q:'+queue.to_s), s.id.to_s)
            update_seen(s)
        end
    end
