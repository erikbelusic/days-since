require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1280, 900 ],
    process_timeout: 20,
    headless: ENV["HEADFUL"] != "true",
    browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {}
  )
end

Capybara.default_max_wait_time = 3

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :cuprite
  end
end
