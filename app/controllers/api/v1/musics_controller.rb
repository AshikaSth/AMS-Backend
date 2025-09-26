class Api::V1::MusicsController < ApplicationController
  include Paginatable
  before_action :authorize_request 
  before_action :set_music, only: [:show, :update, :destroy]
  def index
    musics = policy_scope(Music)
               .includes(:artists, :albums, :genres)
               .with_attached_cover_art
               .with_attached_audio

    @musics = paginate(musics)

    render json: @musics,
           each_serializer: MusicSerializer,
           meta: paginate_meta(@musics),
           adapter: :json,
           status: :ok
  end

  def show
    @music = Music.find(params[:id])
    render json: @music, serializer: MusicSerializer, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [{ field: 'music', message: 'Music not found', type: 'not_found' }] }, status: :not_found
  end

  def all
    authorize Music, :all_musics?
    @musics = Music.includes(:artists, :albums, :genres)
               .with_attached_cover_art
               .with_attached_audio
    render json: @musics, each_serializer: MusicSerializer, status: :ok
  end
      
  def create 
    @music = Music.new(music_params.except(:artist_ids, :album_ids, :genres, :cover_art, :audio))
    current_artist = current_user.artist

    unless current_artist
      return render json: { errors: [{ field: 'artist', message: 'Only artists can create music', type: 'authorization_error' }] }, status: :forbidden
    end
    @music.creator = current_artist

    requested_artist_ids = Array(music_params[:artist_ids]).map(&:to_i)
    requested_artist_ids << current_artist.id
    requested_artist_ids.uniq!

    valid_artist_ids = Artist.where(id: requested_artist_ids).pluck(:id)
    if valid_artist_ids.empty?
      return render json: { errors: [{ field: 'artist_ids', message: 'No valid artist ids provided', type: 'validation_error' }] }, status: :unprocessable_entity
    end
    @music.artist_ids = valid_artist_ids

    if music_params[:album_ids].present?
      requested_album_ids = Array(music_params[:album_ids]).map(&:to_i)
      valid_album_ids = Album.where(id: requested_album_ids).pluck(:id)
      @music.album_ids = valid_album_ids
    end

    if music_params[:genres].present?
        genres = find_or_create_genres(music_params[:genres])
        @music.genres = genres
    end

    if music_params[:cover_art].present?
      Rails.logger.info "Attaching cover_art: #{music_params[:cover_art].inspect}"
      @music.cover_art.attach(music_params[:cover_art])
    end

    if music_params[:audio].present?
      Rails.logger.info "Attaching audio: #{music_params[:audio].inspect}" 
      @music.audio.attach(music_params[:audio])
    end

    authorize @music

    if @music.save 
      render json: @music, serializer: MusicSerializer, status: :created
    else 
      render json: { errors: formatted_errors(@music) }, status: :unprocessable_entity
    end

    rescue Pundit::NotAuthorizedError
    render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden
  end

  def update
    begin
      @music = Music.find(params[:id])
      authorize @music

      if music_params.key?(:artist_ids)
        collaborator_ids = Array(music_params[:artist_ids]).map(&:to_i)
        collaborator_ids << @music.creator.id 
        collaborator_ids.uniq! 
        @music.artist_ids = Artist.where(id: collaborator_ids).pluck(:id)
      end

      if music_params[:album_ids].present?
        @music.album_ids = Album.where(id: Array(music_params[:album_ids]).map(&:to_i)).pluck(:id)
      end

      if music_params[:genres].present?
        genres = find_or_create_genres(music_params[:genres])
         @music.genres = genres
      end

     if music_params[:cover_art].present? 
        Rails.logger.info "Purging existing cover_art" if @music.cover_art.attached? 
        @music.cover_art.purge if @music.cover_art.attached?
        @music.cover_art.attach(music_params[:cover_art])
      end

      if music_params[:audio].present? #
        Rails.logger.info "Purging existing audio" if @music.audio.attached? #
        @music.audio.purge_later if @music.audio.attached? 
        @music.audio.attach(music_params[:audio])
      end

      if @music.update(music_params.except(:artist_ids, :album_ids, :genres, :cover_art, :audio))
        render json: @music, serializer: MusicSerializer, status: :ok
      else
        render json: { errors: formatted_errors(@music) }, status: :unprocessable_entity
      end
    rescue Pundit::NotAuthorizedError
      render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden
    rescue ActiveRecord::RecordNotFound
      render json: { errors: [{ field: 'music', message: 'Music not found', type: 'not_found' }] }, status: :not_found
    end
  end


  def destroy
    begin
      @music = Music.find(params[:id])
      authorize @music

      @music.destroy
      render json: { message: "Music deleted successfully" }, status: :ok
    rescue Pundit::NotAuthorizedError
    render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [{ field: 'music', message: 'Music not found', type: 'not_found' }] }, status: :not_found
  rescue => e
    render json: { errors: [{ field: 'server', message: e.message, type: 'internal_error' }] }, status: :internal_server_error
    end
  end

  private 
  def music_params 
    params.require(:music).permit(
      :title,
      :cover_art,
      :audio,
      album_ids:[], 
      artist_ids:[], 
      genres:[]
      )
  end

  def find_or_create_genres(genre_names)
    genre_names.map do |name|
    Genre.find_or_create_by!(name:name.strip.downcase)
        end
  end

end


