class CreateAmazonPayCharges < ActiveRecord::Migration[6.1]
  def change
    create_table :amazon_pay_charges do |t|
      t.references :order, null: false, polymorphic: true, comment: "注文"
      t.references :payment, comment: "決済ID"
      t.string :charge_permission_id, comment: "注文ID"
      t.string :refund_id, comment: "返金ID"
      t.string :status, comment: "決済ステータス"
      t.datetime :authorized_at, comment: "オーソリされた日時"
      t.datetime :captured_at, comment: "売上請求完了日時"
      t.datetime :capture_declined_at, comment: "売上請求失敗日時"
      t.datetime :refund_initiated_at, comment: "返金処理開始日時"
      t.datetime :refunded_at, comment: "返金完了日時"
      t.datetime :refund_declined_at, comment: "返金失敗日時"
      t.datetime :canceled_at, comment: "キャンセル完了日時"

      t.timestamps
    end
  end
end
