class Purchase < ApplicationRecord
  belongs_to :user
  belongs_to :purchasable, polymorphic: true
end
