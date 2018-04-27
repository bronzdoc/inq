# frozen_string_literal: true

require "how_is/version"
require "how_is/sources/github"
require "how_is/sources/github_helpers"
require "date"

module HowIs::Sources
  class Github
    # Fetch information about who has contributed to a repository during a given
    # period.
    #
    # Usage:
    #
    #     c = HowIs::Contributions.new(start_date: '2017-07-01', user: 'how-is', repo: 'how_is')
    #     c.commits          #=> All commits during July 2017.
    #     c.contributors #=> All contributors during July 2017.
    #     c.new_contributors #=> New contributors during July 2017.
    class Contributions
      include HowIs::Sources::GithubHelpers

      # Returns an object that fetches contributor information about a particular
      # repository for a month-long period starting on +start_date+.
      #
      # @param repository [String] GitHub repository in the form of "user/repo".
      # @param start_date [String] Date in the format YYYY-MM-DD. The first date
      #                            to include commits from.
      # @param end_date [String] Date in the format YYYY-MM-DD. The last date
      #                          to include commits from.
      def initialize(repository, start_date, end_date)
        @user, @repo = repository.split("/")
        @github = ::Github.new(auto_pagination: true) do |config|
          config.basic_auth = HowIs::Sources::Github::BASIC_AUTH
        end

        # IMPL. DETAIL: The external API uses "end_date" so it's clearer,
        #               but internally we use "until_date" to match GitHub's API.
        @since_date = start_date
        @until_date = end_date

        @commit = {}
        @stats = nil
        @changed_files = nil
      end

      # Returns a list of contributors that have zero commits before the @since_date.
      #
      # @return [Hash{String => Hash}] Contributors keyed by email
      def new_contributors
        # author: GitHub login, name or email by which to filter by commit author.
        @new_contributors ||= contributors.select do |email, _committer|
          # Returns true if +email+ never wrote a commit for +@repo+ before +@since_date+.
          @github.repos.commits.list(user: @user,
                                    repo: @repo,
                                    until: @since_date,
                                    author: email).count.zero?
        end
      end

      # @return [Hash{String => Hash}] Author information keyed by author's email.
      def contributors
        commits.map { |api_response|
          [api_response.commit.author.email, api_response.commit.author.to_h]
        }.to_h
      end

      def commits
        @commits ||= begin
          @github.repos.commits.list(user: @user,
                                    repo: @repo,
                                    since: @since_date,
                                    until: @until_date).map { |c|
            # The commits list endpoint doesn't include all commit data, e.g. stats.
            # So, we make N requests here, where N == number of commits returned,
            # and then we die a bit inside.
            commit(c.sha)
          }
        end
      end

      def commit(sha)
        @commit[sha] ||= @github.repos.commits.get(user: @user, repo: @repo, sha: sha)
      end

      def changes
        if @stats.nil? || @changed_files.nil?
          @stats = {
            "total" => 0,
            "additions" => 0,
            "deletions" => 0,
          }

          @changed_files = []

          commits.map do |commit|
            @stats.keys.each do |key|
              @stats[key] += commit.stats[key]
            end

            @changed_files += commit.files.map { |file| file["filename"] }
          end

          @changed_files = @changed_files.sort.uniq
        end

        {"stats" => @stats, "files" => @changed_files}
      end

      def changed_files
        changes["files"]
      end

      def additions_count
        changes["stats"]["additions"]
      end

      def deletions_count
        changes["stats"]["deletions"]
      end

      def compare_url
        "https://github.com/#{@user}/#{@repo}/compare/#{default_branch}@%7B#{@since_date}%7D...#{default_branch}@%7B#{@until_date}%7D" # rubocop:disable Metrics/LineLength
      end

      def default_branch
        @default_branch ||= @github.repos.get(user: @user,
          repo: @repo).default_branch
      end

      def to_html(start_text: nil)
        start_text ||= "From #{pretty_date(@since_date)} through #{pretty_date(@until_date)}"

        "#{start_text}, #{@user}/#{@repo} gained "\
          "<a href=\"#{compare_url}\">#{pluralize('new commit', commits.length)}</a>, " \
          "contributed by #{pluralize('author', contributors.length)}. There " \
          "#{(additions_count == 1) ? 'was' : 'were'} " \
          "#{pluralize('addition', additions_count)} and " \
          "#{pluralize('deletion', deletions_count)} across " \
          "#{pluralize('file', changed_files.length)}."
      end

      private

      def date_to_dt(date)
        DateTime.strptime(date, "%Y-%m-%d")
      end

      def timestamp_for(date)
        date_to_dt(date).strftime("%s")
      end

      def pretty_date(date)
        date_to_dt(date).strftime("%b %d, %Y")
      end
    end
  end
end