require 'httparty'

class ContractAiService
  include HTTParty
  
  CHATGPT_API_URL = 'https://api.openai.com/v1/chat/completions'
  MARKETINCER_API_URL = 'https://api.marketincer.com/api/v1/contracts/generate'
  
  def initialize(contract)
    @contract = contract
  end
  
  def process_contract
    begin
      @contract.update(status: 'processing')
      
      # Send to ChatGPT/OpenAI
      ai_response = send_to_chatgpt(@contract.description)
      
      # Update contract with AI response
      @contract.update(ai_response: ai_response)
      
      # Send to marketincer API
      send_to_marketincer_api(ai_response)
      
      @contract.update(status: 'completed')
      
    rescue => e
      @contract.update(status: 'failed', ai_response: "Error: #{e.message}")
      raise e
    end
  end
  
  private
  
  def send_to_chatgpt(description)
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{ENV['OPENAI_API_KEY']}"
    }
    
    body = {
      model: 'gpt-3.5-turbo',
      messages: [
        {
          role: 'system',
          content: 'You are an AI assistant that helps with contract generation and analysis. Please analyze the following contract description and provide a comprehensive response.'
        },
        {
          role: 'user',
          content: description
        }
      ],
      max_tokens: 1000,
      temperature: 0.7
    }
    
    response = HTTParty.post(
      CHATGPT_API_URL,
      headers: headers,
      body: body.to_json
    )
    
    if response.success?
      response.parsed_response.dig('choices', 0, 'message', 'content')
    else
      raise "ChatGPT API Error: #{response.code} - #{response.message}"
    end
  end
  
  def send_to_marketincer_api(ai_response)
    headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
    
    body = {
      contract_id: @contract.id,
      user_id: @contract.user_id,
      original_description: @contract.description,
      ai_response: ai_response,
      status: @contract.status,
      timestamp: Time.current.iso8601
    }
    
    response = HTTParty.post(
      MARKETINCER_API_URL,
      headers: headers,
      body: body.to_json
    )
    
    unless response.success?
      raise "Marketincer API Error: #{response.code} - #{response.message}"
    end
    
    response.parsed_response
  end
end