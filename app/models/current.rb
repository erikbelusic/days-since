class Current < ActiveSupport::CurrentAttributes
  attribute :session, :single_user

  def user
    single_user || session&.user
  end
end
