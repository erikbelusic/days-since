# Themes live in code and are added by pull request (see CLAUDE.md "Adding a
# theme"). Each theme supplies CSS tokens in app/assets/tailwind/themes/<key>.css
# and may override partials in app/views/themes/<key>/.
class Theme < Data.define(:key, :name, :description)
  REGISTRY = [
    new(key: "default", name: "Default", description: "Clean Tailwind look with automatic light and dark mode."),
    new(key: "worksite", name: "Worksite Safety Sign", description: "Hazard stripes and a \"DAYS SINCE LAST INCIDENT\" site board."),
    new(key: "farmhouse", name: "Farmhouse", description: "A hand-lettered barn-wood sign with hanging flip-card numbers."),
    new(key: "github", name: "GitHub-inspired", description: "Primer-style boxes, status labels, and a contribution-style activity grid. Light and dark."),
    new(key: "datadog", name: "Datadog-inspired", description: "A dark monitoring dashboard: metric tiles, monitor badges, and timeseries bars.")
  ].freeze

  class << self
    def all = REGISTRY
    def keys = all.map(&:key)
    def default = find("default")
    def find(key) = all.find { |theme| theme.key == key.to_s }
    def find_or_default(key) = find(key) || default
  end

  def to_param = key
end
