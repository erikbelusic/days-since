class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  # Accounts are created by an admin (there is no public sign-up). Returns the
  # new user and the password that was set, generating one when none is given.
  def self.provision!(email_address:, password: nil)
    password = SecureRandom.base58(20) if password.blank?
    user = create!(email_address: email_address, password: password)
    [ user, password ]
  end
end
