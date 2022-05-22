# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in trello_tool.gemspec
gemspec

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

if ENV["TEST_PSYCH_ON"] == "3"
  gem "psych", "< 4"
elsif ENV["TEST_PSYCH_ON"] == "4"
  gem "psych", "> 3"
end
