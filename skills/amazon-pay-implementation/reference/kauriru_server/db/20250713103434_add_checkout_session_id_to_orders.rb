class AddCheckoutSessionIdToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :checkout_session_id, :string, comment: "AmazonPayのチェックアウトセッションID"
  end
end
