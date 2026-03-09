module Positionable
  extend ActiveSupport::Concern

  included do
    validates :position, presence: true,
                         numericality: { only_integer: true, greater_than_or_equal_to: 1 }

    default_scope { order(position: :asc) }
  end
end
