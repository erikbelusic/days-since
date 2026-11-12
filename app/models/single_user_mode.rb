# Local-first mode: no sign-in, every request acts as one default local user.
# This is the only place that knows the flag; everything else just sees a User.
module SingleUserMode
  LOCAL_EMAIL_ADDRESS = "local@days-since.local".freeze

  def self.enabled?
    Rails.configuration.x.single_user_mode == true
  end

  def self.user
    User.find_or_create_by!(email_address: LOCAL_EMAIL_ADDRESS) do |user|
      user.password = SecureRandom.base58(32)
    end
  end

  # Production is allowed (e.g. a home server) but gets a loud reminder.
  def self.warn_if_production(env: Rails.env, logger: Rails.logger, io: $stderr)
    return unless enabled? && env.production?

    message = "SINGLE_USER_MODE is enabled in production: sign-in is disabled and every visitor " \
              "acts as #{LOCAL_EMAIL_ADDRESS}. Never expose this app to the public internet."
    logger.warn(message)
    io.puts("[days-since] WARNING: #{message}")
  end
end
