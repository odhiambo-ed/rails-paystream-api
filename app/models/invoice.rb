class Invoice < ApplicationRecord
  has_many :payments

  serialize :items, JSON

  def calculate_total_amount
    total_amount || 0
  end

  def calculate_only_tax
    tax || 0
  end

  def total_with_tax
    calculate_total_amount + calculate_only_tax
  end
end
