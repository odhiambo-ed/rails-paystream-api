class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.datetime :date
      t.decimal :amount
      t.string :mpesa_details
      t.string :checkoutRequestID
      t.string :merchantRequestID
      t.string :mpesaReceiptNumber
      t.string :status
      t.references :invoice, null: false, foreign_key: true

      t.timestamps
    end
  end
end
