class AuthenticatedController < ApplicationController
  before_action :require_authentication
end
