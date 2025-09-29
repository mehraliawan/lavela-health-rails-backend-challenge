class Client < ApplicationRecord
  has_many :appointments, dependent: :destroy
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, format: { with: /\A[\+]?[1-9][\d\s\-\(\)]*\z/, message: "must be a valid phone number" }, allow_blank: true
end
