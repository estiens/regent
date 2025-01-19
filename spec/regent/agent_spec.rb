# frozen_string_literal: true


RSpec.describe Regent::Agent, :vcr do
  let(:llm) { Regent::LLM.new(model) }
  let(:agent) { Regent::Agent.new("You are an AI agent", model: llm) }
  let(:tool) { PriceTool.new(name: 'price_tool', description: 'Get the price of cryptocurrencies') }
  let(:spinner) { double("spinner", auto_spin: nil, update: nil, success: nil, error: nil) }
  
  class PriceTool < Regent::Tool
    def call(query)
      "{'BTC': '$107,000', 'ETH': '$6,000'}"
    end
  end

  RSpec.shared_examples "an LLM agent" do |provider|
    before do
      allow(Regent::Configuration).to receive(:enabled_adapters).and_return(%i[openai anthropic gemini openrouter])
    end

    context "without a tool" do
      let(:cassette) { "Regent_Agent/#{provider}/answers_a_basic_question" }

      it "answers a basic question" do
        response = agent.run("What is the capital of Japan?")
        expect(response).to include("Tokyo")
      end

      it "stores messages within a session" do
        agent.run("What is the capital of Japan?")
        messages = agent.session.messages

        expect(messages.first[:role]).to eq(:system)
        expect(messages.first[:content]).to eq(Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", ""))
        expect(messages[1][:role]).to eq(:user)
        expect(messages[1][:content]).to eq("What is the capital of Japan?")
        expect(messages.last[:role]).to eq(:assistant)
        expect(messages.last[:content]).to include("Tokyo")
      end

      it "stores session history" do
        agent.run("What is the capital of Japan?")

        expect(agent.session.spans.count).to eq(3)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans.first.output).to eq("What is the capital of Japan?")
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
        expect(agent.session.spans.last.output).to include("Tokyo")
      end

      context "logging" do
        before do
          allow(TTY::Spinner).to receive(:new).and_return(spinner)
        end

        it "logs steps in the console" do
          agent.run("What is the capital of Japan?")

          # Input
          expect(spinner).to have_received(:update).with(
            title: /\[.*?INPUT.*?\].*?What is the capital of Japan\?/
          ).exactly(2).times

          # LLM Call
          expect(spinner).to have_received(:update).with(
            title: /\[.*?LLM.*?❯.*?#{model}.*?\].*?What is the capital of Japan\?/
          ).exactly(2).times

          # Answer
          expect(spinner).to have_received(:update).with(
            title: /\[.*?ANSWER.*?\].*?\[.*?0\.\d*s.*?\].*?Tokyo/
          ).exactly(2).times
        end
      end
    end

    context "with a tool" do
      let(:cassette) { "Regent_Agent/#{provider}/answers_a_question_with_a_tool" }
      let(:agent) { Regent::Agent.new("You are an AI agent", model: llm, tools: [tool]) }

      it "answers a question with a tool" do
        expect(agent.run("What is the price of Bitcoin?")).to include("$107,000")
        expect(agent.run("What is the price of Ethereum?")).to include("$6,000")
      end

      it "stores messages within a session" do
        agent.run("What is the price of Bitcoin?")
        messages = agent.session.messages

        expect(messages.first[:role]).to eq(:system)
        expect(messages.first[:content]).to eq(Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "price_tool - Get the price of cryptocurrencies"))
        expect(messages[1][:role]).to eq(:user)
        expect(messages[1][:content]).to eq("What is the price of Bitcoin?")
        expect(messages[2][:role]).to eq(:assistant)
        expect(messages[2][:content]).to include("price_tool")
        expect(messages[3][:role]).to eq(:user)
        expect(messages[3][:content]).to include("$107,000")
      end

      it "stores session history" do
        agent.run("What is the price of Bitcoin?")

        expect(agent.session.spans.count).to eq(5)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[2].type).to eq(Regent::Span::Type::TOOL_EXECUTION)
        expect(agent.session.spans[3].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
      end
    end
  end

  context "OpenAI" do
    let(:model) { "gpt-4o-mini" }
    include_examples "an LLM agent", "OpenAI"
  end

  context "Anthropic" do
    let(:model) { "claude-3-5-sonnet-20240620" }
    include_examples "an LLM agent", "Anthropic"
  end

  context "Google Gemini" do
    let(:model) { "gemini-1.5-pro-002" }
    include_examples "an LLM agent", "Google_Gemini"
  end

  context "OpenRouter" do
    let(:model) { "openrouter/auto" }
    include_examples "an LLM agent", "OpenRouter"
  end

  context "allows tools to be defined in the agent class" do
    let(:model) { "gpt-4o-mini" }
    let(:cassette) { "Regent_Agent/function_tools/answers_a_question_with_a_tool" }

    context "with tool definition missing" do
      subject { InvalidWeatherAgent.new("You are a weather tool", model: Regent::LLM.new(model))}
      class InvalidWeatherAgent < Regent::Agent
        tool(:get_weather, "Get the weather for a given location")
      end

      it "raises an error" do
        expect{ subject }.to raise_error("A tool method 'get_weather' is missing in the InvalidWeatherAgent")
      end
    end

    context "properly defined tool" do
      let(:agent) { ValidWeatherAgent.new("You are a weather tool", model: Regent::LLM.new(model)) }

      class ValidWeatherAgent < Regent::Agent
        tool(:get_weather, "Get the weather for a given location")

        def get_weather(location)
          "The weather in #{location} is 70 degrees and sunny."
        end
      end

      it "allows tools to be defined in the agent class" do
        expect(agent.run("What is the weather in San Francisco?")).to eq("It is 70 degrees and sunny in San Francisco.")
      end
    end
  end
end
