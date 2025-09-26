class Artist < ApplicationRecord
  has_one_attached :photo
  belongs_to :user
  belongs_to :manager, class_name: 'User', foreign_key: 'manager_id', optional: true

  has_many :album_artists, dependent: :destroy
  has_many :albums, through: :album_artists


  has_many :artist_musics, dependent: :destroy
  has_many :musics, through: :artist_musics

  has_many :artist_genres, dependent: :destroy
  has_many :genres, through: :artist_genres

  def no_of_albums_released
    albums.count
  end

  validates :user_id, presence: true, uniqueness: true
  validates :manager_id, numericality: { only_integer: true }, allow_nil: true
  validates :bio, length: { maximum: 1000 }, allow_blank: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  validate :acceptable_photo

  def acceptable_photo
    return unless photo.attached?

    unless photo.content_type.start_with?('image/')
      errors.add(:photo, "must be an image")
    end

    if photo.byte_size > 10.megabytes
      errors.add(:photo, "is too big. Max size is 10MB")
    end
  end
end
