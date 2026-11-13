# Names how long a service has stayed incident-free, from the counter result
# and the user's day thresholds. Themes decide how each level looks and what
# it's called (see CLAUDE.md); the default wording is in parentheses.
#
#   waiting       the status page hasn't been read yet, so there's nothing to count ("Waiting for data")
#   ongoing       an incident is happening right now; always most urgent ("Ongoing")
#   day_one       fewer than short_streak_after_days since the last incident ("Back to day one")
#   short_streak  fewer than long_streak_after_days ("Short streak")
#   long_streak   fewer than solid_streak_after_days, or no incidents on record ("Long streak")
#   solid_streak  solid_streak_after_days or more ("Solid streak")
module Stability
  LEVELS = %w[ waiting ongoing day_one short_streak long_streak solid_streak ].freeze

  def self.level(result, user)
    return "waiting" if result.waiting?
    return "ongoing" if result.ongoing?
    return "long_streak" if result.infinite?

    days = result.days
    if days < user.short_streak_after_days then "day_one"
    elsif days < user.long_streak_after_days then "short_streak"
    elsif days < user.solid_streak_after_days then "long_streak"
    else "solid_streak"
    end
  end
end
