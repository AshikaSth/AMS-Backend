module Api
  module V1
    class AuthController < ApplicationController
      include ActionController::Cookies
      before_action :authorize_request, only: [:profile, :logout, :refresh, :update_profile]

      def login
        user = User.find_by(email: params[:email])
        if user&.authenticate(params[:password])
          service = AuthenticationService.new(user)
          access_token = service.generate_access_token
          refresh_token = service.generate_refresh_token

          user.refresh_tokens.create!(
            token: Digest::SHA256.hexdigest(refresh_token),
            expires_at: 7.days.from_now
          )

          cookies.signed[:access_token] = { value: access_token, httponly: true, secure: Rails.env.production?, expires: 7.days.from_now, same_site: Rails.env.production? ? :none : :lax }
          cookies.signed[:refresh_token] = { value: refresh_token, httponly: true, secure: Rails.env.production?, expires: 7.days.from_now, same_site: Rails.env.production? ? :none : :lax }
          render json: { message: "Logged in successfully!", access_token: access_token, refresh_token: refresh_token, user:  UserSerializer.new(user) }, status: :ok
        else
          render json: { errors: [{ field: 'email_or_password', message: 'Invalid email or password', type: 'authentication_error' }] }, status: :unauthorized
        end
      end

      def logout
        if cookies.signed[:refresh_token]
          token = Digest::SHA256.hexdigest(cookies.signed[:refresh_token])
          current_user.refresh_tokens.where(token: token).update_all(revoked: true)
        end

        cookies.delete(:access_token)
        cookies.delete(:refresh_token)
        render json: { message: "Logged out successfully" }, status: :ok
      end

      def register
        user = User.new(user_params)
        user.role = 'artist'
        if user.save
          UserMailer.verify_email(user).deliver_later
          render json: user, serializer: UserSerializer, status: :created
        else
          render json: { errors: format_errors(user) }, status: :unprocessable_entity
        end
      end

      def refresh
        refresh_token_value = cookies.signed[:refresh_token]
        decoded_token = JsonWebToken.decode(refresh_token_value)

        if decoded_token && decoded_token['type'] == 'refresh'
          user = User.find_by(id: decoded_token['user_id'])
          unless user
            render json: { errors: [{ field: 'refresh_token', message: 'Invalid user', type: 'authentication_error' }] }, status: :unauthorized
            return
          end

          refresh_token = user.refresh_tokens.find_by(token: Digest::SHA256.hexdigest(refresh_token_value))
          if refresh_token && !refresh_token.revoked && refresh_token.expires_at > Time.now
            new_access_token = AuthenticationService.new(user).generate_access_token
            new_refresh_token = AuthenticationService.new(user).generate_refresh_token

            refresh_token.update!(revoked: true)
            user.refresh_tokens.create!(
              token: Digest::SHA256.hexdigest(new_refresh_token),
              expires_at: 7.days.from_now
            )

            cookies.signed[:access_token] = { value: new_access_token, httponly: true, secure: Rails.env.production?, expires: 15.minutes.from_now, same_site: Rails.env.production? ? :none : :lax }
            cookies.signed[:refresh_token] = { value: new_refresh_token, httponly: true, secure: Rails.env.production?, expires: 7.days.from_now, same_site: Rails.env.production? ? :none : :lax }

            render json: { message: "Tokens refreshed successfully!" }, status: :ok
          else
            render json: { errors: [{ field: 'refresh_token', message: 'Invalid or expired refresh token', type: 'authentication_error' }] }, status: :unauthorized
          end
        else
          render json: { errors: [{ field: 'refresh_token', message: 'Invalid or expired refresh token', type: 'authentication_error' }] }, status: :unauthorized
        end
      end

      def profile
        render json: current_user, serializer: UserSerializer, from_profile: true
      end

def update_profile
  user = current_user

  # Handle potential nested 'auth' params
  params_to_use = params[:auth].presence || params

  ActiveRecord::Base.transaction do
    if params_to_use[:artist].present?
      artist = user.artist || user.build_artist
      artist.manager_id ||= nil

      artist_data = params_to_use[:artist] || {}
      artist_attributes = artist_params(artist_data.to_unsafe_h.symbolize_keys).except(:genres, :photo)

      Rails.logger.debug "Artist attributes: #{artist_attributes.inspect}" # Debug log

      if artist_data[:genres].present?
        unless artist_data[:genres].is_a?(Array) && artist_data[:genres].all? { |g| g.is_a?(String) && g.present? }
          render json: { errors: [{ field: 'artist.genres', message: 'Genres must be an array of non-empty strings', type: 'validation_error' }] }, status: :unprocessable_entity
          return
        end
        artist.genres = find_or_create_genres(artist_data[:genres])
      end

      if artist_data[:photo].present?
        artist.photo.purge if artist.photo.attached?
        artist.photo.attach(artist_data[:photo])
      end

      unless artist.update(artist_attributes)
        render json: { errors: format_errors(artist, prefix: 'artist') }, status: :unprocessable_entity
        return
      end
    end

    if params_to_use[:user].present?
      unless user.update(user_params(params_to_use))
        render json: { errors: format_errors(user) }, status: :unprocessable_entity
        return
      end
    end

    render json: user.reload, serializer: UserSerializer, from_profile: true, status: :ok
  end
rescue ActiveRecord::RecordInvalid => e
  render json: { errors: [{ field: 'general', message: e.message, type: 'validation_error' }] }, status: :unprocessable_entity
rescue JSON::ParserError => e
  render json: { errors: [{ field: 'artist.social_media_links', message: 'Invalid JSON format for social media links', type: 'validation_error' }] }, status: :unprocessable_entity
end

private

def user_params(params_to_use = params)
  params_to_use.require(:user).permit(:first_name, :last_name, :email, :gender, :address, :phone_number, :dob)
end

def artist_params(artist_data)
  artist_data = artist_data.with_indifferent_access

  if artist_data[:social_media_links].is_a?(String) && artist_data[:social_media_links].present?
    begin
      artist_data[:social_media_links] = JSON.parse(artist_data[:social_media_links])
    rescue JSON::ParserError
      artist_data[:social_media_links] = {}
    end
  elsif artist_data[:social_media_links].is_a?(Hash)
    artist_data[:social_media_links] = artist_data[:social_media_links].slice(:linkedin, :instagram)
  else
    artist_data[:social_media_links] = {}
  end

  allowed = [
    :first_release_year,
    :bio,
    :website,
    :photo,
    { social_media_links: [] },
    { genres: [] }
  ]

  allowed << :user_id if current_user.super_admin? || current_user.artist_manager?
  allowed << :manager_id if current_user.super_admin?

  ActionController::Parameters.new(artist_data).permit(allowed)
end





    def format_errors(record, prefix: nil)
      record.errors.map do |error|
        { field: prefix ? "#{prefix}.#{error.attribute}" : error.attribute.to_s, message: error.message, type: 'validation_error' }
      end
    end

    def find_or_create_genres(genre_names)
      genre_names.map(&:strip).map(&:downcase).uniq.map do |name|
        Genre.where('LOWER(name) = ?', name).first_or_create!(name: name)
      end
    end
      end
    end
  end

