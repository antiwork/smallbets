class RoomsController < ApplicationController
  require_authentication
  before_action :set_room, only: %i[ edit update show destroy ]
  before_action :set_membership, only: %i[ show ]
  before_action :ensure_has_real_name, only: %i[ show ]
  before_action :ensure_can_administer, only: %i[ update destroy ]
  before_action :remember_last_room_visited, only: :show

  def index
    redirect_to room_url(Current.user.rooms.last)
  end

  def show
    @messages = Bookmark.populate_for(find_messages)
  end

  def destroy
    deactivate_room
    redirect_to root_url
  end

  private
    def deactivate_room
      @room.parent_message&.touch
      @room.deactivate

      broadcast_remove_room
      broadcast_update_parent_message
    end
  
    def set_room
      if room = Current.user.rooms.find_by(id: params[:room_id] || params[:id])
        @room = room
      else
        redirect_to root_url, alert: "Room not found or inaccessible"
      end
    end
  
    def set_membership
      @membership = Membership.find_by(room_id: @room.id, user_id: Current.user.id)
    end

    def ensure_has_real_name
      redirect_to user_profile_path, alert: "Please enter your name" if Current.user.default_name?
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def find_messages
      messages = @room.messages_with_parent.with_threads.with_creator.includes(:mentionees)
      @first_unread_message = messages.ordered.since(@membership.unread_at).first if @membership.unread?

      if show_first_message = messages.find_by(id: params[:message_id]) || @first_unread_message 
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def room_params
      params.require(:room).permit(:name)
    end

    def broadcast_remove_room
      for_each_sidebar_section do |list_name|
        broadcast_remove_to :rooms, target: [@room, helpers.dom_prefix(list_name, :list_node)]
      end
    end
  
    def broadcast_update_parent_message
      if @room.thread?
        threads_html = render_to_string(partial: "messages/threads", locals: { message: @room.parent_message })

        @room.parent_message.broadcast_replace_to @room.parent_message.room, :messages, target: [@room.parent_message, :threads], html: threads_html, attributes: { maintain_scroll: true }
        @room.parent_message.broadcast_replace_to :inbox, target: [@room.parent_message, :threads], html: threads_html, attributes: { maintain_scroll: true }
      end
    end
end
