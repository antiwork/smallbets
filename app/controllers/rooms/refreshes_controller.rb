class Rooms::RefreshesController < ApplicationController
  include RoomScoped

  before_action :set_last_updated_at
  before_action :set_unread_at_message

  def show
    @new_messages = Bookmark.populate_for(@room.messages.with_threads.with_creator.with_original_message.page_created_since(@last_updated_at))
    @updated_messages = Bookmark.populate_for(@room.messages.without(@new_messages).with_threads.with_creator.with_original_message.page_updated_since(@last_updated_at))
  end

  private
    def set_last_updated_at
      @last_updated_at = Time.at(0, params[:since].to_i, :millisecond)
    end

    def set_unread_at_message
      return if params[:unread_at_message_id].blank?

      @unread_at_message = Message.find_by(id: params[:unread_at_message_id])
    end
end
