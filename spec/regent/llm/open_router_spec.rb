# frozen_string_literal: true

begin
  require "open_router"
rescue LoadError
  warn "Skipping OpenRouter specs: open_router gem not available"
end

if defined?(::OpenRouter)
  RSpec.describe Regent::LLM::OpenRouter do
    let(:model) { "openai/gpt-4o" }
    let(:messages) { [{ role: :user, content: "Hello" }] }
    let(:client) { instance_double(::OpenRouter::Client) }

    subject { described_class.new(model: model) }

    before do
      allow(Regent::Configuration).to receive(:enabled_adapters).and_return(%i[openrouter])
      allow(::OpenRouter::Client).to receive(:new).and_return(client)
      allow(client).to receive(:complete).and_return(response) if defined?(response)
    end

    describe "#invoke" do
      context "when API key is not provided" do
        let(:api_key) { nil }
        before { ENV["OPENROUTER_API_KEY"] = nil }

        it "raises an APIKeyNotFoundError" do
          expect { subject.invoke(messages) }.to raise_error(
            Regent::LLM::APIKeyNotFoundError,
            "API key not found. Make sure to set OPENROUTER_API_KEY environment variable."
          )
        end
      end

      context "when making an API call" do
        let(:response) do
          {
            "choices" => [{ "message" => { "content" => "Hi there!" } }],
            "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
          }
        end

        it "makes a request with correct parameters" do
          subject.invoke(messages, temperature: 0.7, response_format: { type: "json_object" })

          expect(client).to have_received(:complete).with(
            messages,
            model: model,
            extras: {
              temperature: 0.7,
              stop: [],
              response_format: { type: "json_object" }
            }
          )
        end

        it "returns a properly formatted result" do
          result = subject.invoke(messages)

          expect(result).to be_a(Regent::LLM::Result)
          expect(result.content).to eq("Hi there!")
          expect(result.input_tokens).to eq(10)
          expect(result.output_tokens).to eq(5)
          expect(result.model).to eq(model)
        end
      end

      context "when API returns an error" do
        it "raises ApiError with the error message" do
          allow(client).to receive(:complete).and_raise(
            ::OpenRouter::Error.new("Invalid model specified")
          )

          expect { subject.invoke(messages) }.to raise_error(
            Regent::LLM::ApiError,
            "Invalid model specified"
          )
        end
      end
    end

    describe "#parse_error" do
      it "extracts error message from response body" do
        error = double(
          response: double(
            body: { error: { message: "Test error" } }.to_json
          )
        )

        expect(subject.parse_error(error)).to eq("Test error")
      end

      it "returns original message if response can't be parsed" do
        error = double(
          response: double(body: "Invalid JSON"),
          message: "Original error"
        )

        expect(subject.parse_error(error)).to eq("Original error")
      end

      it "returns original message if no response body" do
        error = double(message: "Original error")
        allow(error).to receive(:response).and_return(nil)

        expect(subject.parse_error(error)).to eq("Original error")
      end
    end
  end
end 