# frozen_string_literal: true

module AmazonPay::Consts::CheckoutSession
  # ステータス
  # Open: オープン
  # Completed: 完了
  # Canceled: キャンセル
  STATE_OPEN = "Open"
  STATE_COMPLETED = "Completed"
  STATE_CANCELED = "Canceled"

  # payment_intent
  PAYMENT_INTENT_AUTHORIZE = "Authorize"
  PAYMENT_INTENT_AUTHORIZE_WITH_CAPTURE = "AuthorizeWithCapture"
end
