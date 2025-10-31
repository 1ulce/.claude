# frozen_string_literal: true

module AmazonPay::Consts::Refund
  # ステータス
  # RefundInitiated: 返金処理中
  # Refunded: 正常に返金
  # Declined: 返金失敗
  REFUND_INITIATED = "RefundInitiated"
  REFUNDED = "Refunded"
  DECLINED = "Declined"
end
