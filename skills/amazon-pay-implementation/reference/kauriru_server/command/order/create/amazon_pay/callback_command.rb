# Amazon Pay注文作成コールバックコマンド
#
# 短期レンタル・サブスクリプション注文作成時のAmazon Payチェックアウト後のコールバック処理を行う。
#
# 処理概要:
# 1. 注文・ベンダー・決済情報の検証
# 2. Amazon Pay決済の実行（与信または即時売上）
# 3. 決済情報の保存
# 4. Amazon PayアカウントとKauriruユーザーの紐付け
# 5. 注文確定後処理の実行
#
# 与信・実売上の判定:
# - 与信額 > 0: 与信処理後、実売上額に応じて capture_change(売上請求確定) または cancel_charge(与信キャンセル)
# - 与信額 = 0 かつ支払額 > 0: 即時売上処理
#
# エラー処理:
# - 検証エラー時: handle_failed による注文キャンセル
# - API実行エラー時: 返金処理 + 例外の再発生
#
class Order::Create::AmazonPay::CallbackCommand < ApplicationCommand

  record :order, default: nil

  def execute
    self.validate_process
    if self.errors.present?
      self.handle_failed
      return
    end

    begin
      self.order.with_lock do
        self.validate_process
        break if self.errors.present?
        self.main_process
        raise ActiveRecord::Rollback if self.errors.present?
      end
    rescue => e
      self.api_cancel
      self.handle_failed
      raise e
    end
    if self.errors.present?
      self.handle_failed
      return
    end
    self.create_after_process
  end

  private

  # 事前検証処理
  #
  # 検証内容:
  # - 注文の存在確認
  # - ベンダーの有効性確認（借り放題サービス除外、アクティブ状態）
  # - Amazon Pay設定の確認（申請済み・承認済み）
  # - 注文アイテムの初期状態確認
  # - Amazon Pay請求情報とチェックアウトセッションの存在確認
  def validate_process
    if self.order.blank?
      self.errors.add(:base, :not_found_order)
      return
    end

    @vendor = self.order.vendor

    if @vendor.swapable?
      self.errors.add(:base, :invalid_swapable)
      return
    end

    if @vendor.inactive?
      self.errors.add(:base, :vendor_inactive)
      return
    end

    if @vendor.amazon_pay_account.nil?
      self.errors.add(:base, :not_applied)
      return
    end

    if !@vendor.amazon_pay_account.approved?
      self.errors.add(:base, :not_approved)
      return
    end

    unless self.order.rentals.all?(&:any_initial?)
      self.errors.add(:base, :not_all_initial)
      return
    end

    @amazon_pay_charge = self.order.amazon_pay_charges.last
    if @amazon_pay_charge.blank?
      self.errors.add(:base, :charge_not_found)
      return
    end

    if self.order.checkout_session_id.blank?
      self.errors.add(:base, :checkout_session_not_found)
      return
    end
  end

  # メイン決済処理
  #
  # 処理内容:
  # 1. 与信額の計算
  # 2. 与信額の有無に応じた決済処理
  # 3. 決済情報の保存
  # 4. Amazon PayアカウントとKauriruユーザーの紐付け
  # 5. チェックアウトセッションの破棄
  def main_process
    @authorization_amount = self.order.calc_authorization_amount

    if @authorization_amount.positive?
      self.api_payment(capture: false, amount: @authorization_amount)
    elsif self.order.payment_amount.positive?
      self.api_payment(capture: true, amount: self.order.payment_amount)
    end

    self.save_payment
    self.save_buyer_id
    self.order.update!(checkout_session_id: nil)
  end

  # Amazon Pay決済API実行
  #
  # @param capture [Boolean] true: 即時売上, false: 与信
  # @param amount [Integer] 決済金額
  #
  # 与信の場合、実売上額に応じて後続処理を実行:
  # - 実売上額 > 0: capture_change による金額変更
  # - 実売上額 = 0: cancel_charge による与信キャンセル
  def api_payment(capture:, amount:)
    @payment_gateway = PaymentGateway::Proxy.factory(
      gateway: :amazon_pay,
      vendor: @vendor,
      user: self.order.user
    )
    @charge = @payment_gateway.charge.create(
      amount: amount,
      checkout_session_id: self.order.checkout_session_id,
    )

    self.update_amazon_pay_charge(capture)

    if !capture
      if self.order.payment_amount.positive?
        self.api_auth_capture_change
        @amazon_pay_charge.captured! if @amazon_pay_charge.may_captured?
      else
        self.api_cancel_charge
        @amazon_pay_charge.canceled! if @amazon_pay_charge.may_canceled?
      end
    end
  end

  # 与信から実売上への金額変更
  #
  # 与信後に実売上金額へ変更する処理。失敗時は全額返金を行う。
  def api_auth_capture_change
    @charge&.capture_change(self.order.payment_amount, charge_id: @charge.id)
  rescue => e
    gateway_name = @payment_gateway&.name || "決済ゲートウェイ"
    message = "【短期レンタル/サブスク】【注文】与信確保後の金額変更で失敗したため、全額返金します。#{gateway_name} "
    message << " order-id: #{@order.id}, "
    message << " payment-id: #{@charge&.id}"
    SlackNotificationsWorker.perform_async(message)
    raise e
  end

  # Amazon Pay与信キャンセル
  #
  # 与信後に実売上が発生しない場合の与信キャンセル処理。
  def api_cancel_charge
    @charge.cancel_charge(@charge.id)
  rescue => e
    gateway_name = @payment_gateway&.name || "決済ゲートウェイ"
    message = "【短期レンタル/サブスク】【注文】与信キャンセルに失敗しました。#{gateway_name} "
    message << " order-id: #{@order.id}, "
    message << " payment-id: #{@charge&.id}"
    Sentry.capture_message(message)
    Sentry.capture_exception(e)
    SlackNotificationsWorker.perform_async(message)
    raise e
  end

  # Amazon Pay請求情報更新
  #
  # @param capture [Boolean] 即時売上フラグ
  def update_amazon_pay_charge(capture)
    @amazon_pay_charge.update!(charge_permission_id: @charge.original_charge_data["chargePermissionId"])
    if capture
      @amazon_pay_charge.captured! if @amazon_pay_charge.may_captured?
    else
      @amazon_pay_charge.authorized! if @amazon_pay_charge.may_authorized?
    end
  end

  # 支払い情報保存
  #
  # Amazon Pay決済データから支払い情報を作成し、関連モデルに payment_id を設定する。
  # サブスクリプション注文の場合は、初回課金の payment_id も設定する。
  def save_payment
    payment_params = @charge.build_payment_params(payable: @amazon_pay_charge, first_order: true)
    @payment = @order.payments.create!(payment_params)
    @amazon_pay_charge.update!(payment_id: @payment.id)

    if self.order.order_subscription.present?
      self.order
        .order_subscription
        .order_subscription_charges
        .first
        .update_columns(payment_id: @payment.id)
    end
  end

  # Amazon PayアカウントとKauriruユーザーの紐付け
  #
  # Amazon PayのbuyerIdを取得し、Kauriruユーザーアカウントに保存する。
  # Amazonアカウントとカウリル会員が紐づいている場合は更新しない。
  def save_buyer_id
    response = AmazonPay.client.get_charge_permission(@charge.original_charge_data["chargePermissionId"])
    response = JSON.parse(response.body)
    buyer_id = response.dig("buyer", "buyerId")
    external_account = self.order.user.external_accounts.find_by(provider: :amazon_pay)
    # 現状、AmazonPayのアカウントは複数紐付けないようにしている。今後の要望次第
    if buyer_id.present? && external_account.blank?
      self.order.user.external_accounts.create!(uid: buyer_id, provider: :amazon_pay)
    end
  end

  # Amazon Pay返金処理
  #
  # 例外発生時の返金処理。失敗時はSlack通知とSentry記録を行う。
  def api_cancel
    @charge&.cancel
  rescue => e
    gateway_name = @payment_gateway&.name || "決済ゲートウェイ"
    message = "【短期レンタル/サブスク】【注文】返金に失敗しました。#{gateway_name}を確認して返金してください。 "
    message << " order-id: #{self.order.id}, "
    message << " payment-id: #{@charge&.id}"
    Sentry.capture_message(message)
    Sentry.capture_exception(e)
    SlackNotificationsWorker.perform_async(message)
    raise e if Rails.env.development?
  end

  # 決済失敗時の注文キャンセル処理
  #
  # 処理内容:
  # 1. 注文キャンセル処理の実行
  # 2. 返金情報の更新（refund_idが存在する場合）
  # 3. Amazon Pay請求ステータスの更新
  #
  # @see https://developer.amazon.com/ja/docs/amazon-pay-recurring-checkout/verify-and-complete-checkout.html
  def handle_failed
    self.order_cancel(:amazon_pay_failure_order_cancel_by_api!)
    @payment.api_cancel_after(@charge) if @payment.present?
    @amazon_pay_charge.capture_declined! if @amazon_pay_charge&.may_capture_declined?
  rescue => e
    message = "【短期レンタル/サブスク】【注文】決済失敗による注文キャンセルに失敗しました。管理画面を確認してください。 "
    message << " order-id: #{self.order.id}, "
    Sentry.capture_message(message)
    Sentry.capture_exception(e)
    SlackNotificationsWorker.perform_async(message)
    raise e if Rails.env.development?
  end

  # 注文キャンセル処理
  #
  # @param cancel_event [Symbol] 注文アイテムに対するキャンセルイベント
  #
  # 処理内容:
  # 1. 注文アイテムのステータス更新
  # 2. 返金額の設定
  # 3. サブスクリプションの更新（次回更新日クリア、返金額設定）
  # 4. 在庫の更新
  # 5. チェックアウトセッションの破棄
  def order_cancel(cancel_event)
    order.order_items.each do |order_item|
      order_item.send(cancel_event)
    end

    refund_amount = self.order.payment_amount
    self.order.refund_amount = refund_amount
    self.order.save!

    if self.order.order_subscription.present?
      self.order.order_subscription.update!(next_renewal_date: nil)
      self.order.order_subscription.order_subscription_charges.first.update!(
        refund_amount: refund_amount
      )
    end

    self.order.items.each do |item|
      Items::UpdateStockSummaryCommand.run!(item: item)
    end

    self.order.update!(checkout_session_id: nil)
  end

  # 注文確定後処理
  #
  # 注文作成完了後の後続処理を実行する。
  def create_after_process
    Order::Create::AfterCommand.run!(order: self.order)
  rescue => e
    Sentry.capture_exception(e)
    raise e if Rails.env.development?
  end
end
