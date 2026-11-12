# Normalizes user-entered status URLs so equivalent inputs share one Feed:
# assumes https when no scheme is given, lowercases scheme and host, drops
# default ports, query strings, fragments, and trailing slashes.
module FeedUrl
  class Invalid < StandardError; end

  def self.normalize(input)
    raw = input.to_s.strip
    raise Invalid, "URL can't be blank" if raw.empty?

    raw = "https://#{raw}" unless raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
    uri = URI.parse(raw)
    raise Invalid, "URL must use http or https" unless uri.is_a?(URI::HTTP)
    raise Invalid, "URL must include a host" if uri.host.blank?

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.port = nil if uri.port == uri.default_port
    uri.query = nil
    uri.fragment = nil
    uri.user = nil
    uri.path = uri.path.sub(%r{/+\z}, "")
    uri.to_s
  rescue URI::InvalidURIError
    raise Invalid, "URL is not valid"
  end

  # Like normalize, but returns nil instead of raising.
  def self.normalize_or_nil(input)
    normalize(input)
  rescue Invalid
    nil
  end
end
