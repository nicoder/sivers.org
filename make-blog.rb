require 'erb'
require 'date'

def template(name)
  ERB.new(File.read("templates/#{name}.erb"))
end

@blogs = []
Dir['content/blog/20*'].each do |infile|
  /(\d{4}-\d{2}-\d{2})-(\S+)/.match File.basename(infile)
  @date = $1
  @year = @date[0,4]
  @url = $2
  lines = File.readlines(infile)
  /<!--\s+(.+)\s+-->/.match lines.shift
  @title = $1
  body = lines.join('')

  @pagetitle = "#{@title} | Derek Sivers"
  @bodyid = 'oneblog'

  # PAGE STRUCTURE
  html = template('header').result
  html << template('bloghead').result
  html << body
  html << template('blogfoot').result
  html << template('comments').result
  html << template('footer').result

  File.open("site/#{@url}", 'w') {|f| f.puts html }

  @blogs << {date: @date, url: @url, title: @title}
end
@blogs.sort_by!{|x| x[:date]}
@blogs.reverse!

# BLOG PAGE
@pagetitle = 'Derek Sivers Blog'
@bodyid = 'bloglist'
html = template('header').result
html << template('bloglist').result
html << template('footer').result
File.open('site/blog', 'w') {|f| f.puts html }

@presentations = []
Dir['content/presentations/20*'].each do |infile|
  /(\d{4}-\d{2})-(\S+)/.match File.basename(infile)
  @month = $1
  @year = @month[0,4]
  @url = $2
  lines = File.readlines(infile)
  /<!-- TITLE: (.+)\s+-->/.match lines.shift
  @title = $1
  /<!-- SUBTITLE: (.+)\s+-->/.match lines.shift
  @subhead = $1
  /<!-- MINUTES: ([0-9]+)\s+-->/.match lines.shift
  @minutes = $1
  body = lines.join('')

  @pagetitle = "#{@title} | Derek Sivers"
  @bodyid = 'prez'

  # PAGE STRUCTURE
  html = template('header').result
  html << template('prezhead').result
  html << body
  html << template('blogfoot').result
  html << template('comments').result
  html << template('footer').result

  File.open("site/#{@url}", 'w') {|f| f.puts html }

  @presentations << {date: @month, url: @url, title: @title, minutes: @minutes, subhead: @subhead}
end
@presentations.sort_by!{|x| x[:date]}
@presentations.reverse!

# PRESENTATIONS PAGE
@pagetitle = 'Derek Sivers Presentations'
@bodyid = 'presentations'
html = template('header').result
html << template('presentations').result
html << template('footer').result
File.open('site/presentations', 'w') {|f| f.puts html }

# BOOKS
@books = []
Dir['content/books/20*'].each do |infile|
  /(\d{4}-\d{2}-\d{2})-(\S+)/.match File.basename(infile)
  @date = $1
  @url = $2
  lines = File.readlines(infile)
  /^TITLE: (.+)$/.match lines.shift
  @title = $1
  /^ISBN: (\w+)$/.match lines.shift
  @isbn = $1
  /^RATING: (\d+)$/.match lines.shift
  @rating = $1
  /^SUMMARY: (.+)$/.match lines.shift
  @summary = $1
  lines.shift  # the line that says 'NOTES:'
  @notes = lines.join('')

  @pagetitle = "#{@title} | Derek Sivers"
  @bodyid = 'onebook'

  # PAGE STRUCTURE
  html = template('header').result
  html << template('book').result
  html << template('footer').result

  File.open("site/book/#{@url}", 'w') {|f| f.puts html }

  @books << {date: @date, url: @url, title: @title, isbn: @isbn, rating: @rating, summary: @summary}
end
@books.sort_by!{|x| '%02d%s' % [x[:rating], x[:date]]}
@books.reverse!

# BOOKS PAGE
@pagetitle = 'BOOKS | Derek Sivers'
@bodyid = 'booklist'
html = template('header').result
html << template('booklist').result
html << template('footer').result
File.open('site/book/index.html', 'w') {|f| f.puts html }

# TWEETS
@tweets = []
Dir['content/tweets/20*'].each do |infile|
  /^(\d{4}-\d{2}-\d{2})/.match File.basename(infile)
  date = $1
  d = Date.parse(date)
  tweet = File.read(infile).strip
  @tweets << {date: date, show_date: d.strftime('%B %-d'), show_year: d.strftime('%B %-d, %Y'), tweet: tweet}
end
@tweets.sort_by!{|x| x[:date]}
@tweets.reverse!

# TWEETS PAGE
@pagetitle = 'Derek Sivers Tweets'
@bodyid = 'tweets'
html = template('header').result
html << template('tweets').result
html << template('footer').result
File.open('site/tweets', 'w') {|f| f.puts html }

# HOME PAGE
@new_blogs = @blogs[0,6]
@new_tweets = @tweets[0,6]
@pagetitle = 'Derek Sivers'
@bodyid = 'home'
html = template('header').result
html << template('home').result
html << template('footer').result
File.open('site/home', 'w') {|f| f.puts html }

# STATIC PAGES
Dir['content/pages/*'].each do |infile|
  @uri = @bodyid = File.basename(infile)
  lines = File.readlines(infile)
  /<!--\s+(.+)\s+-->/.match lines.shift
  @title = $1
  body = lines.join('')
  @pagetitle = "#{@title} | Derek Sivers"
  html = template('header').result
  html << body
  html << template('footer').result
  File.open("site/#{@uri}", 'w') {|f| f.puts html }
end

