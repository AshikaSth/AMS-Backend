class AuthenticationService
    ACCESS_TOKEN_EXPIRY=7.days
    REFRESH_TOKEN_EXPIRY=7.days

    def initialize(user)
        @user=user
    end

    def generate_access_token 
        JsonWebToken.encode({user_id: @user.id, type: "access"}, ACCESS_TOKEN_EXPIRY.from_now)
    end

    def generate_refresh_token
        JsonWebToken.encode({user_id: @user.id, type: "refresh"}, REFRESH_TOKEN_EXPIRY.from_now)
    end
end
