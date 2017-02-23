require 'cgi'
require 'stringio'
require 'zlib'

FORMATS = %w(text html code)
format = FORMATS.first
files = {}
file_score = 1
ARGV.each do |arg|
  if arg.start_with?('--')
    arg = arg[2..-1]
    format = arg if FORMATS.include?(arg)
  else
    begin
      file_score = Float(arg)
    rescue ArgumentError
      files[File.expand_path(arg)] ||= file_score
    end
  end
end
format = format.to_sym

friends = Hash.new(0)
files.each do |path, score|
  users = File.read(path).each_line.map(&:strip)
  users.each { |user| friends[user] += score }
end

special_users = []
special_users.each { |user| friends[user] = 5 }

scoring_friends = friends.group_by(&:last).to_a.sort_by(&:first)
scoring_friends.each { |pair| pair.last.map!(&:first) }

def tag(*args)
  sio = args.first.is_a?(StringIO) ? args.shift : StringIO.new
  name = args.shift
  remove_bs = name.start_with?('-')
  remove_as = name.end_with?('-')
  name.gsub!(/\A-|-\z/, '')
  attrs = {}
  attrs.merge!(args.shift) while args.first.is_a?(Hash)
  str_attrs = attrs.map { |k, v| " #{k}=\"#{CGI.escapeHTML(v)}\"" }.join
  sio.print "<#{name}#{str_attrs}>"
  if block_given?
    sio.puts '' unless remove_bs
    yield(sio)
  else
    args.each { |arg| sio.print CGI.escapeHTML(arg) }
  end
  sio.send(remove_as ? :print : :puts, "</#{name}>")
  sio.string
end

case format
when :code
  code = 1.upto(10).map do |score|
    score /= 2.0
    _, users = scoring_friends.find { |pair| pair.first == score }
    (users || []).map { |user| format('%08x', Zlib.crc32(user)) }.uniq.join
  end.join('x')
  puts code
  # decode sample
  hashed_scoring_users = {}.tap do |h|
    code.split('x').each_with_index do |hashes, score|
      score = (score + 1) / 2.0
      hashes.scan(/.{8}/) do |hash|
        h[hash] = score
      end
    end
  end
  friends.each do |user, score|
    hash_user = ('0' * 8 + Zlib.crc32(user).to_s(16))[-8..-1]
    next if hashed_scoring_users[hash_user] == score
    raise "#{user} (#{score}) != #{hash_user} (#{hashed_scoring_users[hash_user]})"
  end
when :html
  html = tag('body') do |sio|
    scoring_friends.map do |score, users|
      tag(sio, 'h1', format('%.1f', score))
      tag sio, 'ul' do
        users.each do |user|
          tag sio, '-li' do
            tag sio, 'a-', { href: "https://twitter.com/#{user}" }, user
          end
        end
      end
    end
  end
  print html
else
  scoring_friends.each do |score, users|
    puts format('# %.1f', score)
    users.each { |user| puts user }
    puts ''
  end
end
