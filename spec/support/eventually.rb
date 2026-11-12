# expect { value }.to eventually(matcher): retries until the matcher passes or
# Capybara's wait time runs out. Handy for async server writes in JS specs.
RSpec::Matchers.define :eventually do |expected|
  supports_block_expectations

  match do |block|
    deadline = Time.now + Capybara.default_max_wait_time
    loop do
      return true if expected.matches?(block.call)
      return false if Time.now > deadline
      sleep 0.05
    end
  end

  failure_message { "expected value to eventually #{expected.description}" }
end
