class ApplicationController < ActionController::Base
  include AllowBrowser, RackMiniProfilerAuthorization, Authentication, Authorization, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders, FragmentCache, Sidebar
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName

  before_action :load_current_live_event

  private

  def load_current_live_event
    @current_live_event = LiveEvent.current
  end

  def inertia_request?
    request.headers['X-Inertia'].present?
  end
end
