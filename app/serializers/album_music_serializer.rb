class AlbumMusicSerializer < ActiveModel::Serializer
  attributes :id

  belongs_to :album
  belongs_to :music
end
