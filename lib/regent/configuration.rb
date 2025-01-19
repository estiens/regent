# frozen_string_literal: true

module Regent
  class Configuration
    AVAILABLE_ADAPTERS = %i[openai anthropic gemini openrouter].freeze
    DEFAULT_ADAPTERS = %i[openai anthropic gemini].freeze
    attr_accessor :enabled_adapters

    def self.enabled_adapters
      return DEFAULT_ADAPTERS unless ENV.key?('ENABLED_ADAPTERS')

      enabled = ENV['ENABLED_ADAPTERS'].split(',').map(&:strip).map(&:downcase).map(&:to_sym)
      enabled.select { |adapter| AVAILABLE_ADAPTERS.include?(adapter) }
    end

    def self.enabled?(adapter)
      enabled_adapters.include?(adapter)
    end
  end
end

