# frozen_string_literal: true

class Rack::Attack
  # Use Redis for distributed throttle state across pods.
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  )

  # Throttle login attempts per IP.
  # The default stays 5 per minute. The black-box suite logs in once per test
  # from a single IP, so the API tests workflow sets AUTH_LOGIN_LIMIT higher.
  # Unset, this stays 5. It does not change the F-02 or F-03 assertions.
  throttle('auth/login', limit: ENV.fetch('AUTH_LOGIN_LIMIT', 5).to_i, period: 1.minute) do |req|
    req.ip if req.path == '/api/v1/auth/login' && req.post?
  end

  # Throttle candidate-facing endpoints: 30 per minute per IP.
  throttle('candidate/session', limit: 30, period: 1.minute) do |req|
    req.ip if req.path.match?(%r{\A/api/v1/sessions/[^/]+/(candidate|audio_complete)\z})
  end

  # Return 429 JSON instead of the default plain-text response.
  self.throttled_responder = lambda do |_req|
    [
      429,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Too many requests. Please try again later.' }.to_json]
    ]
  end
end
