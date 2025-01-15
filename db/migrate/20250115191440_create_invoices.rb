class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.string :phone_number
      t.decimal :amount

      t.timestamps
    end
  end
end
