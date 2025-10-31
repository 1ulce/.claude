# 【短期レンタル/サブスク】AmazonPayのタイムアウト自動キャンセル処理
class Order::Create::AmazonPay::TimeoutAutoCancelCommand < ApplicationCommand

  # 【短期レンタル/サブスク】注文情報
  record :order, default: nil
  validates :order, presence: true

  # コマンド実行
  # @return [Symbol]
  #   :success => 処理成功
  #   :error => 処理失敗
  #   :skip => 処理スキップ
  def execute
    return :skip if self.skip?
    self.validate_process
    return :error if self.errors.present?
    self.order.with_lock do
      if self.skip?
        @result = :skip
        break
      end
      self.validate_process
      break if self.errors.present?
      self.cancel
    end
    return :error if self.errors.present?
    @result
  rescue ActiveInteraction::InvalidInteractionError => e
    self.errors.merge!(e.interaction.errors)
    :error
  rescue => e
    Sentry.capture_exception(e)
    raise e
  end

  private

  # スキップ判定
  # ※ ロック処理を不要に行いたくない為、トランザクション前にも検証を二重で行っています。
  # workerから呼ばれる為、AmazonPayのコールバック/タイムアウトが既に完了している場合はスキップ
  # @return [Boolean] 完了/失敗/タイムアウトの場合はtrue
  def skip?
    amazon_pay_charge = self.order.amazon_pay_charges.first
    amazon_pay_charge.present? && (
      amazon_pay_charge.authorized? ||
      amazon_pay_charge.captured? ||
      amazon_pay_charge.capture_declined? ||
      amazon_pay_charge.refund_initiated? ||
      amazon_pay_charge.refunded? ||
      amazon_pay_charge.refund_declined? ||
      amazon_pay_charge.canceled?
    )
  end

  # 検証処理
  # ※ ロック処理を不要に行いたくない為、トランザクション前にも検証を二重で行っています。
  def validate_process
    # ベンダーが解約済
    if self.order.vendor.inactive?
      self.errors.add(:base, :vendor_inactive)
      return
    end

    # 対象の注文のステータスが初期値であること
    unless self.order.rentals.all?(&:any_initial?)
      self.errors.add(:base, :invalid_status)
      return
    end

    # 対象の注文に対して、支払い情報が存在すること
    amazon_pay_charge = self.order.amazon_pay_charges.first
    if amazon_pay_charge.blank?
      self.errors.add(:base, :invalid_payment)
      return
    end
  end

  # 注文キャンセル
  # コールバックAPIが未実行の場合、AmazonPay側の注文状態はオーソリのまま
  # オーソリは24時間後に自動キャンセルされるため、注文キャンセルを実行。
  # @see https://www.amazonpay-faq.jp/faq/QA-152
  def cancel
    refund_amount = self.order.price
    self.order.update!(refund_amount: refund_amount)
    self.order.order_items.map(&:amazon_pay_timeout_order_cancel_by_worker!)

    # サブスクの場合、次回更新日をリセット
    subscription = self.order.order_subscription
    if subscription.present?
      subscription.update!(next_renewal_date: nil)
      subscription.order_subscription_charges.first.update!(refund_amount: refund_amount)
    end

    # 在庫の更新
    self.order.items.each do |item|
      Items::UpdateStockSummaryCommand.run!(item: item)
    end

    # セッションの破棄
    if self.order.checkout_session_id.present?
      self.order.update!(checkout_session_id: nil)
    end
    @result = :success
  end
end
