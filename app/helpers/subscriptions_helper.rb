module SubscriptionsHelper
  SEVERITY_LABELS = {
    "none" => "Any incident, including no-impact notices",
    "minor" => "Minor incidents and worse",
    "major" => "Major incidents and worse",
    "critical" => "Critical incidents only"
  }.freeze

  def severity_options(user)
    [ [ "My default (#{SEVERITY_LABELS.fetch(user.default_min_severity).downcase})", "" ] ] +
      SEVERITY_LABELS.map { |level, label| [ label, level ] }
  end
end
