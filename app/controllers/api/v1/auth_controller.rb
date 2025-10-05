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
          artist_data = user.artist ? ActiveModelSerializers::SerializableResource.new(user.artist, serializer: ArtistSerializer) : nil

          render json: { message: "Logged in successfully!", access_token: access_token, refresh_token: refresh_token, user: user, artist: artist_data }, status: :ok
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
        ActiveRecord::Base.transaction do
          user_attrs = profile_params.except(:artist)
          if user_attrs.present? && !current_user.update(user_attrs)
            return render json: { errors: format_errors(current_user) }, status: :unprocessable_entity
          end

          if current_user.artist? && profile_params[:artist].present?
            @artist = current_user.artist || current_user.build_artist
            @artist.manager_id ||= nil

            permitted_artist_params = artist_params_from_profile(profile_params[:artist])
            unless @artist.update(permitted_artist_params)
              return render json: { errors: format_errors(@artist, prefix: 'artist') }, status: :unprocessable_entity
            end

            if profile_params[:artist][:genres].present?
              unless profile_params[:artist][:genres].is_a?(Array) && profile_params[:artist][:genres].all? { |g| g.is_a?(String) && g.present? }
                return render json: { errors: [{ field: 'artist.genres', message: 'Genres must be an array of non-empty strings', type: 'validation_error' }] }, status: :unprocessable_entity
              end
              genres = find_or_create_genres(profile_params[:artist][:genres])
              @artist.genres.replace(genres)
            end
          end

          render json: current_user, serializer: UserSerializer, from_artist: true, status: :ok
        rescue Pundit::NotAuthorizedError => e
          render json: { errors: [{ field: 'authorization', message: 'Not authorized', type: 'authorization_error', details: e.message }] }, status: :forbidden
        end
      end

      private

      def user_params
        params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :gender, :address, :phone_number, :dob)
      end

      def profile_params
        allowed = [
          :first_name, :last_name, :email, :gender, :address, :dob, :phone_number,
          artist: [:first_release_year, :bio, :website, :photo, { social_media_links: {} }, { genres: [] }]
        ]
        params.require(:user).permit(allowed)
      end

      def artist_params_from_profile(artist_hash)
        if artist_hash[:social_media_links].is_a?(String) && artist_hash[:social_media_links].present?
          begin
            artist_hash[:social_media_links] = JSON.parse(artist_hash[:social_media_links])
          rescue JSON::ParserError
            artist_hash[:social_media_links] = {}
            # Optionally, add error: errors.add(:social_media_links, "Invalid JSON format")
          end
        end
        artist_hash.slice(:first_release_year, :bio, :website, :photo, :social_media_links)
      end

      def format_errors(record, prefix: nil)
        record.errors.map do |error|
          { field: prefix ? "#{prefix}.#{error.attribute}" : error.attribute.to_s, message: error.message, type: 'validation_error' }
        end
      end

      def find_or_create_genres(genre_names)
        genre_names.map do |name|
          Genre.find_or_create_by!(name: name.strip.downcase)
        end
      end
    end
  end
end