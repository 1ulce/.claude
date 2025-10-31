# Amazon Payのペイメントゲートウェイモジュール
module PaymentGateway::AmazonPay
  # 決済関連の処理を行うクラスを返す
  def self.charge
    PaymentGateway::AmazonPay::ChargeProxy
  end
end
