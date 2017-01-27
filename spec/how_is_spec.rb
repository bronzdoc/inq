require 'spec_helper'
require 'open3'
require 'timecop'

HOW_IS_CONFIG_FILE = File.expand_path('./data/how_is.yml', __dir__)

HOW_IS_EXAMPLE_REPOSITORY_JSON_REPORT = File.expand_path('./data/how-is-example-repository-report.json', __dir__)
HOW_IS_EXAMPLE_REPOSITORY_HTML_REPORT = File.expand_path('./data/how-is-example-repository-report.html', __dir__)


HOW_IS_EXAMPLE_EMPTY_REPOSITORY_HTML_REPORT = File.expand_path('./data/how-is-example-empty-repository-report.html', __dir__)

JEKYLL_HEADER = <<-EOF
---
title: rubygems/rubygems report
layout: default
---
EOF

describe HowIs do
  before do
    # 2016-11-01 00:00:00 UTC.
    # See note in lib/how_is/report.rb about new_offset.
    # TODO: Stop pretending to always be in UTC.
    date = DateTime.parse('2016-11-01').new_offset(0)
    Timecop.freeze(date)
  end

  after do
    Timecop.return
  end

  context 'with a config file' do
    it 'generates valid report files' do
      Dir.mktmpdir {|dir|
        Dir.chdir(dir) {
         VCR.use_cassette("how-is-with-config-file") do
            expect {
              HowIs.from_config_file(YAML.load_file(HOW_IS_CONFIG_FILE))
            }.to_not output.to_stderr
          end

          html_report = File.open('report.html').read
          json_report = File.open('report.json').read

          expect(html_report).to include(JEKYLL_HEADER)
        }
      }
    end
  end

  context 'HTML report for how-is/example-repository' do
    it 'generates a valid report' do
      expected = File.open(HOW_IS_EXAMPLE_REPOSITORY_HTML_REPORT).read.chomp
      actual = nil

      VCR.use_cassette("how-is-example-repository") do
        expect {
          actual = HowIs.new('how-is/example-repository').to_html
        }.to_not output.to_stderr
      end

      expect(expected).to eq(actual)
    end
  end

  context 'JSON report for how-is/example-repository' do
    it 'generates a valid report file' do
      expected = File.open(HOW_IS_EXAMPLE_REPOSITORY_JSON_REPORT).read.chomp
      actual = nil

      VCR.use_cassette("how-is-example-repository") do
        expect {
          actual = HowIs.new('how-is/example-repository').to_json
        }.to_not output.to_stderr
      end

      expect(expected).to eq(actual)
    end
  end

  context 'HTML report for repository with no PRs or issues' do
    it 'generates a valid report file' do
      expected = File.open(HOW_IS_EXAMPLE_EMPTY_REPOSITORY_HTML_REPORT).read.chomp
      actual = nil

      VCR.use_cassette("how-is-example-empty-repository") do
        expect {
          actual = HowIs.new('how-is/example-empty-repository').to_html
        }.to_not output.to_stderr
      end

      expect(expected).to eq(actual)
    end
  end
end
