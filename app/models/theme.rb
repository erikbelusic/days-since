# Themes live in code and are added by pull request (see CLAUDE.md "Adding a
# theme"). Each theme supplies CSS tokens in app/assets/tailwind/themes/<key>.css,
# may override partials in app/views/themes/<key>/, and may name the stability
# levels in its own words (anything it leaves out uses DEFAULT_LEVEL_LABELS).
class Theme < Data.define(:key, :name, :description, :level_labels)
  DEFAULT_LEVEL_LABELS = {
    "ongoing" => "Ongoing",
    "day_one" => "Back to day one",
    "short_streak" => "Short streak",
    "long_streak" => "Long streak",
    "solid_streak" => "Solid streak"
  }.freeze

  def initialize(key:, name:, description:, level_labels: {})
    super
  end

  REGISTRY = [
    new(key: "default", name: "Default", description: "Clean Tailwind look with automatic light and dark mode."),
    new(key: "worksite", name: "Worksite Safety Sign", description: "Hazard stripes and a \"DAYS SINCE LAST INCIDENT\" site board.",
        level_labels: { "ongoing" => "Danger", "day_one" => "Warning", "short_streak" => "Caution", "long_streak" => "Safe", "solid_streak" => "★ Safety record ★" }),
    new(key: "farmhouse", name: "Farmhouse", description: "A hand-lettered barn-wood sign with hanging flip-card numbers.",
        level_labels: { "ongoing" => "Trouble now", "day_one" => "Starting over", "short_streak" => "Good stretch", "long_streak" => "Long stretch", "solid_streak" => "Solid ground" }),
    new(key: "github", name: "GitHub-inspired", description: "Primer-style boxes, status labels, and a contribution-style activity grid. Light and dark.",
        level_labels: { "ongoing" => "Failing", "day_one" => "Flaky", "short_streak" => "Passing", "long_streak" => "Green", "solid_streak" => "LTS" }),
    new(key: "datadog", name: "Datadog-inspired", description: "A dark monitoring dashboard: metric tiles, monitor badges, and timeseries bars.")
  ].freeze

  class << self
    def all = REGISTRY
    def keys = all.map(&:key)
    def default = find("default")
    def find(key) = all.find { |theme| theme.key == key.to_s }
    def find_or_default(key) = find(key) || default
  end

  # This theme's name for a stability level, falling back to the default words.
  def level_label(level)
    level_labels.fetch(level.to_s) { DEFAULT_LEVEL_LABELS.fetch(level.to_s, level.to_s.humanize) }
  end

  def to_param = key
end
