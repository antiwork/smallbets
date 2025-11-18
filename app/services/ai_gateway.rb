class AiGateway
  class Error < StandardError; end
  class APIError < Error; end
  class TimeoutError < Error; end

  class Configuration
    attr_accessor :api_key, :base_url, :default_model, :default_temperature

    def initialize
      @api_key = nil
      @base_url = "https://ai-gateway.vercel.sh/v1"
      @default_temperature = 0.7
    end

    def configure(api_key:, base_url: nil, default_model: nil, default_temperature: nil)
      @api_key = api_key if api_key.present?
      @base_url = base_url if base_url.present?
      @default_model = default_model if default_model.present?
      @default_temperature = default_temperature if default_temperature.present?
    end
  end

  class << self
    attr_accessor :config

    def configure(**options)
      self.config ||= Configuration.new
      config.configure(**options)
    end

    def complete(prompt:, model: nil, temperature: nil, response_format: nil, timeout: nil)
      new.complete(prompt: prompt, model: model, temperature: temperature, response_format: response_format, timeout: timeout)
    end
  end

  def initialize
    self.class.config ||= Configuration.new
    self.class.configure(
      api_key: ENV["AI_GATEWAY_API_KEY"],
      base_url: ENV.fetch("AI_GATEWAY_BASE_URL", "https://ai-gateway.vercel.sh/v1"),
      default_model: ENV.fetch("AI_GATEWAY_DEFAULT_MODEL", "anthropic/claude-haiku-4.5"),
      default_temperature: ENV.fetch("AI_GATEWAY_DEFAULT_TEMPERATURE", "0.7").to_f
    ) unless self.class.config&.api_key.present?
    
    @config = self.class.config
  end

  def complete(prompt:, model: nil, temperature: nil, response_format: nil, timeout: nil)
    raise Error, "API key not configured" unless config.api_key.present?

    request_timeout = timeout || (prompt.length > 50000 ? 120 : 30)

    client = OpenAI::Client.new(
      access_token: config.api_key,
      uri_base: config.base_url,
      request_timeout: request_timeout
    )

    model ||= config.default_model
    temperature ||= config.default_temperature

    messages = [{ role: "user", content: prompt }]

    request_params = {
      model: model,
      messages: messages,
      temperature: temperature,
      stream: false
    }

    if response_format
      request_params[:response_format] = response_format
    end

    Rails.logger.info "[AiGateway] Calling model=#{model} with prompt_length=#{prompt.length}"

    retries = 0
    max_retries = 1

    begin
      response = client.chat(
        parameters: request_params
      )

      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "[AiGateway] Retry #{retries}/#{max_retries} after timeout"
        sleep(1)
        retry
      else
        Rails.logger.error "[AiGateway] Timeout after #{max_retries} retries: #{e.message}"
        raise TimeoutError, "AI Gateway timeout: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.error "[AiGateway] API error: #{e.class} - #{e.message}"
      raise APIError, "AI Gateway error: #{e.message}"
    end
  end

  private

  attr_reader :config

  def handle_response(response)
    if response["error"]
      error_message = response["error"]["message"] || "Unknown error"
      Rails.logger.error "[AiGateway] API returned error: #{error_message}"
      raise APIError, error_message
    end

    content = response.dig("choices", 0, "message", "content")
    if content.nil?
      Rails.logger.error "[AiGateway] No content in response: #{response.inspect}"
      raise APIError, "No content in AI response"
    end

    Rails.logger.info "[AiGateway] Successfully received response (length=#{content.length})"
    content
  end
end
