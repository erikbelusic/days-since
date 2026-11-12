require "rails_helper"

RSpec.describe "Sessions" do
  let(:user) { create(:user, password: "s3cret-pass") }

  it "redirects signed-out visitors to the sign-in page" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "signs a user in with valid credentials" do
    post session_path, params: { email_address: user.email_address, password: "s3cret-pass" }

    expect(response).to redirect_to(root_url)
    follow_redirect!
    expect(response.body).to include(user.email_address)
  end

  it "rejects an invalid password" do
    post session_path, params: { email_address: user.email_address, password: "wrong" }

    expect(response).to redirect_to(new_session_path)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "returns to the originally requested page after signing in" do
    get root_path
    post session_path, params: { email_address: user.email_address, password: "s3cret-pass" }

    expect(response).to redirect_to(root_url)
  end

  it "signs a user out" do
    post session_path, params: { email_address: user.email_address, password: "s3cret-pass" }
    delete session_path

    expect(response).to redirect_to(new_session_path)
    get root_path
    expect(response).to redirect_to(new_session_path)
  end
end
