# frozen_string_literal: true

# F-04 (assessment/01-audit.md): invalid or missing AI skill levels are
# saved as real L1–L5 scores.
#
# Required behaviour (assumption, not in spec): a missing or out-of-range
# level is not a score, so that skill is not saved. A valid skill in the
# same response still is, and the portfolio can complete. Fit/gap then
# treats the missing skill as not assessed.
#
# These assertions describe behaviour, not a specific fix.

require 'rails_helper'

RSpec.describe Portfolios::Generator, 'F-04: invalid skill levels are not saved as scores' do
  def skill(label, level)
    {
      'skill_label'        => label,
      'level'              => level,
      'confidence'         => 'low',
      'evidence'           => [],
      'competency_summary' => 'probe'
    }
  end

  def generate_with(payload)
    org = Organization.find_or_create_by!(scheme: 'f04-test') do |record|
      record.name       = 'F04 Test'
      record.identifier = 'f04-test'
      record.host       = 'f04.localhost'
    end
    admin = User.find_or_create_by!(email: 'f04@example.com') do |user|
      user.password = 'password123'
      user.role     = 'admin'
    end
    assessment = Assessment.unscoped.create!(
      tenant_id:      org.id,
      created_by:     admin.id,
      name:           'F-04 probe',
      time_limit_min: 30
    )
    session = Session.unscoped.create!(
      tenant_id:  org.id,
      assessment: assessment,
      status:     'ended'
    )

    client = Object.new
    client.define_singleton_method(:generate_content) { |*_args, **_opts| payload }

    described_class.new(session: session, gemini_client: client).call
  end

  # Positive control: a real L3 must still be stored. Stops a "fix" that
  # simply stops saving skills, or fails the whole portfolio, from going green.
  it 'still saves a skill whose level is a real 1–5 score' do
    portfolio = generate_with(
      'configured_skills' => [skill('Valid', 3)],
      'discovered_skills' => []
    )

    expect(portfolio.generation_status).to eq('complete')
    expect(portfolio.portfolio_skills.pluck(:skill_label, :ai_level)).to eq([['Valid', 3]])
  end

  it 'does not invent L1 for a missing or unreadable level' do
    portfolio = generate_with(
      'configured_skills' => [
        skill('Missing level', nil),
        skill('Not assessed', 'N/A'),
        skill('Zero', 0),
        skill('Valid', 3)
      ],
      'discovered_skills' => []
    )

    saved = portfolio.portfolio_skills.pluck(:skill_label, :ai_level)
    expect(saved).not_to include(['Missing level', 1], ['Not assessed', 1], ['Zero', 1])
    expect(saved).to include(['Valid', 3])
  end

  it 'does not invent L5 for a level above 5' do
    portfolio = generate_with(
      'configured_skills' => [skill('Too high', 9), skill('Valid', 3)],
      'discovered_skills' => []
    )

    saved = portfolio.portfolio_skills.pluck(:skill_label, :ai_level)
    expect(saved).not_to include(['Too high', 5])
    expect(saved).to include(['Valid', 3])
  end
end
