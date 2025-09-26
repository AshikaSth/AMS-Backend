class PublicArtistSerializer < ActiveModel::Serializer
  attributes :id, :first_release_year, :bio, :website, :photo_url

  has_many :genres
  attribute :user_name do
    "#{object.user.first_name} #{object.user.last_name}" if object.user
  end
end
