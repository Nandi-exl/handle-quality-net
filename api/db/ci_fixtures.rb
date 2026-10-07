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

# Users belong to exactly one organization; the test admin belongs to test-corp.
org_a = Organization.find_by!(scheme: 'test-corp')
admin.update!(organization: org_a)

other_admin = User.find_or_create_by!(email: 'other-admin@example.com') do |user|
  user.password = 'password123'
  user.role     = 'admin'
  user.organization = other
end
other_admin.update!(organization: other)

# F-03: a completed portfolio owned by test-corp, so another organization
# can be checked against a record that really exists.
assessment = Assessment.unscoped.find_or_create_by!(name: 'F-03 probe', tenant_id: org_a.id) do |record|
  record.created_by     = admin.id
  record.time_limit_min = 30
end

session = Session.unscoped.find_by(assessment_id: assessment.id, tenant_id: org_a.id)
session ||= Session.create!(tenant_id: org_a.id, assessment: assessment, status: 'ended')

portfolio = session.portfolio || Portfolio.create!(
  session:            session,
  generation_status:  'complete',
  generated_at:       Time.current
)
portfolio.update!(generation_status: 'complete') unless portfolio.complete?

unless portfolio.portfolio_skills.exists?(skill_label: 'Ruby')
  PortfolioSkill.create!(
    portfolio:           portfolio,
    skill_label:         'Ruby',
    ai_level:            3,
    ai_confidence:       'medium',
    competency_summary:  'probe'
  )
end

puts "CI fixtures ready: organizations=#{Organization.pluck(:scheme).join(', ')} " \
     "(added #{other.scheme}), admins=#{admin.email}, #{other_admin.email}, " \
     "portfolio=#{portfolio.id}"
