class UserSerializer < ActiveModel::Serializer
  attributes :id, :first_name, :last_name, :email, :role, :created_at, :updated_at, :gender, :address, :dob, :phone_number

  has_one :artist, serializer: ArtistSerializer, unless: -> { instance_options[:from_artist] }
end
