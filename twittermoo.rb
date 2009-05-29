require 'rubygems'
require 'twitter'
require 'gdbm'
require 'sha1'
require 'optparse'
require 'socket'

$options = {
    :host => 'localhost',
    :port => nil,
    :dbfile => ENV['HOME'] + '/.twittermoo.db',
    :config => ENV['HOME'] + '/.twittermoo',
    :verbose => nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: twittermoo.rb [-v] [-p port] [-h host] [-d dbfile] [-c config]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    puts "verbose is set to #{v}"
    $options[:verbose] = v
  end

  opts.on("-p", "--port N", Integer, "irccat port") do |p|
    puts "port is set to #{p}"
    $options[:port] = p
  end

  opts.on("-d", "--dbfile DBFILE", String, "dbfile") do |p|
    puts "dbfile is set to #{p}"
    $options[:dbfile] = p
  end

  opts.on("-h", "--host HOST", String, "host") do |p|
    puts "host is set to #{p}"
    $options[:host] = p
  end

  opts.on("-c", "--config CONFIG", String, "config file") do |p|
    puts "config is set to #{p}"
    $options[:config] = p
  end
end.parse!

p $options
p ARGV

unless $options[:port].nil? then
    $socket = TCPSocket.new($options[:host], $options[:port])
end

def send_message(x)
    if $options[:port].nil? then
        puts "! #{x}"
    else
        $socket.puts(x)
    end
end

config = YAML::load(open($options[:config]))
 
httpauth = Twitter::HTTPAuth.new(config['email'], config['password'])
twitter = Twitter::Base.new(httpauth)

already_seen = GDBM.new($options[:dbfile])

puts "B fetching current timeline and ignoring"
twitter.friends_timeline().each do |s|
    sha1 = SHA1.hexdigest(s.text + s.user.name)
    xtime = Time.parse(s.created_at)
    threshold = Time.now - 3600
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
                    send_message(output)
                else
                    puts "- #{output}"
                end
            else
    	        puts "+ #{output}"
                if output.length > 250 then
                    $stderr.puts "#{output[0..250]}..."
                    exit;
                end
                send_message(output)
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
}


