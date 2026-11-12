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

  # Every impact value that meets +minimum+ (for SQL filtering).
  def self.at_least(minimum)
    LEVELS.drop(rank(minimum).to_i) + [ UNKNOWN ]
  end
end
