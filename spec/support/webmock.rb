require "webmock/rspec"

# Specs never touch the real network. Stub every request with a fixture from
# spec/fixtures/files (see CLAUDE.md). Localhost stays open for system specs.
WebMock.disable_net_connect!(allow_localhost: true)
