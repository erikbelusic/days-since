namespace :users do
  desc "Create a user account: bin/rails users:create EMAIL=someone@example.com [PASSWORD=secret]"
  task create: :environment do
    email = ENV["EMAIL"].to_s
    abort "Usage: bin/rails users:create EMAIL=someone@example.com [PASSWORD=secret]" if email.blank?

    user, password = User.provision!(email_address: email, password: ENV["PASSWORD"])
    puts "Created #{user.email_address}"
    puts "Password: #{password}" if ENV["PASSWORD"].blank?
  rescue ActiveRecord::RecordInvalid => e
    abort "Could not create user: #{e.record.errors.full_messages.to_sentence}"
  end
end
