# JS system specs check real computed styles, so the compiled Tailwind CSS must
# exist. It's gitignored (bin/dev's watcher keeps it fresh locally); build it
# once when missing, e.g. on CI or a fresh clone.
RSpec.configure do |config|
  config.before(:suite) do
    css = Rails.root.join("app/assets/builds/tailwind.css")
    next if css.exist? && css.size.positive?

    system("bin/rails", "tailwindcss:build", exception: true, out: File::NULL)
  end
end
