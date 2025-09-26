class LoginSerializer < ActiveModel::Serializer
  attributes :id, :email, :role, :token