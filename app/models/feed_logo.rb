# Finds a square-ish logo for a feed on the service's own status page (never a
# third-party logo API) and stores it on the shared Feed:
#
#   1. <link rel="apple-touch-icon"> (largest first)
#   2. <link rel="icon"> / "shortcut icon" (largest first)
#   3. /favicon.ico at the site root
#
# Statuspage header logos are skipped: they're wide banners, not icons. SVGs
# are skipped too (not served inline by Active Storage). Downloads are checked
# by their bytes, not the server's content type, since some sites answer
# /favicon.ico with an HTML page. Views fall back to a letter monogram.
class FeedLogo
  REFRESH_AFTER = 7.days
  MAX_BYTES = 512.kilobytes
  CONTENT_TYPES = %w[ image/png image/jpeg image/gif image/webp image/vnd.microsoft.icon ].freeze
  EXTENSIONS = { "image/png" => "png", "image/jpeg" => "jpg", "image/gif" => "gif", "image/webp" => "webp", "image/vnd.microsoft.icon" => "ico" }.freeze

  Image = Data.define(:bytes, :content_type)

  def self.refresh!(feed, now: Time.current)
    new(feed).refresh!(now: now)
  end

  def initialize(feed)
    @feed = feed
  end

  # Looks for a logo and attaches the first valid one. Keeps the current logo
  # when nothing is found (e.g. the site is down). Returns true if a logo is attached.
  def refresh!(now: Time.current)
    image = candidate_urls.lazy.filter_map { |url| download(url) }.first
    attach(image) if image
    @feed.update!(logo_checked_at: now)
    @feed.logo.attached?
  end

  def candidate_urls
    page = fetch_page
    links = page ? icon_links(page) : []
    (links + [ URI.join(page&.url || page_url, "/favicon.ico").to_s ]).uniq
  rescue URI::Error
    []
  end

  private
    def page_url
      @feed.site_url.presence || URI.join(@feed.url, "/").to_s
    end

    def fetch_page
      response = HttpClient.get(page_url)
      response if response.success? && response.content_type.include?("html")
    rescue HttpClient::Error
      nil
    end

    def icon_links(page)
      links = Nokogiri::HTML(page.body).css("link[rel][href]").filter_map do |link|
        rels = link["rel"].downcase.split
        kind = if rels.intersect?(%w[apple-touch-icon apple-touch-icon-precomposed]) then 0
        elsif rels.include?("icon") then 1
        end
        next unless kind
        next if link["type"].to_s.include?("svg") || link["href"].to_s.downcase.split("?").first.end_with?(".svg")

        [ kind, -icon_size(link["sizes"]), URI.join(page.url, link["href"].strip).to_s ]
      rescue URI::Error
        nil
      end
      links.sort.map(&:last)
    end

    def icon_size(sizes)
      sizes.to_s.scan(/(\d+)x\d+/i).flatten.map(&:to_i).max.to_i
    end

    def download(url)
      response = HttpClient.get(url, accept: "image/*")
      return unless response.success?

      bytes = response.body.b
      return if bytes.empty? || bytes.bytesize > MAX_BYTES

      content_type = Marcel::MimeType.for(StringIO.new(bytes))
      content_type = "image/vnd.microsoft.icon" if content_type == "image/x-icon"
      Image.new(bytes: bytes, content_type: content_type) if CONTENT_TYPES.include?(content_type)
    rescue HttpClient::Error
      nil
    end

    def attach(image)
      return if @feed.logo.attached? && @feed.logo.checksum == OpenSSL::Digest::MD5.base64digest(image.bytes)

      @feed.logo.attach(io: StringIO.new(image.bytes), filename: "logo.#{EXTENSIONS.fetch(image.content_type)}", content_type: image.content_type)
    end
end
