require "rails_helper"

RSpec.describe DaysSinceCounter do
  let(:user) { create(:user, time_zone: "UTC", default_min_severity: "minor") }
  let(:feed) { create(:feed, created_at: Time.utc(2026, 1, 1, 12)) }
  let(:subscription) { create(:subscription, user: user, feed: feed) }
  let(:now) { Time.utc(2026, 3, 10, 12) }

  def result(at: now)
    described_class.new(subscription.reload, now: at).result
  end

  def incident(**attrs)
    create(:incident, feed: feed, impact: "major", started_at: Time.utc(2026, 3, 1, 8), resolved_at: Time.utc(2026, 3, 1, 10), **attrs)
  end

  it "counts calendar days since the last relevant incident was resolved" do
    incident(started_at: Time.utc(2026, 2, 27), resolved_at: Time.utc(2026, 3, 1, 23, 30))

    expect(result).to have_attributes(state: :counting, days: 9)
  end

  it "counts from the most recent resolution" do
    incident(resolved_at: Time.utc(2026, 3, 1, 10))
    latest = incident(started_at: Time.utc(2026, 3, 5), resolved_at: Time.utc(2026, 3, 7, 10))

    expect(result).to have_attributes(days: 3, incident: latest)
  end

  it "shows 0 and ONGOING while a relevant incident is unresolved" do
    incident(resolved_at: Time.utc(2026, 3, 1))
    ongoing = incident(started_at: Time.utc(2026, 3, 10, 9), resolved_at: nil)

    expect(result).to have_attributes(state: :ongoing, days: 0, incident: ongoing)
    expect(result).to be_ongoing
  end

  it "ignores incidents below the effective minimum severity" do
    incident(impact: "major", resolved_at: Time.utc(2026, 3, 1, 10))
    incident(impact: "none", started_at: Time.utc(2026, 3, 9), resolved_at: Time.utc(2026, 3, 9, 1))
    incident(impact: "minor", started_at: Time.utc(2026, 3, 10, 9), resolved_at: nil)

    subscription.update!(min_severity: "major")

    expect(result).to have_attributes(state: :counting, days: 9)
  end

  it "falls back to the user's default severity" do
    incident(impact: "minor", started_at: Time.utc(2026, 3, 10, 9), resolved_at: nil)

    user.update!(default_min_severity: "critical")
    expect(result).to have_attributes(state: :no_history)

    user.update!(default_min_severity: "minor")
    expect(result).to have_attributes(state: :ongoing)
  end

  it "always counts incidents with unknown severity (RSS)" do
    subscription.update!(min_severity: "critical")
    incident(impact: "unknown", resolved_at: Time.utc(2026, 3, 8, 10))

    expect(result).to have_attributes(days: 2)
  end

  it "shows infinity when there is no relevant history by default" do
    expect(result).to have_attributes(state: :no_history, days: nil)
    expect(result).to be_infinite
  end

  it "counts from when tracking started when the user prefers it" do
    user.update!(no_incident_display: "since_tracking")

    expect(result).to have_attributes(state: :no_history, days: 68)
  end

  it "shows 0 on the day an incident is resolved" do
    incident(resolved_at: Time.utc(2026, 3, 10, 1))

    expect(result).to have_attributes(state: :counting, days: 0)
  end

  describe "time zones" do
    it "rolls over at midnight in the user's time zone, not UTC" do
      user.update!(time_zone: "America/Chicago") # UTC-6 in early March
      incident(resolved_at: Time.utc(2026, 3, 1, 20)) # 2pm Mar 1 in Chicago

      expect(result(at: Time.utc(2026, 3, 2, 5, 59))).to have_attributes(days: 0) # 11:59pm Mar 1 Chicago
      expect(result(at: Time.utc(2026, 3, 2, 6, 0))).to have_attributes(days: 1)  # midnight Mar 2 Chicago
    end

    it "attributes a resolution to the user's local date" do
      user.update!(time_zone: "Asia/Tokyo") # UTC+9
      incident(resolved_at: Time.utc(2026, 3, 1, 16)) # 1am Mar 2 in Tokyo

      expect(result(at: Time.utc(2026, 3, 2, 3))).to have_attributes(days: 0) # noon Mar 2 Tokyo
    end

    it "counts calendar days across a DST change" do
      user.update!(time_zone: "America/New_York") # DST starts Mar 8, 2026
      incident(resolved_at: Time.utc(2026, 3, 7, 17)) # noon Mar 7 local

      expect(result(at: Time.utc(2026, 3, 9, 4, 30))).to have_attributes(days: 2) # 12:30am Mar 9 local
    end
  end
end

RSpec.describe DaysSinceCounter, "before the first successful poll" do
  let(:user) { create(:user, no_incident_display: "since_tracking") }
  let(:feed) { create(:feed, :never_polled) }
  let(:subscription) { create(:subscription, user: user, feed: feed) }

  def result = described_class.new(subscription.reload).result

  it "is waiting, with no day count, level or tracked days, whatever the no-incident setting" do
    expect(result).to have_attributes(state: :waiting, days: nil, level: "waiting", tracked_since: nil)
    expect(result).to be_waiting
    expect(result).not_to be_infinite
  end

  it "counts normally once incidents exist, even if the last poll never succeeded" do
    create(:incident, feed: feed, impact: "major", started_at: 5.days.ago, resolved_at: 5.days.ago + 1.hour)

    expect(result).to have_attributes(state: :counting, days: 5)
  end
end

RSpec.describe DaysSinceCounter, "explaining what was counted" do
  let(:user) { create(:user, default_min_severity: "minor") }
  let(:feed) { create(:feed) }
  let(:subscription) { create(:subscription, user: user, feed: feed) }

  def result = described_class.new(subscription.reload, now: Time.utc(2026, 11, 12)).result

  it "reports the threshold and counts newer lower-severity incidents it skipped" do
    counted = create(:incident, feed: feed, impact: "major", started_at: Time.utc(2026, 11, 2, 19), resolved_at: Time.utc(2026, 11, 2, 20))
    create(:incident, feed: feed, impact: "none", started_at: Time.utc(2026, 11, 3, 4), resolved_at: Time.utc(2026, 11, 3, 7))
    create(:incident, feed: feed, impact: "none", started_at: Time.utc(2026, 10, 28), resolved_at: Time.utc(2026, 10, 28, 1))

    expect(result).to have_attributes(incident: counted, min_severity: "minor", ignored_count: 1)
  end

  it "counts every skipped incident when nothing meets the threshold" do
    create_list(:incident, 2, feed: feed, impact: "none")

    expect(result).to have_attributes(state: :no_history, ignored_count: 2)
  end

  it "reports nothing skipped when every incident counts" do
    subscription.update!(min_severity: "none")
    create(:incident, feed: feed, impact: "none")

    expect(result.ignored_count).to eq(0)
  end
end

RSpec.describe DaysSinceCounter, "recent activity" do
  let(:user) { create(:user, time_zone: "America/Chicago", default_min_severity: "minor") }
  let(:feed) { create(:feed) }
  let(:subscription) { create(:subscription, user: user, feed: feed) }
  let(:now) { Time.utc(2026, 3, 28, 18) } # Mar 28 noon-ish in Chicago (CDT, UTC-5)

  def activity = described_class.new(subscription.reload, now: now).result.activity

  it "covers the last 28 local days, oldest first" do
    expect(activity.size).to eq(28)
    expect(activity).to all(eq(0))
  end

  it "marks every local day an incident was active, including multi-day ones" do
    create(:incident, feed: feed, impact: "major", started_at: Time.utc(2026, 3, 20, 15), resolved_at: Time.utc(2026, 3, 22, 15))

    expect(activity.each_index.select { |i| activity[i].positive? }).to eq([ 19, 20, 21 ]) # Mar 20, 21, 22
  end

  it "marks ongoing incidents through today and ignores below-threshold ones" do
    create(:incident, :ongoing, feed: feed, impact: "minor", started_at: Time.utc(2026, 3, 27, 15))
    create(:incident, feed: feed, impact: "none", started_at: Time.utc(2026, 3, 10, 15), resolved_at: Time.utc(2026, 3, 10, 16))

    expect(activity.last(2)).to eq([ 1, 1 ])
    expect(activity.sum).to eq(2)
  end

  it "uses the user's local dates" do
    create(:incident, feed: feed, impact: "major", started_at: Time.utc(2026, 3, 27, 3), resolved_at: Time.utc(2026, 3, 27, 4)) # Mar 26 evening in Chicago

    expect(activity[25]).to eq(1)
    expect(activity[26]).to eq(0)
  end

  it "ignores incidents that ended before the window" do
    create(:incident, feed: feed, impact: "major", started_at: Time.utc(2026, 2, 1), resolved_at: Time.utc(2026, 2, 2))

    expect(activity.sum).to eq(0)
  end

  describe "worst impact per day" do
    def worst_impacts = described_class.new(subscription.reload, now: now).result.worst_impacts

    it "keeps the most severe counted incident on each day and nil on clear days" do
      create(:incident, feed: feed, impact: "minor", started_at: Time.utc(2026, 3, 20, 15), resolved_at: Time.utc(2026, 3, 21, 15))
      create(:incident, feed: feed, impact: "critical", started_at: Time.utc(2026, 3, 21, 16), resolved_at: Time.utc(2026, 3, 21, 17))

      expect(worst_impacts.size).to eq(28)
      expect(worst_impacts[19..21]).to eq([ "minor", "critical", nil ]) # Mar 20, 21, 22
      expect(worst_impacts.compact.size).to eq(2)
    end

    it "ranks an unknown (RSS) impact between minor and major" do
      create(:incident, feed: feed, impact: "unknown", started_at: Time.utc(2026, 3, 20, 15), resolved_at: Time.utc(2026, 3, 20, 16))
      create(:incident, feed: feed, impact: "minor", started_at: Time.utc(2026, 3, 20, 17), resolved_at: Time.utc(2026, 3, 20, 18))
      create(:incident, feed: feed, impact: "unknown", started_at: Time.utc(2026, 3, 21, 15), resolved_at: Time.utc(2026, 3, 21, 16))
      create(:incident, feed: feed, impact: "major", started_at: Time.utc(2026, 3, 21, 17), resolved_at: Time.utc(2026, 3, 21, 18))

      expect(worst_impacts[19..20]).to eq([ "unknown", "major" ])
    end
  end

  describe "tracked since" do
    def tracked_since = described_class.new(subscription.reload, now: now).result.tracked_since

    it "is nil until the feed has been polled successfully" do
      feed.update!(last_success_at: nil)

      expect(tracked_since).to be_nil
    end

    it "is the local day we started polling when there are no older incidents" do
      feed.update!(created_at: Time.utc(2026, 3, 15, 3), last_success_at: now) # Mar 14 evening in Chicago

      expect(tracked_since).to eq(Date.new(2026, 3, 14))
    end

    it "reaches back to the oldest stored incident, which the provider reported from before we started" do
      feed.update!(created_at: Time.utc(2026, 3, 15, 18), last_success_at: now)
      create(:incident, feed: feed, impact: "none", started_at: Time.utc(2026, 2, 10, 18), resolved_at: Time.utc(2026, 2, 10, 19))

      expect(tracked_since).to eq(Date.new(2026, 2, 10))
    end
  end
end

RSpec.describe DaysSinceCounter, "stability level" do
  it "includes the stability level in the result" do
    user = create(:user, short_streak_after_days: 7)
    subscription = create(:subscription, user: user)
    create(:incident, feed: subscription.feed, impact: "major", started_at: 3.days.ago, resolved_at: 3.days.ago)

    expect(described_class.new(subscription).result.level).to eq("day_one")
  end
end
