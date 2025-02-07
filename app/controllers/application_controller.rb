class ApplicationController < ActionController::Base
  include AllowBrowser, Authentication, Authorization, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders, FragmentCache, Sidebar
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName

  # By default, no authentication required
  # Controllers that need auth will call require_authentication
end
