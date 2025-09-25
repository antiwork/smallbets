class LibraryController < ApplicationController
  def index
    @sections = LibraryCatalog.sections
  end

  def download
    url = Vimeo::Library.fetch_download_url(params[:id], params[:quality])

    if url
      redirect_to url, allow_other_host: true
    else
      head :not_found
    end
  end

  def downloads
    downloads = Vimeo::Library.fetch_downloads(params[:id])

    if downloads.blank?
      head :not_found
    else
      render json: downloads
    end
  end

  private

end
