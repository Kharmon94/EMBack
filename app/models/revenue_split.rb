class RevenueSplit < ApplicationRecord
  belongs_to :splittable, polymorphic: true
end
