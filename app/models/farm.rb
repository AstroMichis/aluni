# A farm groups fields. One per user is created implicitly by the onboarding;
# country and region are derived from a field's pin later, never asked.
class Farm < ApplicationRecord
  NAME_MAX = 100

  belongs_to :user
  has_many :fields, -> { order(:position, :id) }, dependent: :destroy

  normalizes :country_code, with: ->(code) { code.to_s.strip.upcase.presence }

  validates :name, length: { maximum: NAME_MAX }
  validates :country_code, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true
  validates :admin_area, length: { maximum: NAME_MAX }, allow_nil: true
end
