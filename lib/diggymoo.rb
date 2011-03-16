require 'rubygems'
require 'thread'
require 'twitter'
require 'sha1'
require 'optparse'
require 'socket'
require 'json'
require 'redis'

$options = {
    :once => true,
    :dbfile => ENV['USER'] + ':diggymoo',
    :config => ENV['HOME'] + '/.twittermoo',
    :email => ENV['USER'] + '@browser.org', # hopefully a safe default
    :verbose => nil,
    :queue => nil,
    :max => 100,    # the maximum number to look back
    :page => 20     # how many to fetch at a time
}

OptionParser.new do |opts|
  opts.banner = "Usage: twittermoo.rb [-v] [-p port] [-h host] [-d dbfile] [-c config] [-o] [-w N] [-p N] [-e N]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    $options[:verbose] = v
  end

  opts.on("-m", "--max N", Integer, "Maximum number of tweets to consider") do |p|
    $options[:max] = p
  end

  opts.on("-q", "--queue N", Integer, "Which queue to process") do |p|
    $options[:queue] = p
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

  opts.on("-e", "--email EMAIL", String, "email") do |p|
    $options[:email] = p
  end

end.parse!

# TODO move this to something like log4r if they have it
def log(x)
    if $options[:verbose] then
        puts *x
    end
end

config = YAML::load(open($options[:config]))

# allow settings of options from the config file
unless config['options'].nil? then
    $options.merge!(config['options'])
end

def dbkey(x)
    return $options[:dbfile] + ":#{x}"
end

$redis = Redis.new
