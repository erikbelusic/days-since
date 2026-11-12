# Computes what a subscription's card shows. Days are whole calendar days in
# the subscriber's time zone, counted from the last relevant incident's
# resolution (see README "Counter semantics").
class DaysSinceCounter
  ACTIVITY_DAYS = 28

  # incident:      the incident the count is based on (nil when no history)
  # min_severity:  the threshold that decided which incidents count
  # ignored_count: newer incidents skipped for being below that threshold
  # activity:      relevant incidents active on each of the last
  #                ACTIVITY_DAYS days in the user's time zone, oldest first
  # level:         Stability level name (ongoing, unstable, recovering,
  #                stable, rock_solid) from the user's thresholds
  Result = Data.define(:state, :days, :incident, :min_severity, :ignored_count, :activity, :level) do
    def ongoing? = state == :ongoing
    def no_history? = state == :no_history
    def counting? = state == :counting

    # No incidents and the user prefers "∞" over counting from tracking start.
    def infinite? = days.nil?
  end

  def initialize(subscription, now: Time.current)
    @subscription = subscription
    @user = subscription.user
    @feed = subscription.feed
    @min_severity = subscription.effective_min_severity
    @now = now
    @today = now.in_time_zone(@user.zone).to_date
  end

  def result
    if (incident = relevant_incidents.ongoing.order(started_at: :desc).first)
      build(:ongoing, 0, incident)
    elsif (incident = relevant_incidents.resolved.order(resolved_at: :desc).first)
      build(:counting, days_since(incident.resolved_at), incident)
    elsif @user.no_incident_display_since_tracking?
      build(:no_history, days_since(@feed.created_at), nil)
    else
      build(:no_history, nil, nil)
    end
  end

  private
    def build(state, days, incident)
      result = Result.new(state: state, days: days, incident: incident, min_severity: @min_severity,
                          ignored_count: ignored_since(incident), activity: activity, level: nil)
      result.with(level: Stability.level(result, @user))
    end

    def relevant_incidents
      @feed.incidents.at_least(@min_severity)
    end

    def ignored_since(incident)
      ignored = @feed.incidents.where.not(impact: Severity.at_least(@min_severity))
      ignored = ignored.where(started_at: incident.started_at..).where.not(id: incident.id) if incident
      ignored.count
    end

    def activity
      first_day = @today - (ACTIVITY_DAYS - 1)
      counts = Array.new(ACTIVITY_DAYS, 0)

      relevant_incidents
        .where(started_at: ...(@today + 1).in_time_zone(@user.zone))
        .where("resolved_at IS NULL OR resolved_at >= ?", first_day.in_time_zone(@user.zone))
        .pluck(:started_at, :resolved_at)
        .each do |started_at, resolved_at|
          from = [ local_date(started_at), first_day ].max
          to = [ local_date(resolved_at || @now), @today ].min
          (from..to).each { |day| counts[(day - first_day).to_i] += 1 }
        end

      counts
    end

    def local_date(time)
      time.in_time_zone(@user.zone).to_date
    end

    def days_since(time)
      [ (@today - local_date(time)).to_i, 0 ].max
    end
end
