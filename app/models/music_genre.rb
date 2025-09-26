class MusicGenre < ApplicationRecord
  belongs_to :music
  belongs_to :genre
end
