class CreateAmazonPayAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :amazon_pay_accounts do |t|
      t.references :vendor, null: false, foreign_key: true, comment: "ベンダー"
      t.string :status, default: "pending", comment: "申請状況"
      t.string :unique_reference_id, comment: "AmazonPay出店者識別ID"
      t.string :merchant_account_id, comment: "AmazonPay出店者ID"
      t.string :ledger_currency, default: "JPY", comment: "通貨"
      t.integer :business_type, default: 0, comment: "事業形態（0: CORPORATE法人, 1: INDIVIDUAL個人）"
      t.string :country_of_establishment, default: "JP", comment: "設立国"
      t.string :business_legal_name, comment: "法人名（商号）"
      t.string :business_address_line1, comment: "法人所在地 住所1"
      t.string :business_address_line2, comment: "法人所在地 住所2"
      t.string :business_city, comment: "法人所在地 市区町村"
      t.string :business_state_or_region, comment: "法人所在地 都道府県"
      t.string :business_postal_code, comment: "法人所在地 郵便番号"
      t.string :business_country_code, default: "JP", comment: "法人所在地 国コード"
      t.string :person_full_name, comment: "担当者の氏名"
      t.date :person_date_of_birth, comment: "担当者の生年月日"
      t.string :contact_address_line1, comment: "担当者住所1"
      t.string :contact_address_line2, comment: "担当者住所2"
      t.string :contact_city, comment: "担当者住所 市区町村"
      t.string :contact_state_or_region, comment: "担当者住所 都道府県"
      t.string :contact_postal_code, comment: "担当者住所 郵便番号"
      t.string :contact_country_code, default: "JP", comment: "担当者住所 国コード"
      t.datetime :approved_at, comment: "承認日時"
      t.datetime :rejected_at, comment: "却下日時"
      t.datetime :resubmitted_at, comment: "再申請日時"

      t.timestamps
    end
  end
end
