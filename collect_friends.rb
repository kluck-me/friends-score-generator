require 'dotenv/load'
require 'twitter'
require 'fileutils'

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['CONSUMER_KEY']
  config.consumer_secret     = ENV['CONSUMER_SECRET']
  config.access_token        = ENV['ACCESS_TOKEN']
  config.access_token_secret = ENV['ACCESS_TOKEN_SECRET']
end

def followings_of(screen_name, client)
  following_ids = client.friend_ids(screen_name).to_a
  following_ids.each_slice(100).to_a.inject ([]) do |users, ids|
    users.concat(client.users(ids))
  end
rescue Twitter::Error::TooManyRequests => error
  STDERR.puts "sleep #{error.rate_limit.reset_in}s"
  sleep error.rate_limit.reset_in
  retry
end

FileUtils.rm_rf('.friends')
FileUtils.mkdir_p('.friends')
ARGV.each do |arg|
  name, _ = arg.split('-', 2)
  open(".friends/#{arg}", 'w') do |f|
    STDERR.puts "get #{name}'s friends"
    followings_of(name, client).each do |user|
      f.puts user.screen_name
    end
  end
end
