# Computes what a subscription's card shows. Days are whole calendar days in
# the subscriber's time zone, counted from the last relevant incident's
# resolution (see README "Counter semantics").
class DaysSinceCounter
  # incident:      the incident the count is based on (nil when no history)
  # min_severity:  the threshold that decided which incidents count
  # ignored_count: newer incidents skipped for being below that threshold
  Result = Data.define(:state, :days, :incident, :min_severity, :ignored_count) do
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
      Result.new(state: state, days: days, incident: incident, min_severity: @min_severity, ignored_count: ignored_since(incident))
    end

    def relevant_incidents
      @feed.incidents.at_least(@min_severity)
    end

    def ignored_since(incident)
      ignored = @feed.incidents.where.not(impact: Severity.at_least(@min_severity))
      ignored = ignored.where(started_at: incident.started_at..).where.not(id: incident.id) if incident
      ignored.count
    end

    def days_since(time)
      [ (@today - time.in_time_zone(@user.zone).to_date).to_i, 0 ].max
    end
end
