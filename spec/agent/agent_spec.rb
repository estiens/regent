# frozen_string_literal: true

RSpec.describe Regent::Agent, :vcr do
  let(:llm) { Regent::LLM.new(model) }
  let(:agent) { Regent::Agent.new("You are an AI agent", llm: llm) }
  let(:tool) { PriceTool.new(name: 'price_tool', description: 'Get the price of cryptocurrencies') }

  class PriceTool < Regent::Tool
    def call(query)
      "{'BTC': '$107,000', 'ETH': '$6,000'}"
    end
  end

  context "OpenAI" do
    let(:model) { "gpt-4o-mini" }

    context "without a tool" do
      let(:cassette) { "Regent_Agent/OpenAI/answers_a_basic_question" }

      it "answers a basic question" do
        expect(agent.execute("What is the capital of Japan?")).to eq("The capital of Japan is Tokyo.")
      end

      it "stores messages within a session" do
        agent.execute("What is the capital of Japan?")

        expect(agent.session.messages).to eq([
          { role: :system, content: Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "") },
          { role: :user, content: "What is the capital of Japan?" },
          { role: :assistant, content: "Thought: I need to find out what the capital of Japan is. \nAction: I will recall my knowledge about countries and their capitals. \nObservation: The capital of Japan is Tokyo. \n\nThought: I have the answer now.\nAnswer: The capital of Japan is Tokyo." }
        ])
      end

      it "stores session history" do
        agent.execute("What is the capital of Japan?")

        expect(agent.session.spans.count).to eq(3)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans.first.output).to eq("What is the capital of Japan?")
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[1].output).to eq("Thought: I need to find out what the capital of Japan is. \nAction: I will recall my knowledge about countries and their capitals. \nObservation: The capital of Japan is Tokyo. \n\nThought: I have the answer now.\nAnswer: The capital of Japan is Tokyo.")

        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
        expect(agent.session.spans.last.output).to eq("The capital of Japan is Tokyo.")
      end
    end

    context "with a tool" do
      let(:cassette) { "Regent_Agent/OpenAI/answers_a_question_with_a_tool" }
      let(:agent) { Regent::Agent.new("You are an AI agent", llm: llm, tools: [tool]) }

      it "answers a question with a tool" do
        expect(agent.execute("What is the price of Bitcoin?")).to eq("The price of Bitcoin is $107,000.")
        expect(agent.execute("What is the price of Ethereum?")).to eq("The price of Ethereum is $6,000.")
      end

      it "stores messages within a session" do
        agent.execute("What is the price of Bitcoin?")

        expect(agent.session.messages).to eq([
          { role: :system, content: Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "price_tool - Get the price of cryptocurrencies") },
          { role: :user, content: "What is the price of Bitcoin?" },
          { role: :assistant, content: "Thought: I need to find the current price of Bitcoin. \nAction: price_tool | \"Bitcoin\"\nPAUSE" },
          { role: :user, content: "Observation: {'BTC': '$107,000', 'ETH': '$6,000'}" },
          { role: :assistant, content: "Thought: I have the current price of Bitcoin, which is $107,000. \nAnswer: The price of Bitcoin is $107,000." }
        ])
      end

      it "stores session history" do
        agent.execute("What is the price of Bitcoin?")

        expect(agent.session.spans.count).to eq(5)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[2].type).to eq(Regent::Span::Type::TOOL_EXECUTION)
        expect(agent.session.spans[3].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
      end
    end
  end

  context "Anthropic" do
    let(:model) { "claude-3-5-sonnet-20240620" }

    context "without a tool" do
      let(:cassette) { "Regent_Agent/Anthropic/answers_a_basic_question" }

      it "answers a basic question" do
        expect(agent.execute("What is the capital of Japan?")).to eq("The capital of Japan is Tokyo.\n\nTokyo has been the capital of Japan since 1868, when it replaced the former capital, Kyoto. It is not only the political center of Japan but also its economic and cultural hub, being one of the world's largest and most populous metropolitan areas.")
      end

      it "stores messages within a session" do
        agent.execute("What is the capital of Japan?")

        expect(agent.session.messages).to eq([
          { role: :system, content: Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "") },
          { role: :user, content: "What is the capital of Japan?" },
          { role: :assistant, content: "Thought: To answer this question, I need to recall basic geographical knowledge about Japan. This is a straightforward factual question that doesn't require any special tools or complex reasoning.\n\nAnswer: The capital of Japan is Tokyo.\n\nTokyo has been the capital of Japan since 1868, when it replaced the former capital, Kyoto. It is not only the political center of Japan but also its economic and cultural hub, being one of the world's largest and most populous metropolitan areas." }
        ])
      end

      it "stores session history" do
        agent.execute("What is the capital of Japan?")

        expect(agent.session.spans.count).to eq(3)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans.first.output).to eq("What is the capital of Japan?")
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[1].output).to eq("Thought: To answer this question, I need to recall basic geographical knowledge about Japan. This is a straightforward factual question that doesn't require any special tools or complex reasoning.\n\nAnswer: The capital of Japan is Tokyo.\n\nTokyo has been the capital of Japan since 1868, when it replaced the former capital, Kyoto. It is not only the political center of Japan but also its economic and cultural hub, being one of the world's largest and most populous metropolitan areas.")

        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
        expect(agent.session.spans.last.output).to eq("The capital of Japan is Tokyo.\n\nTokyo has been the capital of Japan since 1868, when it replaced the former capital, Kyoto. It is not only the political center of Japan but also its economic and cultural hub, being one of the world's largest and most populous metropolitan areas.")
      end
    end

    context "with a tool" do
      let(:cassette) { "Regent_Agent/Anthropic/answers_a_question_with_a_tool" }
      let(:agent) { Regent::Agent.new("You are an AI agent", llm: llm, tools: [tool]) }

      it "answers a question with a tool" do
        expect(agent.execute("What is the price of Bitcoin?")).to eq("The current price of Bitcoin (BTC) is $107,000.")
        expect(agent.execute("What is the price of Ethereum?")).to eq("The current price of Ethereum (ETH) is $6,000.")
      end

      it "stores messages within a session" do
        agent.execute("What is the price of Bitcoin?")

        expect(agent.session.messages).to eq([
          { role: :system, content: Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "price_tool - Get the price of cryptocurrencies") },
          { role: :user, content: "What is the price of Bitcoin?" },
          { role: :assistant, content: "Thought: To answer this question, I need to get the current price of Bitcoin. I can use the price_tool to obtain this information.\n\nAction: price_tool | Bitcoin\n" },
          { role: :user, content: "Observation: {'BTC': '$107,000', 'ETH': '$6,000'}" },
          { role: :assistant, content: "Thought: I have received the price information for Bitcoin (BTC) and Ethereum (ETH). The question specifically asked about Bitcoin, so I'll focus on that.\n\nAnswer: The current price of Bitcoin (BTC) is $107,000." }
        ])
      end

      it "stores session history" do
        agent.execute("What is the price of Bitcoin?")

        expect(agent.session.spans.count).to eq(5)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[2].type).to eq(Regent::Span::Type::TOOL_EXECUTION)
        expect(agent.session.spans[3].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
      end
    end
  end

  context "Google Gemini" do
    let(:model) { "gemini-1.5-pro-002" }

    context "without a tool" do
      let(:cassette) { "Regent_Agent/Google_Gemini/answers_a_basic_question" }

      it "answers a basic question" do
        expect(agent.execute("What is the capital of Japan?")).to eq("Tokyo")
      end

      it "stores messages within a session" do
        agent.execute("What is the capital of Japan?")

        expect(agent.session.messages).to eq([
          { role: :system, content: Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "") },
          { role: :user, content: "What is the capital of Japan?" },
          { role: :assistant, content: "Thought: I know the capital of Japan.\nAnswer: Tokyo" }
        ])
      end

      it "stores session history" do
        agent.execute("What is the capital of Japan?")

        expect(agent.session.spans.count).to eq(3)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans.first.output).to eq("What is the capital of Japan?")
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[1].output).to eq("Thought: I know the capital of Japan.\nAnswer: Tokyo")

        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
        expect(agent.session.spans.last.output).to eq("Tokyo")
      end
    end

    context "with a tool" do
      let(:cassette) { "Regent_Agent/Google_Gemini/answers_a_question_with_a_tool" }
      let(:agent) { Regent::Agent.new("You are an AI agent", llm: llm, tools: [tool]) }

      it "answers a question with a tool" do
        expect(agent.execute("What is the price of Bitcoin?")).to eq("The price of Bitcoin is $107,000.")
        expect(agent.execute("What is the price of Ethereum?")).to eq("The price of Ethereum is $6,000.")
      end

      it "stores messages within a session" do
        agent.execute("What is the price of Bitcoin?")

        expect(agent.session.messages).to eq([
          { role: :system, content: Regent::Engine::React::PromptTemplate.system_prompt("You are an AI agent", "price_tool - Get the price of cryptocurrencies") },
          { role: :user, content: "What is the price of Bitcoin?" },
          { role: :assistant, content: "Thought: I need to find the current price of Bitcoin.\nAction: price_tool | Bitcoin\nPAUSE" },
          { role: :user, content: "Observation: {'BTC': '$107,000', 'ETH': '$6,000'}" },
          { role: :assistant, content: "Thought: I have the price of Bitcoin.\nAnswer: The price of Bitcoin is $107,000." }
        ])
      end

      it "stores session history" do
        agent.execute("What is the price of Bitcoin?")

        expect(agent.session.spans.count).to eq(5)
        expect(agent.session.spans.first.type).to eq(Regent::Span::Type::INPUT)
        expect(agent.session.spans[1].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans[2].type).to eq(Regent::Span::Type::TOOL_EXECUTION)
        expect(agent.session.spans[3].type).to eq(Regent::Span::Type::LLM_CALL)
        expect(agent.session.spans.last.type).to eq(Regent::Span::Type::ANSWER)
      end
    end
  end
end
