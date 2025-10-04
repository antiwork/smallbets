class Messages::GiphyController < MessagesController
  def search
    query = params[:query]
    room_id = params[:room_id]

    response = Faraday.get(
      "https://api.giphy.com/v1/gifs/search",
      {
        q: query,
        limit: 10,
        api_key: Rails.application.credentials[:giphy_api_key]
      }
    )

    if response.success?
      data = JSON.parse(response.body)
      gifs = data["data"].map { |gif| gif["images"]["fixed_height"]["url"] }

      session[:giphy_results] = {
        gifs: gifs,
        index: 0,
        query: query,
        room_id: room_id
      }

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "messages_rooms_open_#{room_id}",
            partial: "messages/giphy_preview",
            locals: { gif_url: gifs[0], query: query }
          )
        end
      end
    else
      Rails.logger.info response
      render json: { error: "Failed to fetch data" }, status: :bad_gateway
    end
  end

  def navigate
    direction = params[:direction].to_i
    giphy_results = session[:giphy_results]

    return head :bad_request unless giphy_results

    new_index = (giphy_results["index"] + direction) % giphy_results["gifs"].length
    session[:giphy_results]["index"] = new_index

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "giphy_preview",
          partial: "messages/giphy_preview",
          locals: {
            gif_url: giphy_results["gifs"][new_index],
            query: giphy_results["query"],
            room_id: giphy_results["room_id"]
          }
        )
      end
    end
  end

  def remove
    session.delete(:giphy_results)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("giphy_preview")
      end
    end
  end
end
