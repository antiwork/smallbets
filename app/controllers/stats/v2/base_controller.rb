# frozen_string_literal: true

module Stats
  module V2
    # Base controller for Stats V2
    # Follows Single Responsibility Principle - provides common controller behavior
    class BaseController < ApplicationController
      layout 'application'
    end
  end
end
