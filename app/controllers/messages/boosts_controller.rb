class Messages::BoostsController < ApplicationController
  include NotifyBots

  before_action :set_message

  def index
  end

  def new
  end

  def create
    @source_boost = Boost.active.find_by(id: params[:source_boost_id])
    @boost = @message.boosts.create!(boost_params)

    broadcast_create
    deliver_webhooks_to_bots(@boost, :created)
  end

  def destroy
    @boost = Current.user.boosts.find(params[:id])
    @boost.deactivate!

    broadcast_remove
    deliver_webhooks_to_bots(@boost, :deleted)
  end

  private
    def set_message
      @message = Current.user.reachable_messages.find(params[:message_id])
    end

    def boost_params
      params.require(:boost).permit(:content)
    end

    def broadcast_create
      boost_html = render_to_string(partial: "messages/boosts/boost", locals: { boost: @boost })

      @boost.broadcast_append_to @boost.message.room, :messages,
        target: "boosts_message_#{@boost.message.client_message_id}", html: boost_html

      @boost.broadcast_append_to :inbox, target: "boosts_message_#{@boost.message.client_message_id}",
                                 html: boost_html
    end

    def broadcast_remove
      @boost.broadcast_remove_to @boost.message.room, :messages
      @boost.broadcast_remove_to :inbox
    end
end
