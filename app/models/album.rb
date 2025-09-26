class Album < ApplicationRecord
  has_one_attached :cover_art
  belongs_to :creator, class_name: "Artist", foreign_key: "artist_id", optional: true

  has_many :album_musics, dependent: :destroy
  has_many :musics, through: :album_musics

    has_many :album_artists, dependent: :destroy
  has_many :artists, through: :album_artists
  
  has_many :album_genres, dependent: :destroy
  has_many :genres, through: :album_genres

  validates :name, presence: true, length: {minimum: 2, maximum: 255}
  validates :release_date, presence: true
  validate :cover_art_format

  def music_count
    music.count
  end

  def cover_art_format
    return unless cover_art.attached?

    unless cover_art.content_type.start_with?('image/')
      errors.add(:cover_art, "must be an image")
    end

    if cover_art.byte_size > 10.megabytes
      errors.add(:cover_art, "size must be less than 10MB")
    end
  end
end
