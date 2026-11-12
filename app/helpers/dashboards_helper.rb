module DashboardsHelper
  SEVERITY_SHORT_LABELS = { "none" => "any severity", "minor" => "minor+", "major" => "major+", "critical" => "critical only" }.freeze

  STABILITY_LABELS = { "ongoing" => "Ongoing", "day_one" => "Back to day one", "short_streak" => "Short streak", "long_streak" => "Long streak", "solid_streak" => "Solid streak" }.freeze

  def counter_caption(result)
    case result.state
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

  # Default wording for a stability level; themes may use their own words.
  def stability_label(level)
    STABILITY_LABELS.fetch(level.to_s, level.to_s.humanize)
  end
end
