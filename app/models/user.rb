class User < ApplicationRecord
  has_many :refresh_tokens, dependent: :destroy
  has_one :artist, dependent: :destroy
  has_many :managed_artists, class_name: 'Artist', foreign_key: 'manager_id'

  enum :role, [ :super_admin, :artist_manager, :artist ]
  enum :gender, [ :male, :female, :others ]

  has_secure_password

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email" }
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :password, format: { 
    with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z\d])/,
    message: "must include at least one uppercase, one lowercase, one number, and one special character"
  }, if: :password_required?

  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :gender, inclusion: { in: genders.keys }, allow_nil: true

  before_save :downcase_email

  private

  def downcase_email
    self.email = email.downcase.strip
  end

  def password_required?
    new_record? || !password.nil?
  end
end

