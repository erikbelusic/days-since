require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "rejects connections without a session" do
    expect { connect }.to have_rejected_connection
  end

  it "identifies the signed-in user from the session cookie" do
    user = create(:user)
    session = user.sessions.create!
    cookies.signed[:session_id] = session.id

    connect

    expect(connection.current_user).to eq(user)
  end

  it "identifies the local user in single-user mode", :single_user_mode do
    connect

    expect(connection.current_user.email_address).to eq(SingleUserMode::LOCAL_EMAIL_ADDRESS)
  end
end
