# frozen_string_literal: true
ENV['OPENAI_API_KEY'] = 'sk-...'
ENV['ANTHROPIC_API_KEY'] = 'sk-...'
ENV['GEMINI_API_KEY'] = 'AIza...'
ENV['OPENROUTER_API_KEY'] = 'sk-...'

require "regent"
require "vcr"
require "webmock/rspec"

# Conditionally require adapters for testing
begin
  require "ruby-openai"
rescue LoadError
  # OpenAI adapter not available
end

begin
  require "anthropic"
rescue LoadError
  # Anthropic adapter not available
end

begin
  require "gemini-ai"
rescue LoadError
  # Gemini adapter not available
end

begin
  require "open_router"
rescue LoadError
  # OpenRouter adapter not available
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter out sensitive data like API keys
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV['GEMINI_API_KEY'] }
  config.filter_sensitive_data('<OPENROUTER_API_KEY>') { ENV['OPENROUTER_API_KEY'] }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:each, :vcr) do |example|
    VCR.use_cassette(cassette, record: :new_episodes) { example.call }
  end
end
