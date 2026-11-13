# Incident impact levels, lowest to highest. Statuspage reports these values;
# sources without severity (RSS/Atom) use UNKNOWN, which always counts.
module Severity
  LEVELS = %w[ none minor major critical ].freeze
  UNKNOWN = "unknown".freeze
  IMPACTS = (LEVELS + [ UNKNOWN ]).freeze

  def self.rank(level)
    LEVELS.index(level.to_s)
  end

  # Does an incident with impact +level+ meet the +minimum+ severity?
  def self.meets?(level, minimum)
    return true if level.to_s == UNKNOWN || level.blank?

    rank(level).to_i >= rank(minimum).to_i
  end

  # The more severe of two impacts (either may be nil). An unknown impact (RSS)
  # ranks between minor and major: something happened, but we can't say how bad.
  WORST_ORDER = %w[ none minor unknown major critical ].freeze

  def self.worst(a, b)
    [ a, b ].compact.max_by { |impact| WORST_ORDER.index(impact.to_s).to_i }
  end

  # Every impact value that meets +minimum+ (for SQL filtering).
  def self.at_least(minimum)
    LEVELS.drop(rank(minimum).to_i) + [ UNKNOWN ]
  end
end
