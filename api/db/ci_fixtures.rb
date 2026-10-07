# frozen_string_literal: true

# Test data for the black-box API tests in web/test/api.
# Run after db:seed (which creates the "test-corp" organization):
#
#   bundle exec rails runner db/ci_fixtures.rb
#
# Safe to re-run.

other = Organization.find_or_create_by!(scheme: 'other-corp') do |org|
  org.name       = 'Other Corp'
  org.identifier = 'other-corp'
  org.host       = 'other.localhost'
end

admin = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'password123'
  user.role     = 'admin'
end

puts "CI fixtures ready: organizations=#{Organization.pluck(:scheme).join(', ')} " \
     "(added #{other.scheme}), admin=#{admin.email}"
