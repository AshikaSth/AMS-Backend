# app/controllers/api/v1/auth_controller.rb

module Api
    module V1
        class AuthController < ApplicationController
            include ActionController::Cookies
            before_action :authorize_request, only: [ :profile, :logout, :refresh, :update_profile]
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

                    cookies.signed[:access_token] = { value: access_token, httponly: true, secure: true, expires: 7.days.from_now, same_site: :none  }
                    cookies.signed[:refresh_token] = { value: refresh_token, httponly: true, secure: true, expires: 7.days.from_now, same_site: :none }
                    artist_data = user.artist ? ActiveModelSerializers::SerializableResource.new(user.artist, serializer: ArtistSerializer) : nil

                    render json: { message: "Logged in successfully!", access_token: access_token, refresh_token: refresh_token,  user: user, artist: artist_data }, status: :ok
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

            end


            def register
                user= User.new(user_params)
                user.role = 'artist'
                if user.save
                    UserMailer.verify_email(user).deliver_later
                    render json: user, serializer: UserSerializer, status: :created
                else
                    formatted_errors = user.errors.messages.flat_map do |attribute, messages|
                        messages.map do |msg|
                        {
                        field: attribute.to_s,
                        message: msg,
                        type: 'validation_error'
                        }
                    end
                end

                    render json: { errors: formatted_errors(user) }, status: :unprocessable_entity
                end
            end

            def refresh
                refresh_token_value = cookies.signed[:refresh_token]

                decoded_token = JsonWebToken.decode(refresh_token_value)

                if decoded_token && decoded_token['type'] == 'refresh'
                    user = User.find(decoded_token['user_id'])
                    refresh_token = user.refresh_tokens.find_by(
                    token: Digest::SHA256.hexdigest(refresh_token_value)
                    )

                    if refresh_token && !refresh_token.revoked && refresh_token.expires_at > Time.now
                    new_access_token = AuthenticationService.new(user).generate_access_token
                    new_refresh_token = AuthenticationService.new(user).generate_refresh_token

                    refresh_token.update!(revoked: true)
                    user.refresh_tokens.create!(
                        token: Digest::SHA256.hexdigest(new_refresh_token),
                        expires_at: 7.days.from_now
                    )

                    cookies.signed[:access_token] = { value: new_access_token, httponly: true, secure: Rails.env.production?, expires: 15.minutes.from_now }
                    cookies.signed[:refresh_token] = { value: new_refresh_token, httponly: true, secure: Rails.env.production?, expires: 7.days.from_now }

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
                    user_params_only = profile_params.except(:artist)

                    if user_params_only.present?
                        unless current_user.update(user_params_only)
                            formatted_errors = current_user.errors.map do |attr, msg|
                                { field: attr.to_s, message: msg, type: 'validation_error' }
                            end
                            render json: { errors: formatted_errors }, status: :unprocessable_entity
                            return
                        end
                    end

                    if current_user.artist? && profile_params[:artist].present?
                        @artist = current_user.artist || current_user.build_artist
                        artist_params = profile_params[:artist].except(:genres)
                        @artist.manager_id = nil 
                        unless @artist.update(artist_params_only)
                            formatted_errors = @artist.errors.map do |attr, msg|
                                { field: "artist.#{attr}", message: msg, type: 'validation_error' }
                            end
                            render json: { errors: formatted_errors }, status: :unprocessable_entity
                            return
                        end

                        if profile_params[:artist][:genres].present?
                            genres = find_or_create_genres(profile_params[:artist][:genres])
                            @artist.genres.replace(genres)
                        end
                    end
                    render json: current_user, serializer: UserSerializer, from_artist: true, status: :ok
                end
                rescue Pundit::NotAuthorizedError => e
                    render json: { errors: [{ field: 'authorization', message: 'Not authorized to update profile', type: 'authorization_error', details: e.message }] }, status: :forbidden
                end

                private

                def profile_params
                    allowed = [
                        :first_name, :last_name, :email, :gender, :address, :dob, :phone_number,
                        artist: [:first_release_year, :bio, :website, :photo, { social_media_links: {} }, { genres: [] }]
                    ]
                    params.require(:user).permit(allowed)
                end

                def user_params
                    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :gender, :address, :phone_number, :dob)
                end
                end
            end
        end
        