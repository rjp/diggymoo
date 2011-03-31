#! /usr/bin/env ruby
require 'rubygems'
require 'diggymoo'
require 'haml'
require 'mash'

path_to_email = File.expand_path(File.dirname(__FILE__) + "/../email.txt")
template = File.read(path_to_email)
engine = Haml::Engine.new(template)

# fix for ruby's utterly braindead timeout handling
# http://jerith.livejournal.com/40063.html

def dopp_colour(name)
    dopp = SHA1.hexdigest(name)
	r = (128 + (dopp[0..1].hex)/2).to_s(16)
	g = (128 + (dopp[2..3].hex)/2).to_s(16)
	b = (128 + (dopp[4..5].hex)/2).to_s(16)
    return [r,g,b].join()
end

queue = nil
unless $options[:queue].nil? then
    queue = $options[:queue]
else
	queue = $redis.get(dbkey('curqueue')) || 0
	$redis.incr(dbkey('curqueue'))
end
post_list = $redis.smembers(dbkey('q:'+queue.to_s))

posts = []
post_list.each do |post_id|
    o = $redis.hgetall(dbkey('twit:'+post_id.to_s))
    o['dopp'] = dopp_colour(o['from_screen'])
    URI.extract(o['text'].gsub(/href='http:/,"XX!!XX"), ['http','https']).each do |url|
        o['text'].gsub!(url, "<a href='#{url}'>#{url}</a>")
    end
    posts.push o.to_mash
end

# TODO only send out N twips at a time?

puts engine.render(Object.new, {
    :boundary => SHA1.hexdigest(posts.inspect + Time.now.to_s + $$.to_s),
    :posts => posts,
    :queue => queue
})
$redis.sadd(dbkey('processed'), queue)
