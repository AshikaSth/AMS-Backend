class Album < ApplicationRecord
  has_one_attached :cover_art
  belongs_to :creator, class_name: "Artist", foreign_key: "artist_id", optional: true

  has_many :album_musics, dependent: :nullify
  has_many :musics, through: :album_musics

  has_many :album_artists, dependent: :nullify
  has_many :artists, through: :album_artists
  
  has_many :album_genres, dependent: :destroy
  has_many :genres, through: :album_genres

  validates :name, presence: true,
                 length: { minimum: 2, maximum: 255 },
                 format: { with: /\A[[:print:]]+\z/, message: "may contain letters, numbers, spaces, and symbols" }

  validate :valid_release_date
  validates :cover_art, presence: { message: "must be attached" }
  validates :artists, presence: { message: "must have at least one artist" }
  validates :genres, presence: { message: "must have at least one genre" }
  validates :musics, presence: { message: "must have at least one music track" }
  validate :cover_art_format

  def music_count
    musics.count
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

  def valid_release_date
    return if release_date.blank?

    if release_date > Date.today
      errors.add(:release_date, "cannot be in the future")
    end
  end
end
