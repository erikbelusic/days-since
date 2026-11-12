require "rails_helper"

RSpec.describe User do
  it "stores email addresses stripped and downcased" do
    user = create(:user, email_address: "  Someone@Example.COM ")

    expect(user.reload.email_address).to eq("someone@example.com")
  end

  it "authenticates with a case-insensitive email address" do
    user = create(:user, email_address: "someone@example.com", password: "s3cret-pass")

    expect(User.authenticate_by(email_address: "SOMEONE@example.com", password: "s3cret-pass")).to eq(user)
  end
end
