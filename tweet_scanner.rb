#!/usr/bin/env ruby
#
# Tweet Scanner
# Created by Caius Durling on 2011-03-18.
# 
# Searches twitter and saves search results in a sqlite db
# 
# USAGE
# 
# ruby tweet_scanner.rb --search caius
#   # => creates caius.sqlite3 and stores the tweets matching "caius" in it
# 
# CHANGELOG
# 
#   v0.1.0 - Initial release
# 

require "rubygems"
gem "twitter", ">= 1.1.2"
require "twitter"
gem "sequel", ">= 3.17.0"
require "sequel"
require "optparse"
require "ostruct"

def databaseify search_query
  "#{search_query.gsub(/\W/, "-").gsub(/-{2,}/, "-")}.sqlite3"
end

@config = OpenStruct.new

OptionParser.new do |opt|
  opt.banner = "USAGE: tweet_scanner.rb [OPTIONS]"

  opt.on("-s", "--search [TERM]") do |search|
    @config.search_terms = search
  end

  opt.on("-t", "--hashtag [TERM]") do |hashtag|
    @config.hashtag = hashtag
  end
end.parse!

if @config.hashtag && @config.search_terms
  puts "Error: either specify --hashtag OR --search, not both."
  exit(1)
end

unless @config.hashtag || @config.search_terms
  puts "Error: you need to specify either --hashtag or --search."
  exit(1)
end

db_file = databaseify(@config.hashtag || @config.search_terms)

DB = Sequel.sqlite db_file

unless File.exists?(db_file)
  DB.create_table :tweets do
    primary_key :id
    Integer :status_id, :unique => true, :null => false
    String :username, :null => false
    String :body, :null => false
    DateTime :created_at
    DateTime :tweeted_at
  end
end

@s = Twitter::Search.new

@s = if @config.hashtag
  @s.hashtag(@config.hashtag)
else
  @s.containing(@config.search_terms)
end

@s.per_page(100).each do |t|
  begin
    DB[:tweets].insert(
      :status_id => t.id,
      :username => t.from_user.to_s,
      :body => t.text,
      :created_at => Time.now,
      :tweeted_at => t.created_at
    )
  rescue Sequel::DatabaseError => e
    if e.message =~ /column status_id/
      # Already exists, shucks.
    else
      raise
    end
  end
end
