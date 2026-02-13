class Accounts::DigestPreviewsController < ApplicationController
  before_action :ensure_can_administer

  MAX_TOPICS = 10
  MIN_TOPICS = 3

  def create
    user = User.find_by(email_address: params[:email])

    unless user
      redirect_to edit_account_url, alert: "No user found with that email."
      return
    end

    weeks_ago = params[:since].to_i
    window_start = (weeks_ago + 1).weeks.ago
    window_end = weeks_ago.weeks.ago
    cards = HomeFeed::Ranker.top(limit: 50, since: window_start)
    cards = cards.select { |card| card.created_at < window_end }.first(MAX_TOPICS)
    room_ids = cards.map(&:room_id)
    rooms = Room.where(id: room_ids).index_by(&:id)
               .then { |by_id| room_ids.filter_map { |id| by_id[id] } }

    if rooms.length < MIN_TOPICS
      redirect_to edit_account_url, alert: "Only #{rooms.length} topics found (minimum: #{MIN_TOPICS}). Try a longer time range."
      return
    end

    DigestMailer.weekly(user, rooms).deliver_now
    redirect_to edit_account_url, notice: "Digest preview sent to #{user.email_address}."
  end
end
