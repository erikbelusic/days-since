require "rails_helper"

RSpec.describe "Subscriptions", :single_user_mode do
  include ActiveJob::TestHelper

  let(:user) { SingleUserMode.user }

  def subscribe(url, **attrs)
    post subscriptions_path, params: { subscription_form: { url: url, **attrs } }
  end

  describe "adding a status page" do
    before { stub_statuspage_site("www.githubstatus.com") }

    it "detects the provider, subscribes the user, and queues a first poll" do
      expect { subscribe("www.githubstatus.com") }
        .to change(user.subscriptions, :count).by(1)
        .and have_enqueued_job(PollFeedJob)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Added GitHub.")
      expect(user.subscriptions.sole.feed).to have_attributes(provider: "statuspage", url: "https://www.githubstatus.com/api/v2/incidents.json")
    end

    it "saves an optional display name" do
      subscribe("www.githubstatus.com", display_name: "Work Git")

      expect(user.subscriptions.sole.name).to eq("Work Git")
    end

    it "shares an existing feed instead of creating a duplicate, without re-polling it" do
      feed = create(:feed, url: "https://www.githubstatus.com/api/v2/incidents.json", last_polled_at: 1.minute.ago)
      create(:subscription, feed: feed)

      expect { subscribe("https://www.githubstatus.com/api/v2/incidents.json") }
        .to not_change(Feed, :count)
        .and not_have_enqueued_job(PollFeedJob)

      expect(user.subscriptions.sole.feed).to eq(feed)
    end

    it "refuses a status page the user already follows" do
      subscribe("www.githubstatus.com")
      subscribe("www.githubstatus.com")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("already on your dashboard")
      expect(user.subscriptions.count).to eq(1)
    end
  end

  it "shows detection problems inline" do
    stub_request(:get, /example\.com/).to_return(status: 404)
    stub_request(:get, "https://example.com").to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" })

    subscribe("example.com")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Couldn&#39;t find a Statuspage API or an RSS/Atom feed at that URL")
    expect(user.subscriptions).to be_empty
  end

  it "requires a URL" do
    subscribe("")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Url can&#39;t be blank")
  end

  it "requires signing in when SINGLE_USER_MODE is off", single_user_mode: false do
    get new_subscription_path

    expect(response).to redirect_to(new_session_path)
  end
end

RSpec::Matchers.define_negated_matcher :not_change, :change
RSpec::Matchers.define_negated_matcher :not_have_enqueued_job, :have_enqueued_job
