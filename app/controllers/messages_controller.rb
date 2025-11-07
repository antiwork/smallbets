class MessagesController < ApplicationController
  include ActiveStorage::SetCurrent, RoomScoped, NotifyBots

  before_action :set_room, only: %i[ index create destroy ]
  before_action :set_room_if_found, only: %i[ show edit update ]
  before_action :set_message, only: %i[ show edit update destroy ]
  before_action :ensure_can_administer, only: %i[ edit update destroy ]

  layout false, only: :index

  def index
    @messages = Bookmark.populate_for(find_paged_messages)

    head :no_content if @messages.blank?
  end

  def create
    set_room
    @message = @room.messages.create_with_attachment(message_params)

    if @message.persisted?
      @message.broadcast_create
      broadcast_update_message_involvements
      deliver_webhooks_to_bots(@message, :created)
    else
      render action: :not_allowed
    end
  rescue ActiveRecord::RecordNotFound
    render action: :room_not_found
  end

  def show
  end

  def edit
  end

  def update
    @message.update!(message_params)

    presentation_html = render_to_string(partial: "messages/presentation", locals: { message: @message })
    @message.broadcast_replace_to @message.room, :messages, target: [ @message, :presentation ], html: presentation_html, attributes: { maintain_scroll: true }
    @message.broadcast_replace_to :inbox, target: [ @message, :presentation ], html: presentation_html, attributes: { maintain_scroll: true }
    broadcast_update_message_involvements
    deliver_webhooks_to_bots(@message, :updated)

    redirect_to @room ? room_message_url(@room, @message) : @message
  end

  def destroy
    @message.deactivate
    @message.broadcast_remove_to @room, :messages
    @message.broadcast_remove_to :inbox
    deliver_webhooks_to_bots(@message, :deleted)
  end

  private
    def set_message
      if @room
        @message = @room.messages.find(params[:id])
      else
        @message = Current.user.reachable_messages.find(params[:id])
      end
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@message)
    end


    def find_paged_messages
      messages = case
      when params[:before].present?
        @room.messages.with_threads.with_creator.with_original_message.page_before(@room.messages.find(params[:before]))
      when params[:after].present?
        @room.messages.with_threads.with_creator.with_original_message.page_after(@room.messages.find(params[:after]))
      else
        @room.messages.with_threads.with_creator.with_original_message.last_page
      end

      # If this is a thread and we've loaded the very first message, prepend the parent message
      if @room.thread? && messages.any? && @room.parent_message.present?
        first_thread_message = @room.messages.ordered.first
        messages_array = messages.to_a
        if messages_array.first&.id == first_thread_message&.id
          [@room.parent_message] + messages_array
        else
          messages_array
        end
      else
        messages
      end
    end

    def message_params
      params.require(:message).permit(:body, :attachment, :client_message_id)
    end

    def broadcast_update_message_involvements
      @message.mentionees.each do |user|
        refresh_shared_rooms(user)
      end
    end

    def refresh_shared_rooms(user)
      memberships = user.memberships.shared.visible
      {
        starred_rooms: memberships.with_room_by_last_active_newest_first,
        shared_rooms: memberships.with_room_by_last_active_newest_first
      }.each do |list_name, memberships|
        user.broadcast_replace_to user, :rooms, target: list_name,
                                  partial: "users/sidebars/rooms/shared_rooms_list",
                                  locals: { list_name:, memberships: },
                                  attributes: { maintain_scroll: true }
      end
    end
end
