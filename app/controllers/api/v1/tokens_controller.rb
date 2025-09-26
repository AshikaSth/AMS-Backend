class TokensController < ApplicationController
    def refresh 
        refresh_token= cookies.signed[:refresh_token]
        payload = JsonWebToken.decode(refresh_token)
    end

    if payload&& payload["type"] == "refresh"
        user = User.find(payload["user_id"])

        stored_token = user.refresh_tokens.find_by(
        token. Digest::SHA256.hexdigest(refresh_token)
        )

        if stored_token && stored_token.expires_at>Time.current_user
            access_token = AuthenticationService.new(user).generate_access_token
            
            cookies.signed[:access_token]= {
                value: access_token,
                httponly: true,
                expires: 15.minutes.from_now
            }

            render json: {message: "Access token refreshed"}
        else
            render json: {message: "Invalid refresh token"}, status: :unauthorized
        end
    else
        render json: {error: "Invalid token type"}, status: :unauthorized
    end
end
