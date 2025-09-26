class Genre < ApplicationRecord
    has_many :artist_genres
    has_many :artists, through: :artist_genres

    has_many :album_genres, dependent: :destroy
    has_many :albums, through: :album_genres

    has_many :music_genres, dependent: :destroy
    has_many :musics, through: :music_genres

    validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { minimum: 2, maximum: 50 }
end
