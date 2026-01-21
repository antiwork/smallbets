# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Base class for all Stats V2 query objects
      class BaseQuery
        # Class method for convenient query execution
        # @param args [Hash] arguments to pass to initializer
        # @return [ActiveRecord::Relation, Array, Hash] query results
        def self.call(**args)
          new(**args).call
        end

        # Abstract method to be implemented by subclasses
        # @raise NotImplementedError
        def call
          raise NotImplementedError, "#{self.class} must implement #call"
        end

        private

        # Returns time range for a given period
        # @param period [Symbol] one of :today, :month, :year, :all_time
        # @return [Range, nil] time range or nil for all_time
        # @raise ArgumentError if period is unknown
        def time_range_for_period(period)
          case period.to_sym
          when :today
            Time.current.beginning_of_day..Time.current.end_of_day
          when :month
            Time.current.beginning_of_month..Time.current.end_of_month
          when :year
            Time.current.beginning_of_year..Time.current.end_of_year
          when :all_time
            nil # No time restriction
          else
            raise ArgumentError, "Unknown period: #{period}"
          end
        end

        # Returns formatted date string for today (SQLite optimization)
        # @return [String] date in YYYY-MM-DD format
        def today_date_string
          Time.current.strftime('%Y-%m-%d')
        end
      end
    end
  end
end
