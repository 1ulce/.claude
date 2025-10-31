# frozen_string_literal: true

# Amazon Pay決済システムとの統合を提供するモジュール
#
# Amazon Pay APIクライアントの初期化と管理を行う
# @return [AmazonPay::Client] Amazon Pay APIクライアント
module AmazonPay
  def self.client
    @client ||= AmazonPay::Client.new
  end
end
