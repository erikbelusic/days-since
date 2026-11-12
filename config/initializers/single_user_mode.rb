Rails.application.config.after_initialize do
  SingleUserMode.warn_if_production
end
