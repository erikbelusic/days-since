# Names how stable a service looks, from the counter result and the user's
# day thresholds. Themes decide how each level looks (see CLAUDE.md).
#
#   ongoing     an incident is happening right now (always most urgent)
#   unstable    fewer than recovering_after_days since the last incident
#   recovering  fewer than stable_after_days
#   stable      fewer than rock_solid_after_days, or no incidents on record
#   rock_solid  rock_solid_after_days or more
module Stability
  LEVELS = %w[ ongoing unstable recovering stable rock_solid ].freeze

  def self.level(result, user)
    return "ongoing" if result.ongoing?
    return "stable" if result.infinite?

    days = result.days
    if days < user.recovering_after_days then "unstable"
    elsif days < user.stable_after_days then "recovering"
    elsif days < user.rock_solid_after_days then "stable"
    else "rock_solid"
    end
  end
end
