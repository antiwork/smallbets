# frozen_string_literal: true

module Stats
  module V2
    # Base controller for Stats V2
    class BaseController < ApplicationController
      layout 'application'

      PERIODS = [:today, :month, :year, :all_time].freeze

      # Returns human-readable title for a period
      # @param period [Symbol] the period (:today, :month, :year, :all_time)
      # @return [String] the title
      def self.period_title(period)
        case period
        when :today then "Today"
        when :month then "This Month"
        when :year then "This Year"
        when :all_time then "All Time"
        end
      end

      # Instance method wrapper for period_title
      def period_title(period)
        self.class.period_title(period)
      end
      helper_method :period_title
    end
  end
end
