# frozen_string_literal: true

module Regent
  class LLM
    DEFAULT_RETRY_COUNT = 3
    PROVIDER_PATTERNS = {
      OpenAI: /^gpt-/,
      Gemini: /^gemini-/,
      Anthropic: /^claude-/
    }.freeze

    class ProviderNotFoundError < StandardError; end
    class APIKeyNotFoundError < StandardError; end
    class ApiError < StandardError; end
    class AdapterDisabledError < StandardError; end

    PROVIDER_MAPPING = {
      /^gpt-|^text-davinci-|^openai/ => OpenAI,
      /^claude-|^anthropic/ => Anthropic,
      /^gemini/ => Gemini,
      /^openrouter/ => OpenRouter
    }.freeze

    def initialize(model, provider: nil, strict_mode: true, **options)
      @model = model
      @strict_mode = strict_mode
      @options = options
      @provider = initialize_provider(provider)
    end

    attr_reader :model, :options

    def invoke(messages, **args)
      retries = 0

      messages = [{ role: "user", content: messages }] if messages.is_a?(String)

      @provider.invoke(messages, **args)

    rescue Faraday::Error => error
      if error.respond_to?(:retryable?) && error.retryable? && retries < DEFAULT_RETRY_COUNT
        sleep(exponential_backoff(retries))
        retry
      end
      handle_error(error)
    end

    private

    attr_reader :provider, :strict_mode

    def initialize_provider(provider_class)
      provider_class = detect_provider if provider_class.nil?
      validate_provider!(provider_class)

      provider_class.new(**options.merge(
        model: model,
        provider: provider_class
      ))
    end

    def detect_provider
      provider_class = PROVIDER_MAPPING.find { |pattern, _| pattern.match?(model) }&.last
      raise ProviderNotFoundError, "No provider found for model #{model}" unless provider_class
      provider_class
    end

    def validate_provider!(provider_class)
      unless provider_class.ancestors.include?(Regent::LLM::Base)
        raise ArgumentError, "Provider must be a subclass of Regent::LLM::Base"
      end

      unless provider_class.enabled?
        raise AdapterDisabledError, "Provider #{provider_class.adapter_name} is disabled. Enable it in configuration first."
      end
    end

    def handle_error(error)
      message = provider.parse_error(error) || error.message
      raise ApiError, message if strict_mode
      Result.new(model: model, content: message, input_tokens: nil, output_tokens: nil)
    end

    def exponential_backoff(retry_count)
      # Exponential backoff with jitter: 2^n * 100ms + random jitter
      (2**retry_count * 0.1) + rand(0.1)
    end
  end
end
