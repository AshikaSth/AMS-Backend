class MusicSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers

  attributes :id, :title, :created_at, :updated_at, :cover_art_url, :audio_file_url, :artist_names
  
  has_many :genres, serializer: GenreSerializer
  has_many :artists, serializer: ArtistSerializer
  has_many :albums, serializer: AlbumSerializer

  def cover_art_url
    object.cover_art.attached? ? rails_blob_path(object.cover_art, only_path: true) : nil
  end

  def audio_file_url
    object.audio.attached? ? rails_blob_path(object.audio, only_path: true) : nil
  end

  def artist_names

    artists = object.artists.map do |artist|
      user = artist.user
      { artist_id: artist.id, first_name: user&.first_name, last_name: user&.last_name } if user
    end.compact

    if object.creator && !artists.any? { |a| a[:artist_id] == object.creator.id }
      creator_user = object.creator.user
      artists << { artist_id: object.creator.id, first_name: creator_user&.first_name, last_name: creator_user&.last_name } if creator_user
    end
    
    artists.map { |a| "#{a[:first_name]} #{a[:last_name]}" }.compact
  end

end

