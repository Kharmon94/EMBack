class MerchItemTag < ApplicationRecord
  belongs_to :merch_item
  belongs_to :product_tag
end

