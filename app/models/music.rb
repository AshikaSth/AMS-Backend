class Music < ApplicationRecord
  has_one_attached :cover_art
  has_one_attached :audio
  
  has_many :artist_musics, dependent: :destroy
  has_many :artists, through: :artist_musics

  has_many :album_musics, dependent: :destroy
  has_many :albums, through: :album_musics

  has_many :music_genres, dependent: :destroy
  has_many :genres, through: :music_genres

  belongs_to :creator, class_name: "Artist", foreign_key: "artist_id", optional: true
  
  validates :title, presence: true, length: { minimum: 2, maximum: 255 }
  validate :cover_art_format
  validate :audio_format

  private

  def cover_art_format
    return unless cover_art.attached?

    unless cover_art.content_type.start_with?('image/')
      errors.add(:cover_art, "must be an image")
    end

    if cover_art.byte_size > 10.megabytes
      errors.add(:cover_art, "size must be less than 10MB")
    end
  end

  def audio_format
    return unless audio.attached?

    unless audio.content_type.in?(%w[audio/mpeg audio/mp3 audio/wav audio/ogg])
      errors.add(:audio, "must be an MP3, WAV, or OGG file")
    end

    if audio.byte_size > 30.megabytes
      errors.add(:audio, "size must be less than 30MB")
    end
    
  end
end
