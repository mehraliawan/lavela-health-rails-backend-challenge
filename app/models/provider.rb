class Provider < ApplicationRecord
  has_many :availabilities, dependent: :destroy
  has_many :appointments, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
