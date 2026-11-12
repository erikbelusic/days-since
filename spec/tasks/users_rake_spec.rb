require "rails_helper"
require "rake"

RSpec.describe "users:create" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("users:create") }
  after { Rake::Task["users:create"].reenable }

  def run_task(env)
    saved = ENV.to_h.slice(*env.keys)
    env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    stdout = StringIO.new
    original_stdout, $stdout = $stdout, stdout
    Rake::Task["users:create"].invoke
    stdout.string
  ensure
    $stdout = original_stdout
    env.each_key { |key| saved.key?(key) ? ENV[key] = saved[key] : ENV.delete(key) }
  end

  it "creates a user who can sign in with the given password" do
    run_task("EMAIL" => "admin@example.com", "PASSWORD" => "chosen-pass")

    expect(User.authenticate_by(email_address: "admin@example.com", password: "chosen-pass")).to be_present
  end

  it "generates and prints a password when none is given" do
    output = run_task("EMAIL" => "new@example.com", "PASSWORD" => nil)

    password = output[/Password: (\S+)/, 1]
    expect(User.authenticate_by(email_address: "new@example.com", password: password)).to be_present
  end

  it "refuses a duplicate email address" do
    create(:user, email_address: "taken@example.com")

    expect { run_task("EMAIL" => "taken@example.com", "PASSWORD" => "x-pass") }
      .to raise_error(SystemExit).and output(/Could not create user/).to_stderr
  end
end
