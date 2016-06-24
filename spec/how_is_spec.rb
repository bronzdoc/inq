require 'spec_helper'

describe HowIs do
  let(:issues) { JSON.parse(open(File.expand_path('./data/issues.json', __dir__)).read) }
  let(:pulls) { JSON.parse(open(File.expand_path('./data/pulls.json', __dir__)).read) }

  let(:github) {
    instance_double('GitHub',
      issues: instance_double('GitHub::Issues', list: issues),
      pulls: instance_double('GitHub::Pulls', list: pulls)
    )
  }


  context '.generate_report' do
    it 'generates a correct JSON report' do
      report = HowIs.generate_report(
        repository: 'rubygems/rubygems',
        github: github,
        format: :json,
      )

      expected_report = open('data/how_is_spec/generate_report--generates-a-correct-JSON-report.json').read.strip

      expect(report).to eq(expected_report)
    end
  end
end
