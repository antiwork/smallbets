# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Facade query for all system metrics (application + system resources)
      # Combines ApplicationMetricsQuery and SystemResourcesQuery
      class SystemMetricsQuery
        # Calculate all system metrics
        # @return [Hash] hash with all system metrics
        def self.call
          new.call
        end

        def call
          ApplicationMetricsQuery.call.merge(SystemResourcesQuery.call)
        end
      end
    end
  end
end
