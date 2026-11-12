# Specs run in multi-user mode unless tagged :single_user_mode, regardless of
# the SINGLE_USER_MODE value in the developer's shell.
RSpec.configure do |config|
  config.around do |example|
    original = Rails.configuration.x.single_user_mode
    Rails.configuration.x.single_user_mode = example.metadata[:single_user_mode] == true
    example.run
  ensure
    Rails.configuration.x.single_user_mode = original
  end
end
