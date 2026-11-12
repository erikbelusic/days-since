# Computes what a subscription's card shows. Days are whole calendar days in
# the subscriber's time zone, counted from the last relevant incident's
# resolution (see README "Counter semantics").
class DaysSinceCounter
  Result = Data.define(:state, :days, :incident) do
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
    @today = now.in_time_zone(@user.zone).to_date
  end

  def result
    if (incident = relevant_incidents.ongoing.order(started_at: :desc).first)
      Result.new(state: :ongoing, days: 0, incident: incident)
    elsif (incident = relevant_incidents.resolved.order(resolved_at: :desc).first)
      Result.new(state: :counting, days: days_since(incident.resolved_at), incident: incident)
    elsif @user.no_incident_display_since_tracking?
      Result.new(state: :no_history, days: days_since(@feed.created_at), incident: nil)
    else
      Result.new(state: :no_history, days: nil, incident: nil)
    end
  end

  private
    def relevant_incidents
      @feed.incidents.at_least(@subscription.effective_min_severity)
    end

    def days_since(time)
      [ (@today - time.in_time_zone(@user.zone).to_date).to_i, 0 ].max
    end
end
