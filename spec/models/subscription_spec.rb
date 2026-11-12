require "rails_helper"

RSpec.describe Subscription do
  let(:user) { create(:user, default_min_severity: "major") }

  it "lets a user subscribe to a feed only once" do
    feed = create(:feed)
    create(:subscription, user: user, feed: feed)

    duplicate = build(:subscription, user: user, feed: feed)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:feed_id]).to include("is already on your dashboard")
  end

  it "shares one feed between users who subscribe to the same URL" do
    feed = create(:feed)

    create(:subscription, feed: feed)
    create(:subscription, feed: feed)

    expect(Feed.count).to eq(1)
    expect(feed.subscriptions.count).to eq(2)
  end

  it "uses its own severity threshold when set, otherwise the user's default" do
    expect(build(:subscription, user: user, min_severity: "critical").effective_min_severity).to eq("critical")
    expect(build(:subscription, user: user, min_severity: "").effective_min_severity).to eq("major")
  end

  it "rejects unknown severity thresholds" do
    expect(build(:subscription, min_severity: "catastrophic")).not_to be_valid
  end

  it "uses its display name when set, otherwise the feed's name" do
    feed = create(:feed, name: "GitHub")

    expect(build(:subscription, feed: feed, display_name: "  Work Git ").name).to eq("Work Git")
    expect(build(:subscription, feed: feed, display_name: " ").name).to eq("GitHub")
  end

  it "adds new subscriptions to the end of the user's list" do
    first = create(:subscription, user: user)
    second = create(:subscription, user: user)
    other_user_sub = create(:subscription)

    expect(user.subscriptions.ordered).to eq([ first, second ])
    expect(second.position).to be > first.position
    expect(other_user_sub.position).to eq(0)
  end

  it "keeps the feed and its history when the last subscriber leaves" do
    subscription = create(:subscription)
    feed = subscription.feed
    create(:incident, feed: feed)

    subscription.destroy

    expect(feed.reload.incidents.count).to eq(1)
    expect(feed).not_to be_subscribed
    expect(Feed.subscribed).not_to include(feed)
  end

  it "is removed when its user is deleted" do
    subscription = create(:subscription)

    subscription.user.destroy

    expect(Subscription.exists?(subscription.id)).to be(false)
  end
end

RSpec.describe Subscription, "#move_to" do
  let(:user) { create(:user) }
  let!(:subs) { 4.times.map { create(:subscription, user: user) } }

  def order = user.subscriptions.ordered.to_a

  it "moves a subscription down the list" do
    subs[0].move_to(2)

    expect(order).to eq([ subs[1], subs[2], subs[0], subs[3] ])
  end

  it "moves a subscription to the top" do
    subs[3].move_to(0)

    expect(order).to eq([ subs[3], subs[0], subs[1], subs[2] ])
  end

  it "clamps out-of-range positions" do
    subs[1].move_to(99)
    expect(order.last).to eq(subs[1])

    subs[1].move_to(-5)
    expect(order.first).to eq(subs[1])
  end

  it "leaves other users' lists alone" do
    other = create(:subscription)

    subs[0].move_to(3)

    expect(other.reload.position).to eq(0)
  end
end
