class AddAmazonPayToVendorPaymentOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :vendor_payment_options, :amazon_pay, :integer, default: 0, after: :credit, comment: "AmazonPay"
  end
end
