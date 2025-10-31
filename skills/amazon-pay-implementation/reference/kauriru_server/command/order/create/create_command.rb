# API:注文作成コマンド
# 名前変更 Rentals::OrderCommand -> Api::Order::CreateCommand
class Api::Order::CreateCommand < ApplicationCommand
  object :cart, class: Cart
  integer :vendor_id, :address_id
  date :start_date, default: -> {
    cart.cart_items.with_vendor(vendor_id).first.start_date
  }
  date :end_date, default: -> {
    cart_item = cart.cart_items.with_vendor(vendor_id).first
    cart_item.order_type_rental? ? cart_item.end_date : nil
  }
  string :payment_type, default: nil
  integer :way_to_receive
  integer :credit_card_id, default: nil
  integer :store_id, default: nil
  string :notes, default: nil
  string :delivery_time, default: nil
  string :remote_ip, default: nil
  string :user_agent, default: nil
  string :browser_fingerprint, default: nil
  string :tracking, default: nil

  integer :user_coupon_id, default: nil
  string :checkout_session_id, default: nil

  validates :credit_card_id, presence: true, if: -> { payment_type == 'credit' }
  string :locale, default: 'ja'

  attr_accessor :gmo_card, :vendor, :active_payment_gateway

  def execute
    self.credit_card_id = nil if payment_type != 'credit'
    @order = nil
    begin
      ActiveRecord::Base.transaction do
        record_lock
        check_owner
        check_correct_order

        self.calc_cart_summary
        @order = create_order
        create_order_items(@order)
        create_order_coupon(@order, @user_coupon)
        self.create_order_subscription_charge_if_needed
        self.charge
        self.update_checkout
        if !@order.payment_type_amazon_pay? && @tds2_redirect_url.blank?
          cart.cart_items.with_vendor(vendor_id).destroy_all
        end
        @order.reload
      end
    rescue => e
      self.api_cancel
      raise e
    end
    self.create_tracking
    self.create_after_process
    self.order_with_redirect
  rescue ActiveInteraction::InvalidInteractionError => e
    self.errors.merge!(e.interaction.errors)
    raise e
  end

  private

  def record_lock
    self.cart.lock!
    self.vendor = Vendor.active
      .eager_load(:vendor_payjp_tenant, :gmo_tenant, :amazon_pay_account)
      .find(self.vendor_id)
  end

  def check_owner
    @address = Address.find(address_id)
    # 「保存しない」を選んだ場合、address の user_id が空のため所有者チェックができない
    if @address.user_id && @address.user_id != cart.user_id
      raise UnexpectedOrderError, 'address_id が user のものではありません'
    end

    if store_id
      store = Store.find(store_id)
      if store.vendor_id != vendor_id
        raise UnexpectedOrderError, 'store が vendor のものではありません。'
      end
    end

    # 所有クーポンのチェック
    if self.user_coupon_id.present?
      @user_coupon = UserCoupon.find(self.user_coupon_id)
      if @user_coupon.user_id != cart.user_id
        raise UnexpectedOrderError, 'user_coupon が user のものではありません。'
      end
      # クーポンの vendor が異なる場合はエラー
      # ただし、全てのストアが使用可能なクーポンの場合は vendor_id が nil になる
      if @user_coupon.coupon.vendor_id.present? && @user_coupon.coupon.vendor_id != self.vendor_id
        raise UnexpectedOrderError, 'user_coupon が vendor のものではありません。'
      end
    end

    # Amazonアカウントのチェック
    if self.payment_type == 'amazon_pay' &&
       self.checkout_session_id.present? &&
       self.cart.user.external_accounts.exists?(provider: :amazon_pay)
      response = AmazonPay.client.get_checkout_session(self.checkout_session_id)
      response = JSON.parse(response.body)

      buyer_id = response.dig("buyer", "buyerId")
      external_account = self.cart.user.external_accounts.amazon_pay.first
      if buyer_id != external_account&.uid
        raise UnexpectedOrderError, 'buyer_idが user のものではありません。'
      end
    end

    return if payment_type != 'credit'
    raise UnexpectedOrderError, 'credit_card_id がありません。' if self.credit_card_id.blank?

    self.active_payment_gateway = self.vendor.active_payment_gateway(self.cart.user)
    if self.active_payment_gateway == :payjp
      raise UnexpectedOrderError, 'user.customer_id がありません。' if self.cart.user.customer_id.blank?
      has_credit_card = self.cart.user.credit_cards.exists?(self.credit_card_id)
      raise UnexpectedOrderError, 'credit_card_id が user のものではありません。' unless has_credit_card
    elsif self.active_payment_gateway == :gmo_fincode
      raise UnexpectedOrderError, 'user.gmo_customer がありません。' if self.cart.user.gmo_customer.blank?
      self.gmo_card = self.cart.user.gmo_cards.kept.find_by(id: self.credit_card_id)
      raise UnexpectedOrderError, 'credit_card_id が user のものではありません。' unless self.gmo_card
    else
      raise UnexpectedOrderError, 'unknown payment gateway'
    end
  end

  def check_correct_order
    cart.cart_items.with_vendor(vendor_id).each do |cart_item|
      unless Carts::CheckCurrentSettingCommand.run!(cart_item: cart_item)
        raise UnexpectedOrderError, "アイテムの設定が変わっています"
      end
    end

    unless cart.check_order_item_combination(vendor_id)
      raise UnexpectedOrderError, '組み合わせられない注文の組み合わせです'
    end

    order_type = cart.cart_items.with_vendor(vendor_id).first.order_type
    unless self.vendor.available_payment_type?(payment_type, order_type, way_to_receive, @address)
      raise UnexpectedOrderError, "対応していない支払い方法です"
    end

    today = Date.current
    if start_date < today
      self.errors.add(:base, :invalid_start_date)
      return
    end

    # 前回の3Dセキュアが未完了の場合は中断する
    if self.cart.user.order_tds2_pending?(self.vendor)
      self.errors.add(:base, :invalid_order_tds2_pending)
      return
    end

    check_number_of_nights
  end

  # https://github.com/tent-inc/kauriru_web/issues/567
  #  - 最低宿泊日数と最大泊数内におさまらない泊数でリクエストがきたらエラーにする
  def check_number_of_nights
    cart.cart_items.with_vendor(vendor_id).each do |cart_item|
      next unless cart_item.order_type_rental?
      unless (cart_item.item.min_number_of_nights..cart_item.item.max_number_of_nights).include?(cart_item.number_of_nights)
        # 購入できないのでカートを消す
        cart.cart_items.with_vendor(vendor_id).destroy_all
        raise UnexpectedOrderError
      end
    end
  end

  # カート内の商品の合計金額を計算
  def calc_cart_summary
    @cart_summary_command = Carts::CheckoutSummaryCommand.run(
      cart: self.cart,
      vendor: self.vendor,
      user_coupon: @user_coupon
    )
    @cart_summary = @cart_summary_command.result
    if @cart_summary_command.errors.present?
      raise UnexpectedOrderError, @cart_summary_command.errors.full_messages.join("\n")
    end
  end

  def create_order
    cart.user.orders.create! build_order_params
  end

  def create_order_items(order)
    reservation_type = guess_reservation_type(cart)
    cart.cart_items.with_vendor(vendor_id).each do |cart_item|
      item = cart_item.item
      item.lock!
      exist_stock = Rentals::CheckStockCommand.run!(item: item,
                                                    start_date: start_date,
                                                    end_date: end_date,
                                                    way_to_receive: order.way_to_receive,
                                                    order_type: cart_item.order_type,
                                                    quantity: cart_item.quantity)
      raise NotEnoughItemStockError unless exist_stock
      cart_item.quantity.times do
        order_item = order.rentals.create! build_order_item_params(cart_item, reservation_type)
        cart_item.cart_item_options.each do |cart_item_option|
          order_item.order_item_options.create!(
            option_type: cart_item_option&.option_type,
            option_name: cart_item_option.option_name,
            option_item_name: cart_item_option&.option_item_name,
            option_date: cart_item_option&.option_date,
            option_content: cart_item_option&.option_content,
            option_item_price: cart_item_option.option_item_price,
            zero_price_display: cart_item_option.zero_price_display?
          )
        end
      end
      if order.order_type_subscription?
        order.create_order_subscription! build_order_subscription(cart_item)
      end
      Items::UpdateStockSummaryCommand.run!(item: item)
    end
  end

  # 注文クーポンの作成
  def create_order_coupon(order, user_coupon)
    return unless user_coupon
    order.create_order_coupon!(
      user_coupon: @user_coupon,
    )
  end

  def create_order_subscription_charge_if_needed
    return unless @order.order_subscription
    @order_subscription_charge = Subscriptions::CreateChargeCommand.run!(order: @order, first_charge: true)
  end

  def guess_reservation_type(cart)
    cart.cart_items.with_vendor(vendor_id).each do |cart_item|
      return 'temporary' if cart_item.item.reservation_type_temporary?
    end
    'committed'
  end

  def build_order_params
    # 本人確認が必要なアイテムかあるか？
    required_verify_user = self.cart.cart_items.with_vendor(vendor_id).map(&:item).any?(&:verify_user?)
    @verify_user_pending = false
    if required_verify_user
      if self.locale != 'ja'
        @verify_user_pending = false # パスポートは英語の場合は、注文前に行われているはず
      else
        @verify_user_pending = !(self.cart.user.identity_approved? || self.cart.user.identity_passports&.last&.status == 'approved')
      end
    end

    credit_card_id = nil
    gmo_card_id = nil
    if self.active_payment_gateway == :payjp
      credit_card_id = self.credit_card_id
    elsif self.active_payment_gateway == :gmo_fincode
      gmo_card_id = self.gmo_card.id
    end

    {
      vendor_id: vendor_id,
      payment_type: payment_type,
      credit_card_id: credit_card_id,
      gmo_card_id: gmo_card_id,
      address_id: address_id,
      notes: notes,
      delivery_time: delivery_time,
      way_to_receive: way_to_receive,
      store_id: store_id,
      point: 0,
      shipping_cost_configured: self.vendor.shipping_cost_configured,
      remote_ip: remote_ip,
      user_agent: user_agent,
      browser_fingerprint: browser_fingerprint,
      order_type: @cart_summary.order_type,
      price: @cart_summary.total_price,
      payment_amount: @cart_summary.total_price,
      shipping_cost: @cart_summary.shipping_cost,
      coupon_target_amount: @cart_summary.coupon_target_amount,
      coupon_discount_amount: @cart_summary.coupon_discount_amount,
      verify_user_pending: @verify_user_pending, # 本人確認による保留
    }
  end

  def build_order_item_params(cart_item, reservation_type)
    status = reservation_type == 'temporary' ? 'temporary_reserved' : 'prepare_shipment'
    calc = cart_item.calc_rental_price
    {
      item_id: cart_item.item.id,
      price: calc.price,
      start_date: start_date,
      end_date: end_date,
      type: "Rental",
      status: status,
      option_price: cart_item.option_price,
      discount_amount: calc.discount_amount,
      coupon_target: @user_coupon&.coupon&.target_item?(cart_item.item) || false,
    }
  end

  def build_order_subscription(cart_item)
    subscription_rental_price = cart_item.item.item_subscriptions.find_by(min_period: cart_item.min_subscription_period)
    expiry_date = nil
    if subscription_rental_price.max_period.present?
      expiry_date = start_date + subscription_rental_price.max_period.months - 1
    end
    {
      item_id: cart_item.item_id,
      subscription_type: cart_item.subscription_type,
      start_date: start_date,
      expiry_date: expiry_date,
      min_period: subscription_rental_price.min_period,
      max_period: subscription_rental_price.max_period,
      rental_price: subscription_rental_price.rental_price,
      rental_discount_rate: subscription_rental_price.rental_discount_rate,
      purchase_price: subscription_rental_price.purchase_price,
      next_renewal_date: OrderSubscription.calc_next_renewal_date(cart_item.start_date),
    }
  end

  def charge
    return if @order.payment_type_amazon_pay?
    return unless @order.payment_process_required?

    @authorization_amount = @order.calc_authorization_amount

    # 与信額がある場合は与信額で与信を行う
    if @authorization_amount.positive?
      self.api_payment(capture: false, amount: @authorization_amount)
    elsif @order.payment_amount.positive? # 金額が0円の場合は決済を行わない
      self.api_payment(capture: true, amount: @order.payment_amount)
    end
  end

  ## 決済関連

  # 3Dセキュアが有効か？
  def tds2_enabled?
    self.vendor.tds2_enabled?
  end

  # API決済処理
  def api_payment(capture:, amount:)
    # 外部APIで決済を行う
    @payment_gateway = PaymentGateway::Proxy.factory(
      gateway: self.active_payment_gateway,
      vendor: self.vendor,
      user: self.cart.user
    )
    @charge = @payment_gateway.charge.create(
      capture: capture,
      amount: amount,
      tds2: self.tds2_enabled?,
      tds2_callback_url: self.tds2_callback_url,
      meta_data: {
        order_id: @order.id,
        vendor_name: self.vendor.name,
        model_name: @order.model_name.human,
      }
    )

    # 3Dセキュアの場合はリダイレクトURLを設定
    # 3Dセキュアが無効の場合は
    # - 与信額がある場合
    #   - 実際の実売上がある場合は実売上を行う
    #   - 実際の実売上がない場合は与信をキャンセルする
    if self.tds2_enabled?
      @tds2_redirect_url = @charge.tds2_redirect_url
    elsif @authorization_amount.positive?
      if @order.payment_amount.positive?
        self.api_auth_capture_change
      else
        self.api_cancel
      end
    end

    # 支払い情報を保存
    payment_params = @charge.build_payment_params(first_order: true)
    payment = @order.payments.create!(payment_params)

    # サブスクリプションの場合はサブスクリプションチャージにも payment_id を設定
    if @order_subscription_charge.present?
      @order_subscription_charge.update_columns(
        payment_id: payment.id
      )
    end
  end

  # 与信の金額変更処理
  def api_auth_capture_change
    @charge&.capture_change(@order&.payment_amount)
  rescue => e
    message = "【短期レンタル/サブスク】【注文】与信確保後の金額変更で失敗したため、全額返金します。#{@payment_gateway.name} "
    message << " order-id: #{@order.id}, "
    message << " payment-id: #{@charge.id}"
    SlackNotificationsWorker.perform_async(message)
    raise e
  end

  # キャンセル処理
  def api_cancel
    if @tds2_redirect_url.blank? || !@order.payment_type_amazon_pay?
      @charge&.cancel
    end
  rescue => e
    message = "【短期レンタル/サブスク】【注文】処理失敗時の返金に失敗しました。#{@payment_gateway.name}を確認して返金してください。 "
    message << " orde-id: #{@order.id}, "
    message << " payment-id: #{@charge.id}"
    Sentry.capture_message(message)
    Sentry.capture_exception(e)
    SlackNotificationsWorker.perform_async(message)
    raise e
  end

  # TDS2コールバックURL
  def tds2_callback_url
    "#{Settings.default_url_options}/api/v1/orders/#{@order.id}/tds2_callback"
  end

  # AmazonPayのチェックアウトセッション更新
  def update_checkout
    # 支払い方法がamazonPayの場合でないはスキップ
    return unless @order.payment_type_amazon_pay?

    # セッションが存在している場合はセッションを破棄
    @order.update!(checkout_session_id: nil) if @order.checkout_session_id.present?

    checkout_session_response = AmazonPay::UpdateCheckoutSessionCommand.run!(
      order: @order,
      checkout_session_id: self.checkout_session_id
    )
    @amazon_pay_redirect_url = checkout_session_response["webCheckoutDetails"]["amazonPayRedirectUrl"]
    @order.update!(checkout_session_id: self.checkout_session_id)
  end

  ## トランザクション外の処理

  # トラッキング
  def create_tracking
    Tracking::OrderRegistrationCommand.run!(
      order: @order,
      user: self.cart.user,
      tracking: self.tracking
    )
  rescue => e
    # 主となる処理ではないので、エラーを握りつぶす
    Sentry.capture_exception(e)
    raise e if Rails.env.development?
  end

  # 注文確定後の処理
  def create_after_process
    if @tds2_redirect_url.present?
      # 3Dセキュアのタイムアウト+1分後にタイムアウト処理を行う
      timeout_sec = @payment_gateway.charge.tds2_timeout_sec + 60
      Order::Create::Tds2::TimeoutWorker.perform_in(timeout_sec.seconds, @order.id)
    elsif @amazon_pay_redirect_url.present?
      # AmazonPayのセッション開始+15分後にタイムアウト処理を行う
      timeout_sec = @order.updated_at.to_i + 15 * 60 # 15分 = 900秒
      Order::Create::AmazonPay::TimeoutWorker.perform_in(timeout_sec.seconds, @order.id)
    else
      # 3Dセキュアが無効の場合、注文確定後の処理を行う
      Order::Create::AfterCommand.run!(order: @order)
    end
  rescue => e
    # 主となる処理ではないので、エラーを握りつぶす
    Sentry.capture_exception(e)
    raise e if Rails.env.development?
  end

  def order_with_redirect
    redirect_url ||= @tds2_redirect_url || @amazon_pay_redirect_url
    OpenStruct.new({
      order: @order,
      redirect_url: redirect_url,
    })
  end
end
