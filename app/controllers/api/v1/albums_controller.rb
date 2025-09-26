class Api::V1::AlbumsController < ApplicationController
  include Paginatable
  before_action :authorize_request
  before_action :set_album, only: [:show,:update, :destroy] 
  def index
    albums = policy_scope(Album)
               .includes(artists: :user, creator: :user, musics: [], genres: [])
               .with_attached_cover_art

    @albums = paginate(albums)

    render json: @albums,
           each_serializer: AlbumSerializer,
           meta: paginate_meta(@albums),
           adapter: :json,
           status: :ok
  end

  def show
    @album = Album.find(params[:id])
    render json: @album, serializer: AlbumSerializer, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [{ field: 'album', message: 'Album not found', type: 'not_found' }] }, status: :not_found
  end

  def all
    authorize Album, :all_albums?
    @albums = Album.includes(artists: :user, creator: :user, musics: [], genres: []).with_attached_cover_art
    render json: @albums, each_serializer: AlbumSerializer, status: :ok
  end
    
    
  def create 

    cover_art = album_params[:cover_art]
    @album = Album.new(album_params.except(:artist_ids, :music_ids, :genres, :cover_art))
    current_artist = current_user.artist
    unless current_artist
      return render json: {error: "Only artists can create album"}, status: :forbidden
    end
    @album.creator = current_artist

    requested_artist_ids = Array(album_params[:artist_ids]).map(&:to_i)
    requested_artist_ids << current_artist.id
    requested_artist_ids.uniq!

    valid_artist_ids = Artist.where(id: requested_artist_ids).pluck(:id)
    if valid_artist_ids.empty?
      return render json: {error: "No valid artist ids provided"}, status: :unprocessable_entity
    end
    @album.artist_ids = valid_artist_ids

    if album_params[:music_ids].present?
      requested_music_ids = Array(album_params[:music_ids]).map(&:to_i)
      valid_music_ids = Music.where(id: requested_music_ids).pluck(:id)
      @album.music_ids = valid_music_ids
    end

    if album_params[:genres].present?
        genres = find_or_create_genres(album_params[:genres])
        @album.genres = genres
    end

    if cover_art.present?
      Rails.logger.info "Attaching cover_art: #{cover_art.inspect}"
      @album.cover_art.attach(cover_art)
    end


    authorize @album

    if @album.save 
      render json: @album, serializer: AlbumSerializer, status: :created
    else 
      render json: { errors: formatted_errors(@album) }, status: :unprocessable_entity
    end
  rescue Pundit::NotAuthorizedError
    render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden
  end


  def update
    begin
      @album = Album.find(params[:id])
      authorize @album

      if album_params.key?(:artist_ids)
        collaborator_ids = Array(album_params[:artist_ids]).map(&:to_i)
        collaborator_ids << @album.creator.id if @album.creator
        collaborator_ids.uniq! 
        @album.artist_ids = Artist.where(id: collaborator_ids).pluck(:id)
      end

      if album_params[:music_ids].present?
        @album.album_ids = Music.where(id: Array(album_params[:music_ids]).map(&:to_i)).pluck(:id)
      end

      if album_params[:genres].present?
        @album.genres = find_or_create_genres(album_params[:genres])
      end

      if album_params[:cover_art].present?
        Rails.logger.info "Purging existing cover_art" if @album.cover_art.attached?
        @album.cover_art.purge if @album.cover_art.attached?
        @album.cover_art.attach(album_params[:cover_art])
      end

      if @album.update(album_params.except(:artist_ids, :music_ids, :genres))
        render json: @album, serializer: AlbumSerializer, status: :ok
      else
        render json: { errors: formatted_errors(@album) }, status: :unprocessable_entity
      end
    rescue Pundit::NotAuthorizedError
      render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden
    rescue ActiveRecord::RecordNotFound
      render json: { errors: [{ field: 'album', message: 'Album not found', type: 'not_found' }] }, status: :not_found
    end
  end

  def destroy
      @album = Album.find(params[:id])
      authorize @album

      @album.destroy
      render json: { message: "Album deleted successfully" }, status: :ok
    rescue Pundit::NotAuthorizedError
      render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden
    rescue ActiveRecord::RecordNotFound
      render json: { errors: [{ field: 'album', message: 'Album not found', type: 'not_found' }] }, status: :not_found
    rescue => e
      render json: { errors: [{ field: 'server', message: e.message, type: 'internal_error' }] }, status: :internal_server_error
  end

  private 
  def set_album
    @album = Album.find(params[:id]) 
  end
  def album_params 
      params.require(:album).permit(
          :name, :release_date, :cover_art, artist_ids:[], genres:[], music_ids:[]
      )
  end

  def find_or_create_genres(genre_names)
    genre_names.map do |name|
      Genre.find_or_create_by!(name:name.strip.downcase)
    end
  end  
end


