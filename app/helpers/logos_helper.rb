module LogosHelper
  # A service's logo, or a one-letter monogram when it has none. Decorative:
  # the service name is always shown next to it, so it's hidden from screen
  # readers. Themes pass their own classes for size and treatment.
  # Logos sit on a small white chip by default so dark marks (GitHub, Huntress)
  # stay visible on dark themes.
  def service_logo(subscription, css_class: "h-6 w-6 rounded-md", monogram_class: "bg-surface-muted text-ink-muted",
                   image_class: "bg-white p-0.5 ring-1 ring-black/10")
    feed = subscription.feed
    if feed.logo.attached?
      image_tag feed.logo, alt: "", class: "#{css_class} #{image_class} shrink-0 object-contain", loading: "lazy",
                           aria: { hidden: true }, data: { service_logo: true }
    else
      tag.span subscription.name.to_s.strip.first.to_s.upcase.presence || "?",
               class: "#{css_class} #{monogram_class} inline-flex shrink-0 items-center justify-center font-bold leading-none",
               aria: { hidden: true }, data: { service_logo: "monogram" }
    end
  end
end
