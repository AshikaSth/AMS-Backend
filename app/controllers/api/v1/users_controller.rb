class Api::V1::UsersController < ApplicationController
  include Paginatable

  def index
    users = policy_scope(User)
    @users = paginate(users)

    render json: @users,
           each_serializer: UserSerializer,
           meta: paginate_meta(@users),
           adapter: :json,
           status: :ok
  end

  def all
    @artists = Artist.includes(:user, :genres, :albums, :musics).with_attached_photo
    render json: @artists, each_serializer: ArtistSerializer, status: :ok
  end

  def show
    @user = User.find(params[:id])
    render json: @user, serializer: UserSerializer, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [{ field: 'user', message: 'User not found', type: 'not_found' }] }, status: :not_found
  end

  def unassigned_artists
    authorize User, :unassigned_artists?
    @users = User.where(role: 'artist').left_outer_joins(:artist).where(artists: { id: nil })
    render json: @users, each_serializer: UserSerializer, status: :ok
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      render json: @user, serializer: UserSerializer, status: :created
    else
      render json: { errors: formatted_errors(@user) }, status: :unprocessable_entity
    end
  rescue Pundit::NotAuthorizedError
    render json: { error: "You are not authorized to perform this action." }, status: :forbidden
  end

  def update
    @user = User.find(params[:id])
    authorize @user

    if @user.update(user_params)
      render json: @user, serializer: UserSerializer, status: :ok
    else
      render json: { errors: formatted_errors(@user) }, status: :unprocessable_entity
    end
  rescue Pundit::NotAuthorizedError
    render json: { error: "You are not authorized to perform this action." }, status: :forbidden
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [{ field: 'user', message: 'User not found', type: 'not_found' }] }, status: :not_found
  end

  def destroy
    @user = User.find(params[:id])
    authorize @user

    @user.destroy
    render json: { message: "User deleted successfully" }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { errors: [{ field: 'user', message: 'User not found', type: 'not_found' }] }, status: :not_found
  rescue Pundit::NotAuthorizedError
    render json: { error: "You are not authorized to perform this action." }, status: :forbidden
  end

  private

  def user_params
    params.require(:user).permit(
      :first_name, :last_name, :email, :password, :password_confirmation,
      :phone_number, :gender, :address, :dob, :role
    )
  end
end
