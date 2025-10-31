# frozen_string_literal: true

module AmazonPay::Consts::Charge
  # ステータス
  # AuthorizationInitiated: 保留状態
  # Authorized: 正常にオーソリ
  # CaptureInitiated: 売上請求処理中
  # Captured: 正常に売上請求
  # Cancelled: 取り消し
  # Declined: 拒否
  AUTHORIZATION_INITIATED = "AuthorizationInitiated"
  AUTHORIZED = "Authorized"
  CAPTURE_INITIATED = "CaptureInitiated"
  CAPTURED = "Captured"
  CANCELED = "Canceled"
  DECLINED = "Declined"
end
