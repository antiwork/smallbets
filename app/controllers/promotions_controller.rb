class PromotionsController < AuthenticatedController
  before_action :require_administrator

  def create
    message_id = params[:message_id] || params.dig(:promotion, :message_id)
    return redirect_back(fallback_location: root_path, alert: "Message ID is required") unless message_id.present?

    message = Message.find_by(id: message_id)
    return redirect_back(fallback_location: root_path, alert: "Message not found") unless message

    if message.room.conversation_room?
      return redirect_back(fallback_location: root_path, alert: "Cannot promote a message from a conversation room")
    end

    result = ConversationDetector.detect(promoted_message_id: message_id.to_i)

    room_result = RoomCreator.create_conversation_room(
      message_ids: result[:message_ids],
      title: result[:title],
      summary: result[:summary],
      key_insight: result[:key_insight],
      preview_message_id: result[:preview_message_id],
      type: "promoted",
      promoted_by: Current.user
    )

    redirect_back fallback_location: room_path(room_result[:room]), notice: "Promoted to Home"
  rescue ConversationDetector::NotFoundError => e
    Rails.logger.error "[PromotionsController] Message not found: #{e.message}"
    redirect_back(fallback_location: root_path, alert: "Message not found")
  rescue ConversationDetector::Error, AIGateway::Error => e
    Rails.logger.error "[PromotionsController] AI error: #{e.class} - #{e.message}"
    redirect_back(fallback_location: root_path, alert: "AI processing failed. Please try again or use manual promotion.")
  rescue RoomCreator::Error => e
    Rails.logger.error "[PromotionsController] Room creation error: #{e.class} - #{e.message}"
    redirect_back(fallback_location: root_path, alert: "Failed to create conversation room: #{e.message}")
  end

  private

  def require_administrator
    head :forbidden unless Current.user&.administrator?
  end
end
