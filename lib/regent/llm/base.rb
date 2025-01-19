# frozen_string_literal: true

module Regent
  class LLM
    Result = Struct.new(:model, :content, :input_tokens, :output_tokens, keyword_init: true)

    class Base
      include Concerns::Dependable

      class << self
        def enabled?
          Configuration.enabled?(adapter_name)
        end

        def adapter_name
          name.split("::").last.downcase.to_sym
        end
      end

      def initialize(model:, api_key: nil, **options)
        @model = model
        @api_key = api_key || api_key_from_env
        @options = options

        super()
      end

      def parse_error(error)
        error.response.dig(:body, "error", "message")
      end

      private

      attr_reader :model, :api_key, :options

      def result(model:, content:, input_tokens:, output_tokens:)
        Result.new(
          model: model,
          content: content,
          input_tokens: input_tokens,
          output_tokens: output_tokens
        )
      end

      def api_key_from_env
        return nil unless self.class.enabled?

        ENV.fetch(self.class::ENV_KEY) do
          raise APIKeyNotFoundError, "API key not found. Make sure to set #{self.class::ENV_KEY} environment variable."
        end
      end
    end
  end
end
