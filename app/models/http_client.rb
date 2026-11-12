require "faraday"
require "faraday/follow_redirects"

# The only way the app talks to the network. Wraps Faraday with timeouts, a
# descriptive user agent, redirect following, and conditional GET support.
module HttpClient
  USER_AGENT = "days-since/1.0 (+https://github.com/erikbelusic/days-since)".freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  MAX_REDIRECTS = 5

  class Error < StandardError; end

  Response = Data.define(:status, :body, :headers, :url) do
    def success? = (200..299).cover?(status)
    def not_modified? = status == 304
    def etag = headers["etag"]
    def last_modified = headers["last-modified"]
    def content_type = headers["content-type"].to_s
  end

  # GETs +url+, following redirects. Pass the etag / last_modified from a
  # previous response to make a conditional request (a 304 means unchanged).
  # Returns a Response for any HTTP status; raises HttpClient::Error when the
  # server can't be reached.
  def self.get(url, etag: nil, last_modified: nil, accept: nil)
    headers = {}
    headers["If-None-Match"] = etag if etag.present?
    headers["If-Modified-Since"] = last_modified if last_modified.present?
    headers["Accept"] = accept if accept.present?

    response = connection.get(url, nil, headers)
    Response.new(status: response.status, body: response.body.to_s, headers: response.headers, url: response.env.url.to_s)
  rescue Faraday::Error, URI::InvalidURIError, ArgumentError => e
    raise Error, "#{e.class.name.demodulize}: #{e.message}"
  end

  def self.connection
    Faraday.new(headers: { "User-Agent" => USER_AGENT }) do |f|
      f.response :follow_redirects, limit: MAX_REDIRECTS
      f.options.open_timeout = OPEN_TIMEOUT
      f.options.timeout = READ_TIMEOUT
    end
  end
  private_class_method :connection
end
