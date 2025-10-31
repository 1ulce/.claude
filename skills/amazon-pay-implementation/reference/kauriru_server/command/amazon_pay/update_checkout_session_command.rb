# frozen_string_literal: true

# Amazon Payチェックアウトセッション更新コマンド
#
# Amazon Payのチェックアウトセッションに注文情報・決済詳細を設定し、
# 決済処理の準備を行う。
#
# 処理概要:
# 1. 与信額・支払額に応じた決済インテント（与信 or 即時売上）の決定
# 2. チェックアウトセッションの更新（決済詳細・マーチャント情報の設定）
# 3. Amazon Pay請求レコードの作成
#
# 決済種別の判定:
# - 与信額 > 0: Authorize（与信のみ）
# - 与信額 = 0: AuthorizeWithCapture（即時売上）
#
# 前提条件:
# - 注文が存在し、有効なチェックアウトセッションIDが提供されている
# - 注文にベンダー情報が設定されている
#
# エラー条件:
# - チェックアウトセッションの状態がOpenでない場合
#
module AmazonPay
  class UpdateCheckoutSessionCommand < ActiveInteraction::Base
    object :order, class: Order
    validates :order, presence: true

    string :checkout_session_id
    validates :checkout_session_id, presence: true

    def execute
      self.set_payment_intent_and_amount
      self.update_checkout_session
      return if self.errors.present?
      self.order.amazon_pay_charges.create!(status: :pending)
      @response
    end

    private

    # 決済種別・決済金額の設定
    #
    # 注文の与信額に基づいて決済方法を決定する:
    # - 与信額がある場合: Authorize（与信のみ）で与信額を設定
    # - 与信額がない場合: AuthorizeWithCapture（即時売上）で支払額を設定
    #
    # 与信額は割引やクーポンが適用される場合に発生する。
    def set_payment_intent_and_amount
      authorization_amount = self.order.calc_authorization_amount
      if authorization_amount.positive?
        @amount = authorization_amount
        @payment_intent = AmazonPay::Consts::CheckoutSession::PAYMENT_INTENT_AUTHORIZE
      else
        @amount = self.order.payment_amount
        @payment_intent = AmazonPay::Consts::CheckoutSession::PAYMENT_INTENT_AUTHORIZE_WITH_CAPTURE
      end
    end

    # Amazon Payチェックアウトセッション更新
    #
    # 決済詳細・マーチャント情報を含むペイロードを作成し、
    # Amazon Payのチェックアウトセッションを更新する。
    # セッション状態がOpenであることを確認し、エラーがあれば適切に処理する。
    def update_checkout_session
      payload = self.build_update_payload
      response = AmazonPay.client.update_checkout_session(self.checkout_session_id, payload)
      @response = JSON.parse(response.body)

      state = @response.dig("statusDetails", "state")
      if state != AmazonPay::Consts::CheckoutSession::STATE_OPEN
        return self.errors.add(:base, :invalid_checkout_session_update, state: state)
      end
    end

    # チェックアウトセッション更新ペイロード作成
    #
    # Amazon Pay Update Checkout Session APIに送信するペイロードを構築する。
    #
    # 含まれる情報:
    # - webCheckoutDetails: 決済完了後のリダイレクトURL
    # - paymentDetails: 決済インテント、金額、通貨、非同期処理設定
    # - merchantMetadata: 注文参照ID、店舗名、購入者向けメモ
    #
    # paymentIntentの種類:
    # - Authorize: 与信のみ
    # - AuthorizeWithCapture: 即時売上
    #
    # @return [Hash] Amazon Pay更新API用のペイロード
    # @see https://pay-api.amazon.com/v2/checkoutSessions/{checkoutSessionId}
    def build_update_payload
      {
        webCheckoutDetails: {
          checkoutResultReturnUrl: self.callback_url
        },
        paymentDetails: {
          paymentIntent: @payment_intent,
          canHandlePendingAuthorization: false, # 非同期
          chargeAmount: {
            amount: @amount.to_s,
            currencyCode: "JPY"
          },
        },
        merchantMetadata: {
          merchantReferenceId: @order.id.to_s,
          merchantStoreName: @order.vendor.service_name,
          noteToBuyer: @order.vendor.name_kanji,
        }
      }
    end

    # コールバックURL構築
    #
    # 決済完了後にAmazon PayからリダイレクトされるURL。
    #
    # @return [String] コールバックURL
    def callback_url
      "#{Settings.default_url_options}/api/v1/orders/#{@order.id}/amazon_pay_callback"
    end
  end
end
