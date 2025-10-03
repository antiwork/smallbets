class Messages::GiphyController < MessagesController
  def search
    query = params[:query]
    response = Faraday.get(
      "https://api.giphy.com/v1/gifs/search",
      {
        q: query,
        limit: 10,
        api_key: Rails.application.credentials[:giphy_api_key]
      }
    )

    if response.success?
      render json: JSON.parse(response.body)
    else
      Rails.logger.info response
      render json: { error: "Failed to fetch data" }, status: :bad_gateway
    end
  end
end
