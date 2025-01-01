# frozen_string_literal: true

module Regent
  class LLM
    class OpenAI < Base
      ENV_KEY = "OPENAI_API_KEY"

      depends_on "ruby-openai"

      def invoke(messages, **args)
        response = client.chat(parameters: {
          messages: messages,
          model: model,
          temperature: args[:temperature] || 0.0,
          stop: args[:stop]
        })

        result(
          model: model,
          content: response.dig("choices", 0, "message", "content"),
          input_tokens: response.dig("usage", "prompt_tokens"),
          output_tokens: response.dig("usage", "completion_tokens")
        )
      end

      private

      def client
        @client ||= ::OpenAI::Client.new(access_token: api_key)
      end
    end
  end
end
