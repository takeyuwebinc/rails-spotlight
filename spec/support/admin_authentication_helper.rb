# frozen_string_literal: true

module AdminAuthenticationHelper
  def sign_in_admin(email: "test@takeyuweb.co.jp", name: "Test Admin")
    # Setup OmniAuth mock and perform the callback
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "123456789",
      info: {
        email: email,
        name: name
      },
      credentials: {
        token: "mock_token",
        expires_at: Time.now.to_i + 3600
      }
    })

    get "/admin/auth/google_oauth2/callback"
  end
end

RSpec.configure do |config|
  config.include AdminAuthenticationHelper, type: :request

  # Enable OmniAuth test mode for request specs
  config.before(:each, type: :request) do
    OmniAuth.config.test_mode = true
  end

  config.after(:each, type: :request) do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
end
