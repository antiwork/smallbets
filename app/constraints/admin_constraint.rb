class AdminConstraint
  # TODO: Remove once the feed becomes available to everyone.
  def matches?(request)
    user_id = request.session[:user_id]
    return false unless user_id

    user = User.find_by(id: user_id)
    user&.administrator?
  rescue => error
    Rails.logger.warn("admin_constraint_error=#{error.class} message=#{error.message}")
    false
  end
end
