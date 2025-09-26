class AlbumArtistSerializer < ActiveModel::Serializer
  attributes :id

  belongs_to :artist
  belongs_to :album
end
