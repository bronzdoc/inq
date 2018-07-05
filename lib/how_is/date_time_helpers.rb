# frozen_string_literal: true

require "how_is/version"
require "date"

module HowIs
  ##
  # Various helper functions for working with DateTime objects.
  module DateTimeHelpers
    def date_le(left, right)
      left  = str_to_dt(left)
      right = str_to_dt(right)

      left <= right
    end

    def date_ge(left, right)
      left  = str_to_dt(left)
      right = str_to_dt(right)

      left >= right
    end

    private

    def str_to_dt(str)
      DateTime.parse(str)
    end
  end
end
