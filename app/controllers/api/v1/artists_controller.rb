class Api::V1::ArtistsController < ApplicationController
    require 'csv'
    include Paginatable
    before_action :authorize_request, only: [:index, :all, :public_show, :update, :destroy, :assign_manager, :my_artists, :create, :csv_import, :csv_export]
    before_action :set_artist, only: [:public_show, :update, :destroy, :assign_manager]
    before_action :authorize_artist, only: [:public_show, :update, :destroy]

    def index
        artists=policy_scope(Artist).includes(:user, :manager, :genres, :albums, :musics).with_attached_photo
        @artists = paginate(artists)
        render json: @artists,
          each_serializer: ArtistSerializer,
          meta: paginate_meta(@artists),
          adapter: :json, status: :ok
    end

    def all
      authorize Artist, :all_artists?
      @artists = Artist.includes(:user, :genres, :albums, :musics).with_attached_photo
      render json: @artists, each_serializer: ArtistSerializer, status: :ok
    end

    def public_show
        artist = Artist.find(params[:id])
        render json: artist, serializer:    PublicArtistSerializer, status: :ok
    rescue ActiveRecord::RecordNotFound => e
        render json: { errors: [{ field: 'artist', message: 'Artist not found', type: 'not_found' }] }, status: :not_found
    end
    
    
    def create
      begin

        genres = artist_params[:genres]
        photo = artist_params[:photo]
        Rails.logger.info "Received photo: #{photo.inspect}"

        if current_user.artist?
          @artist = current_user.build_artist(artist_params.except(:genres, :photo))
          @artist.manager_id = nil
        else
          @artist = Artist.new(artist_params.except(:genres, :photo))
          @artist.manager_id = current_user.id if current_user.artist_manager?
        end
        
        authorize @artist

        if genres.present?
          @artist.genres = find_or_create_genres(genres)
        end
        
        if photo.present?
          @artist.photo.attach(photo)
        end

        if @artist.save
          render json: @artist, status: :created
        else
          render json: { errors: formatted_errors(@artist) }, status: :unprocessable_entity
        end
      rescue Pundit::NotAuthorizedError
        render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden

      end
    end


  def update
    begin
      @artist = Artist.find(params[:id])
      authorize @artist

      if artist_params[:genres].present?
        @artist.genres = find_or_create_genres(artist_params[:genres])
      end
      
      if artist_params[:photo].present?
        @artist.photo.purge if @artist.photo.attached?
        @artist.photo.attach(artist_params[:photo])
      end

      if @artist.update(artist_params.except(:genres, :photo))
        render json: @artist, serializer: ArtistSerializer, status: :ok
      else
        render json: { errors: formatted_errors(@artist) }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Artist not found" }, status: :not_found
    rescue Pundit::NotAuthorizedError
      render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden

    end
  end

  def destroy
      begin
          @artist = Artist.find(params[:id])
          authorize @artist

          @artist.destroy
          render json: { message: "Artist deleted successfully" }, status: :ok
      rescue ActiveRecord::RecordNotFound
          render json: { error: "Artist not found" }, status: :not_found
      rescue Pundit::NotAuthorizedError
          render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden


      end
  end

  def csv_import
    begin
      authorize Artist, :csv_import?

      file = params[:file]
      unless file
        return render json: { error: "No file provided" }, status: :bad_request
      end

      imported = []
      errors = []

      CSV.foreach(file.path, headers: true) do |row|
        begin
          # Match export headers exactly
          first_name            = row['First Name']
          last_name             = row['Last Name']
          email                 = row['Email']
          role                  = row['Role']
          bio                   = row['Bio']
          manager_id            = row['Manager ID']
          user_id               = row['User Id']
          website               = row['Website']

          # Ensure user exists or create
          user = User.find_or_initialize_by(email: email)
          if user.new_record?
            user.first_name = first_name
            user.last_name  = last_name
            user.role       = role || 'artist'
            user.password   = SecureRandom.hex(8) # fallback password since export has none
            user.save!
          end

          # Create/update artist
          artist = Artist.find_or_initialize_by(user_id: user.id)
          artist.bio                  = bio
          artist.website              = website
          artist.manager_id           = manager_id if manager_id.present?

          if artist.save
            imported << artist
          else
            errors << { row: row.to_h, errors: artist.errors.full_messages }
          end

        rescue => e
          errors << { row: row.to_h, errors: formatted_errors(artist) }
        end
      end

      render json: { imported: imported.count, errors: errors }, status: :ok
    rescue Pundit::NotAuthorizedError
      render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden

    end
  end


    # GET /api/v1/artists/csv_export

  def csv_export
    begin
      authorize Artist, :csv_export?

      artists = policy_scope(Artist).includes(:user, :genres) 

      csv_data = CSV.generate(headers: true) do |csv|
        csv << ['First Name', 'Last Name', 'Email', 'Role', 'Bio', 'Manager ID', 'User Id', 'Website', ]

        artists.each do |artist|
          csv << [
            artist.user&.first_name || 'null',
            artist.user&.last_name || 'null',
            artist.user&.email || 'null',
            artist.user&.role || 'null',
            artist.bio || 'null',
            artist.manager_id || 'null',
            artist.user_id || 'null',
            artist.website || 'null',
            
          ]
        end
      end

      file_path = Rails.root.join('public', 'exports', "artists-#{Date.today}.csv")
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, csv_data)

      send_data csv_data, filename: "artists-#{Date.today}.csv"
  
    rescue Pundit::NotAuthorizedError
      render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden

    end
  end


  def my_artists
    Rails.logger.debug ">>> Current user: #{current_user.inspect}"
    authorize Artist, :my_artists?
      @artists=policy_scope(Artist)
      .includes(:user, :manager, :genres, :albums, :musics)
      .with_attached_photo
      render json: @artists, each_serializer: ArtistSerializer, status: :ok
  end

   
    # PATCH /api/v1/artists/:id/assign_manager
  def assign_manager
      begin
          artist = Artist.find(params[:id])
          authorize artist, :assign_manager?

          manager_id = params[:manager_id]
          manager = User.find_by(id: manager_id, role: 'artist_manager')

          unless manager
              return render json: { errors: [{ field: 'manager_id', message: 'Manager not found or invalid role', type: 'not_found' }] }, status: :not_found
          end
              artist.manager_id = manager.id
          if artist.save
              render json: { message: "Manager assigned successfully", artist: artist }, status: :ok
          else
              render json: { errors: artist.errors.full_messages }, status: :unprocessable_entity
          end
      rescue Pundit::NotAuthorizedError
          render json: { errors: [{ field: 'authorization', message: 'You are not authorized to perform this action', type: 'authorization_error' }] }, status: :forbidden

      end
  end

  private 
  def set_artist
      @artist = Artist.find(params[:id])
  end

  def authorize_artist
      authorize @artist
  end

  def artist_params 
    if params[:artist][:social_media_links].is_a?(String) && params[:artist][:social_media_links].present?
        parsed_social_media = JSON.parse(params[:artist][:social_media_links]) rescue {}
        params[:artist][:social_media_links] = parsed_social_media
    end

    allowed = [
      :first_release_year, :bio, :website, :photo,
      { social_media_links: {} },
      { genres: [] }
    ]

    if current_user.super_admin?
      allowed << :user_id
      allowed << :manager_id
    elsif current_user.artist_manager?
      allowed << :user_id
    end
    params.require(:artist).permit(allowed)
  end

  def find_or_create_genres(genre_names)
      genre_names.map do |name|
      Genre.find_or_create_by!(name: name.strip.downcase)
      end
  end    
end
