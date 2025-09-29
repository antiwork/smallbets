class RoomsController < ApplicationController
  before_action :set_room, only: %i[ edit update show destroy ]
  before_action :set_membership, only: %i[ show ]
  before_action :ensure_has_real_name, only: %i[ show ]
  before_action :ensure_can_administer, only: %i[ update destroy ]
  before_action :remember_last_room_visited, only: %i[ show ]

  def index
    redirect_to room_url(Current.user.rooms.last)
  end

  def show
    # Redirect to canonical slug URL when available, unless viewing a specific message
    if params[:message_id].blank? && @room.slug.present? && params[:slug].blank?
      target = room_slug_url(@room.slug)
      target = target + "?" + request.query_string if request.query_string.present?
      return redirect_to(target)
    end

    @messages = Bookmark.populate_for(find_messages)
  end

  def destroy
    deactivate_room
    redirect_to root_url
  end

  private
    def deactivate_room
      @room.deactivate

      broadcast_remove_room
    end

    def set_room
      identifier = params[:room_id] || params[:id] || params[:slug]

      # Try by numeric id first (preserve existing behavior)
      room = Current.user.rooms.find_by(id: identifier)

      # Fallback to slug-based lookup when identifier is not a numeric id
      if room.nil?
        room = Current.user.rooms.find_by(slug: identifier)
      end

      if room
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
      messages = @room.messages
                      .with_rich_text_body_and_embeds
                      .with_attached_attachment
                      .preload(creator: :avatar_attachment)
                      .includes(attachment_blob: :variant_records)
                      .includes(:mentionees, boosts: :booster)
      @first_unread_message = messages.ordered.since(@membership.unread_at).first if @membership.unread?

      if show_first_message = messages.find_by(id: params[:message_id]) || @first_unread_message
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def room_params
      permitted = [ :name ]
      permitted << :slug if Current.user.administrator?
      params.require(:room).permit(*permitted)
    end

    def broadcast_remove_room
      for_each_sidebar_section do |list_name|
        broadcast_remove_to :rooms, target: [ @room, helpers.dom_prefix(list_name, :list_node) ]
      end
    end
end
