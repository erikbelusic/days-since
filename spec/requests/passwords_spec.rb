require "rails_helper"

RSpec.describe "Password resets" do
  include ActionMailer::TestHelper

  it "emails reset instructions to a known address" do
    user = create(:user)

    assert_emails 1 do
      post passwords_path, params: { email_address: user.email_address }
    end
    expect(response).to redirect_to(new_session_path)
  end

  it "does not reveal whether an address is registered" do
    assert_emails 0 do
      post passwords_path, params: { email_address: "nobody@example.com" }
    end
    expect(response).to redirect_to(new_session_path)
  end

  it "lets a user set a new password with a valid token" do
    user = create(:user)

    put password_path(user.password_reset_token), params: { password: "brand-new-pass", password_confirmation: "brand-new-pass" }

    expect(response).to redirect_to(new_session_path)
    expect(User.authenticate_by(email_address: user.email_address, password: "brand-new-pass")).to eq(user)
  end
end
