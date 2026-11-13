module DashboardsHelper
  SEVERITY_SHORT_LABELS = { "none" => "any severity", "minor" => "minor+", "major" => "major+", "critical" => "critical only" }.freeze

  def counter_caption(result)
    case result.state
    when :waiting then "no data yet"
    when :ongoing then "incident in progress"
    when :counting then "#{"day".pluralize(result.days)} since last incident"
    else result.infinite? ? "no incidents on record" : "#{"day".pluralize(result.days)} since tracking started, no incidents"
    end
  end

  def severity_short_label(level)
    SEVERITY_SHORT_LABELS.fetch(level.to_s, level.to_s)
  end

  def threshold_explanation(result)
    "Only #{severity_short_label(result.min_severity)} incidents reset this counter. Change it from Edit or Settings."
  end

  def ignored_incidents_note(result)
    where = result.incident ? "since" : "on record"
    "+#{pluralize(result.ignored_count, "lower-severity incident")} #{where}, not counted"
  end

  # The current theme's name for a stability level (see Theme#level_label).
  def stability_label(level)
    current_theme.level_label(level)
  end
end
