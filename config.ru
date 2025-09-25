# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

use Rack::Deflater, if: lambda { |_env, _status, headers, _body|
  # If videos are compressed and served via Cloudflare, the HTTP Range requests return a wrong status code
  # (200 OK instead of the correct 206 Partial Content). This causes Safari playback issues.
  !headers.key?(Rack::CONTENT_TYPE) || !headers[Rack::CONTENT_TYPE].to_s.start_with?("video/")
}

run Rails.application

Rails.application.load_server
