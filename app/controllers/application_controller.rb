class ApplicationController < ActionController::Base
  include AllowBrowser, RackMiniProfilerAuthorization, Authentication, Authorization, SetCurrentRequest, SetPlatform, TrackedRoomVisit, VersionHeaders, FragmentCache, Sidebar
  include Turbo::Streams::Broadcasts, Turbo::Streams::StreamName

  before_action :load_current_live_event

  private

  # TODO: Remove once the feed becomes available to everyone.
  def enforce_feed_conversation_access!(room)
    return false unless room&.conversation_room?
    return false if Current.user&.administrator?

    if request.format.html? || request.format.turbo_stream?
      redirect_to talk_path, status: :see_other
    else
      head :forbidden
    end

    true
  end

  def load_current_live_event
    @current_live_event = LiveEvent.current
  end

  def inertia_request?
    request.headers['X-Inertia'].present?
  end
end
