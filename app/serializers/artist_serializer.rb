class ArtistSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers

  attributes :id, :first_release_year, :bio, :website, :genres, :created_at, :updated_at, :social_media_links, :no_of_albums_released, :photo_url

  def photo_url
    object.photo.attached? ? rails_blob_path(object.photo, only_path: true) : nil
  end
  has_many :genres
  has_many :albums
  has_many :musics
  belongs_to :user, serializer: UserSerializer
  belongs_to :manager, serializer: UserSerializer

end
