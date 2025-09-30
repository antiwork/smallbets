require "net/http"
require "restricted_http/private_network_guard"

class Opengraph::Fetch
  ALLOWED_DOCUMENT_CONTENT_TYPE = "text/html"
  MAX_BODY_SIZE = 5.megabytes
  MAX_REDIRECTS = 10
  
  class TooManyRedirectsError < StandardError; end
  class RedirectDeniedError < StandardError; end

  def fetch_document(url, ip: RestrictedHTTP::PrivateNetworkGuard.resolve(url.host))
    request(url, Net::HTTP::Get, ip: ip) do |response|
      return body_if_acceptable(response)
    end
  end

  def fetch_content_type(url, ip: RestrictedHTTP::PrivateNetworkGuard.resolve(url.host))
    request(url, Net::HTTP::Head, ip: ip) do |response|
      return response["Content-Type"]
    end
  end

  private
    def request(url, request_class, ip:)
      redirect_count = 0
      
      loop do
        raise TooManyRedirectsError if redirect_count >= MAX_REDIRECTS
        
        Net::HTTP.start(url.host, url.port, ipaddr: ip, use_ssl: url.scheme == "https") do |http|
          request = request_class.new(url)
          # Add User-Agent to avoid being blocked
          request["User-Agent"] = "Mozilla/5.0 (compatible; OpengraphBot/1.0)"
          
          http.request(request) do |response|
            if response.is_a?(Net::HTTPRedirection)
              url, ip = resolve_redirect(response["location"])
              redirect_count += 1
            else
              return yield(response)
            end
          end
        end
      end
    end

    def resolve_redirect(location)
      url = URI.parse(location)
      raise RedirectDeniedError unless url.is_a?(URI::HTTP)
      [ url, RestrictedHTTP::PrivateNetworkGuard.resolve(url.host) ]
    end

    def body_if_acceptable(response)
      size_restricted_body(response) if response_valid?(response)
    end

    def size_restricted_body(response)
      "".tap do |body|
        response.read_body do |chunk|
          return nil if body.bytesize + chunk.bytesize > MAX_BODY_SIZE
          body << chunk
        end
      end
    end

    def response_valid?(response)
      status_valid?(response) && content_type_valid?(response) && content_length_valid?(response)
    end

    def status_valid?(response)
      response.is_a?(Net::HTTPOK)
    end

    def content_type_valid?(response)
      # Handle content type with charset (e.g., "text/html; charset=utf-8")
      response.content_type&.split(";")&.first&.strip == ALLOWED_DOCUMENT_CONTENT_TYPE
    end

    def content_length_valid?(response)
      response.content_length.to_i <= MAX_BODY_SIZE
    end
end
