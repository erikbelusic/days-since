require "rails_helper"

RSpec.describe "SINGLE_USER_MODE" do
  context "when enabled", :single_user_mode do
    it "shows the dashboard without signing in" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(SingleUserMode::LOCAL_EMAIL_ADDRESS)
    end

    it "reuses the same local user across requests" do
      expect {
        get root_path
        get root_path
      }.to change(User, :count).by(1)
    end

    it "does not offer a sign-out button" do
      get root_path

      expect(response.body).not_to include("Sign out")
    end

    it "redirects the sign-in, sign-out, and password pages to the dashboard" do
      get new_session_path
      expect(response).to redirect_to(root_path)

      post session_path, params: { email_address: "x@example.com", password: "nope" }
      expect(response).to redirect_to(root_path)

      delete session_path
      expect(response).to redirect_to(root_path)

      get new_password_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "when disabled" do
    it "requires signing in" do
      get root_path

      expect(response).to redirect_to(new_session_path)
    end

    it "does not create the local user" do
      expect { get root_path }.not_to change(User, :count)
    end
  end
end
