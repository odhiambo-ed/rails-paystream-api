class Invoice < ApplicationRecord
  has_many :payments
end
