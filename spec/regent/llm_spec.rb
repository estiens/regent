# frozen_string_literal: true

RSpec.describe Regent::LLM do
  let(:strict_mode) { true }
  let(:messages) { [{ role: :user, content: "What is the capital of Japan?" }] }
  let(:provider) { nil }

  subject { Regent::LLM.new(model, provider: provider, strict_mode: strict_mode) }

  before do
    ENV["ENABLED_ADAPTERS"] = nil
  end

  after do
    ENV["ENABLED_ADAPTERS"] = nil
  end

  context "Unsupported model" do
    let(:model) { "llama-3.1-8b" }

    it "raises an error if the model is not supported" do
      expect { subject }.to raise_error(Regent::LLM::ProviderNotFoundError)
    end

    context "with explicit provider" do
      before do
        ENV["ENABLED_ADAPTERS"] = "openrouter"
        ENV["OPENROUTER_API_KEY"] = "test_key"
      end

      after do
        ENV["OPENROUTER_API_KEY"] = nil
      end

      let(:provider) { Regent::LLM::OpenRouter }

      it "works with explicit provider" do
        expect { subject }.not_to raise_error
      end
    end
  end

  context "Invalid provider" do
    let(:model) { "gpt-4" }
    let(:provider) { Class.new }

    it "raises an error if provider is not a valid LLM adapter" do
      expect { subject }.to raise_error(
        ArgumentError,
        "Provider must be a subclass of Regent::LLM::Base"
      )
    end
  end

  context "Disabled adapter" do
    let(:model) { "gpt-4-turbo" }

    before do
      ENV["ENABLED_ADAPTERS"] = "anthropic,gemini"
    end

    it "raises an error if the adapter is not enabled" do
      expect { subject }.to raise_error(
        Regent::LLM::AdapterDisabledError,
        "Provider openai is disabled. Enable it in configuration first."
      )
    end

    it "works after enabling the adapter" do
      ENV["ENABLED_ADAPTERS"] = "openai,anthropic,gemini"
      expect { subject }.not_to raise_error
    end

    context "with explicit provider" do
      let(:provider) { Regent::LLM::OpenRouter }

      it "raises an error if the explicit provider is not enabled" do
        expect { subject }.to raise_error(
          Regent::LLM::AdapterDisabledError,
          "Provider openrouter is disabled. Enable it in configuration first."
        )
      end

      it "works after enabling the explicit provider" do
        ENV["ENABLED_ADAPTERS"] = "openrouter"
        ENV["OPENROUTER_API_KEY"] = "test_key"
        expect { subject }.not_to raise_error
      ensure
        ENV["OPENROUTER_API_KEY"] = nil
      end
    end
  end

  context "API key not set in environment" do
    let(:model) { "gpt-4-turbo" }

    before do
      ENV["ENABLED_ADAPTERS"] = "openai"
    end

    it "raises an error if the API key is not set" do
      original_api_key = ENV["OPENAI_API_KEY"]
      ENV["OPENAI_API_KEY"] = nil
      expect { subject }.to raise_error(Regent::LLM::APIKeyNotFoundError)
    ensure
      ENV["OPENAI_API_KEY"] = original_api_key
    end
  end

  context "API error", vcr: true do
    before do
      ENV["ENABLED_ADAPTERS"] = "openai,anthropic,gemini"
    end

    context "OpenAI" do
      let(:model) { "gpt-4.1o-mini" }
      let(:cassette) { "LLM/OpenAI/non_existent_model" }

      context "strict mode" do
        it "raises an API error" do
          expect { subject.invoke(messages) }.to raise_error(
            Regent::LLM::ApiError,
            "The model `gpt-4.1o-mini` does not exist or you do not have access to it."
          )
        end
      end

      context "non strict mode" do
        let(:strict_mode) { false }

        it "returns a result with error message" do
          result = subject.invoke(messages)
          expect(result).to be_a(Regent::LLM::Result)
          expect(result.content).to eq("The model `gpt-4.1o-mini` does not exist or you do not have access to it.")
        end
      end
    end

    context "Gemini" do
      let(:model) { "gemini-3.5-flash" }
      let(:cassette) { "LLM/Google_Gemini/non_existent_model" }

      context "strict mode" do
        it "raises an API error" do
          expect { subject.invoke(messages) }.to raise_error(
            Regent::LLM::ApiError,
            "models/gemini-3.5-flash is not found for API version v1, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods."
          )
        end
      end

      context "non strict mode" do
        let(:strict_mode) { false }

        it "returns a result with error message" do
          result = subject.invoke(messages)
          expect(result).to be_a(Regent::LLM::Result)
          expect(result.content).to eq("models/gemini-3.5-flash is not found for API version v1, or is not supported for generateContent. Call ListModels to see the list of available models and their supported methods.")
        end
      end
    end

    context "Anthropic" do
      let(:model) { "claude-4.1-haiku" }
      let(:cassette) { "LLM/Anthropic/non_existent_model" }

      context "strict mode" do
        it "raises an API error" do
          expect { subject.invoke(messages) }.to raise_error(
            Regent::LLM::ApiError,
            "system: Input should be a valid list"
          )
        end
      end

      context "non strict mode" do
        let(:strict_mode) { false }

        it "returns a result with error message" do
          result = subject.invoke(messages)
          expect(result).to be_a(Regent::LLM::Result)
          expect(result.content).to eq("system: Input should be a valid list")
        end
      end
    end
  end

  context "Missing model dependency" do
    let(:model) { "claude-3-5-sonnet-20240620" }

    before do
      ENV["ENABLED_ADAPTERS"] = "anthropic"
      allow(Regent::Logger).to receive(:warn_and_exit).and_return(true)
      allow_any_instance_of(Regent::LLM::Anthropic).to receive(:gem).with("anthropic").and_raise(Gem::LoadError)
    end

    it "warns and exists if the dependency is not installed" do
      subject

      expect(Regent::Logger).to have_received(:warn_and_exit).with(
        /\n.*In order to use .*claude-3-5-sonnet-20240620.* model you need to install .*anthropic.* gem. Please add .*gem "anthropic".* to your Gemfile.*/
      )
    end
  end
end
