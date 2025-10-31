class AddAmazonPayToVendors < ActiveRecord::Migration[6.1]
  def change
    add_column :vendors, :amazon_pay, :boolean, default: false, comment: "AmazonPay利用設定"
    add_column :vendors, :payment_type_amazon_pay, :boolean, default: false, after: :payment_type_others, comment: "AmazonPayの支払いタイプ設定"
  end
end
