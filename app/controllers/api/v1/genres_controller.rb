class Api::V1::GenresController < ApplicationController
  include Paginatable
  before_action :set_genre, only: [:show, :update, :destroy]
  def show
    render json: @genre, serializer: GenreSerializer, status: :ok
  end

  def index
    genres = Genre.all
    @genres = paginate(genres)

    render json: @genres,
           each_serializer: GenreSerializer,
           meta: paginate_meta(@genres),
           adapter: :json,
           status: :ok
  end

  def create
    name = genre_params[:name].to_s.downcase.strip
    @genre = Genre.find_or_create_by(name: name)

    if @genre.persisted?
      render json: @genre, serializer: GenreSerializer, status: :created
    else
      render json: { errors: @genre.errors.full_messages }, status: :unprocessable_entity
    end
  end
  

  def update
    name = genre_params[:name].to_s.downcase.strip
    if @genre.update(name: name)
      render json: @genre, serializer: GenreSerializer, status: :ok
    else
      render json: { errors: @genre.errors.full_messages }, status: :unprocessable_entity
    end
  end
    
  def destroy
    @genre.destroy
    render json: { message: "Genre deleted successfully" }, status: :ok
  end

  def search
    query = params[:query].to_s.downcase.strip
    @genres = Genre.where("LOWER(name) LIKE ?", "%#{query}%")
    render json: @genres, each_serializer: GenreSerializer, status: :ok
  end

  private

  def set_genre
    @genre = Genre.find(params[:id])
    authorize @genre
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Genre not found" }, status: :not_found
  end

  def genre_params
    params.require(:genre).permit(:name)
  end
end
