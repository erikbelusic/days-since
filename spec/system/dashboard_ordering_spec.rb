require "rails_helper"

RSpec.describe "Dashboard ordering", :js, :single_user_mode do
  it "lets cards be dragged into a new order" do
    user = SingleUserMode.user
    first = create(:subscription, user: user, feed: create(:feed, name: "Alpha"))
    second = create(:subscription, user: user, feed: create(:feed, name: "Bravo"))

    visit root_path
    expect(page).to have_css("#subscriptions[data-controller='sortable']")

    # Simulate the drop Sortable reports, then check the server persisted it.
    page.execute_script(<<~JS)
      const list = document.getElementById("subscriptions")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(list, "sortable")
      const item = document.getElementById("#{ActionView::RecordIdentifier.dom_id(second)}")
      controller.moved({ item, oldIndex: 1, newIndex: 0 })
    JS

    expect { user.subscriptions.ordered.first }.to eventually(eq(second))
    visit root_path
    expect(page.body.index("Bravo")).to be < page.body.index("Alpha")
    expect(first.reload.position).to eq(1)
  end
end
