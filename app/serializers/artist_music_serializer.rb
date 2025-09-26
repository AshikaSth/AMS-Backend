class ArtistMusicSerializer < ActiveModel::Serializer
  attributes :id

  belongs_to :artist
  belongs_to :music

end
