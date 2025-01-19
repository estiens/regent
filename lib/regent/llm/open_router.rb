# frozen_string_literal: true
require 'pry'
module Regent
  class LLM
    class OpenRouter < Base
      ENV_KEY = "OPENROUTER_API_KEY"

      depends_on "open_router"

      def invoke(messages, **args)
        raise APIKeyNotFoundError, "API key not found. Make sure to set #{self.class::ENV_KEY} environment variable." unless api_key

        response = client.complete(
          messages,
          model: model,
          extras: {
            temperature: args[:temperature] || 0.0,
            stop: args[:stop] || [],
            **args
          }
        )

        result(
          model: model,
          content: response.dig("choices", 0, "message", "content"),
          input_tokens: response.dig("usage", "prompt_tokens"),
          output_tokens: response.dig("usage", "completion_tokens")
        )
      rescue ::OpenRouter::Error => e
        raise ApiError, parse_error(e)
      end

      def parse_error(error)
        return error.message if error.respond_to?(:message)
        return error.dig("message") if error.respond_to?(:[])
        
        return JSON.parse(error.response.body).dig("error", "message") if error.response&.body

        error.to_s
      rescue JSON::ParserError
        error.message
      end

      private

      def client
        return @client if @client
        
        configure_client
        @client = ::OpenRouter::Client.new
      end

      def configure_client
        ::OpenRouter.configure do |config|
          config.access_token = ENV[ENV_KEY]
          config.site_name = referrer if referrer
          config.site_url = site_url if site_url
        end
      end

      def referrer
        ENV.fetch("SITE_NAME", nil)
      end

      def site_url
        ENV.fetch("SITE_URL", nil)
      end
    end
  end
end 