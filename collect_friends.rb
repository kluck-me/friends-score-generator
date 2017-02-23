require 'dotenv/load'
require 'twitter'

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
  sleep error.rate_limit.reset_in
  retry
end

ARGV.each do |screen_name|
  open("friends_#{screen_name}.txt", 'w') do |f|
    followings_of(screen_name, client).each do |user|
      f.puts user.screen_name
    end
  end
end
