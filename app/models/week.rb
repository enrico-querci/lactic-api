class Week < ApplicationRecord
  include Positionable

  belongs_to :program

  has_many :workouts, dependent: :destroy

  validates :position, uniqueness: { scope: :program_id }
end
