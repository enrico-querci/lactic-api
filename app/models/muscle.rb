class Muscle < ApplicationRecord
  has_many :exercise_muscles, dependent: :destroy
  has_many :exercises, through: :exercise_muscles

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :in_region, ->(region) { where(region: region) }
end
