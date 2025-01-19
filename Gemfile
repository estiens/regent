# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in regent.gemspec
gemspec

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"
gem "ruby-openai", "~> 7.3.1"
gem "tty-spinner", "~> 0.9.3"
gem "pastel", "~> 0.8.0"
gem "http", "~> 5.1"
gem "httparty", "~> 0.21.0"

gem "anthropic"
gem "gemini-ai"
gem "open_router"

group :test do
  gem "vcr", "~> 6.2"
  gem "webmock", "~> 3.19"
end

group :development, :test do
  gem "pry"
end
