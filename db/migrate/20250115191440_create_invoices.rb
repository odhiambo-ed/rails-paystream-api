class CreateInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :invoices do |t|
      t.string :invoice_number
      t.text :items
      t.decimal :total_amount
      t.decimal :tax
      t.string :status
      t.datetime :due_date

      t.timestamps
    end
  end
end
