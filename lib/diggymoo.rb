require 'rubygems'
require 'thread'
require 'twitter'
require 'sha1'
require 'optparse'
require 'socket'
require 'json'
require 'redis'
require 'etc'

# try to make a prefix based on our user name/id
myusername = ENV['USER'] || Etc.getpwuid.name || '#'<<Process.uid.to_s

if myusername.nil? then
    $stderr.puts "Cannot find who you are, cannot continue!"
    exit 1
end

$options = {
    :once => true,
    :dbfile => nil,
    :config => ENV['HOME'] + '/.diggymoo',
    :email => myusername + '@browser.org', # hopefully a safe default
    :user => myusername,
    :verbose => nil,
    :queue => nil,
    :list => nil,
    :max => 100,    # the maximum number to look back
    :page => 20     # how many to fetch at a time

}

OptionParser.new do |opts|
  opts.banner = "Usage: diggymoo.rb [-v] [-l list] [-d dbkey] [-c config] [-o] [-w N] [-p N] [-e N]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    $options[:verbose] = v
  end

  opts.on("-l", "--list LIST", String, "Twitter List") do |v|
    $options[:list] = v
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
    key = [$options[:user], 'diggymoo', $options[:dbfile], x].compact.join(':')
    return key
end

$redis = Redis.new
