class Program < ApplicationRecord
  belongs_to :coach, class_name: "User"

  has_many :weeks, dependent: :destroy
  has_many :program_assignments, dependent: :destroy

  validates :name, presence: true
end
