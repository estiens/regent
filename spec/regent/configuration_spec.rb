# frozen_string_literal: true

RSpec.describe Regent::Configuration do
  describe ".enabled_adapters" do
    before do
      ENV["ENABLED_ADAPTERS"] = nil
    end

    after do
      ENV["ENABLED_ADAPTERS"] = nil
    end

    it "returns default adapters when no env var is set" do
      expect(described_class.enabled_adapters).to match_array(described_class::DEFAULT_ADAPTERS)
    end

    it "returns specified adapters when env var is set" do
      ENV["ENABLED_ADAPTERS"] = "openai,anthropic"
      expect(described_class.enabled_adapters).to match_array(%i[openai anthropic])
    end

    it "handles whitespace and case in env var" do
      ENV["ENABLED_ADAPTERS"] = " OpenAI , ANTHROPIC "
      expect(described_class.enabled_adapters).to match_array(%i[openai anthropic])
    end

    it "filters out invalid adapters" do
      ENV["ENABLED_ADAPTERS"] = "openai,invalid,anthropic"
      expect(described_class.enabled_adapters).to match_array(%i[openai anthropic])
    end
  end

  describe ".enabled?" do
    before do
      ENV["ENABLED_ADAPTERS"] = nil
    end

    after do
      ENV["ENABLED_ADAPTERS"] = nil
    end

    context "with default configuration" do
      described_class::DEFAULT_ADAPTERS.each do |adapter|
        it "returns true for #{adapter}" do
          expect(described_class.enabled?(adapter)).to be true
        end
      end

      it "returns false for openrouter" do
        expect(described_class.enabled?(:openrouter)).to be false
      end
    end

    context "with custom configuration" do
      before do
        ENV["ENABLED_ADAPTERS"] = "openai,openrouter"
      end

      it "returns true for enabled adapters" do
        expect(described_class.enabled?(:openai)).to be true
        expect(described_class.enabled?(:openrouter)).to be true
      end

      it "returns false for disabled adapters" do
        expect(described_class.enabled?(:anthropic)).to be false
        expect(described_class.enabled?(:gemini)).to be false
      end
    end
  end
end 