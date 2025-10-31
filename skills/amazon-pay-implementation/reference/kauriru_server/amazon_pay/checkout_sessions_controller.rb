# Amazon Pay チェックアウトセッション管理コントローラ
#
# Amazon Pay決済フローの開始時に必要なチェックアウトセッションの作成、
# ペイロード生成、セッション情報の取得を行う
class Api::V1::AmazonPay::CheckoutSessionsController < Api::V1::ApiController
  before_action :load_user, only: [:show]

  # チェックアウトセッションを作成
  #
  # 注文種別（レンタル/サブスク）に応じたペイロードを生成し、
  # Amazon Pay APIを使用してチェックアウトセッションを作成する
  def create
    @vendor = Vendor.active.by_origin(@origin).find_by(name: params[:vendor])
    payload = checkout_payload(params[:order_type], params[:is_store_pickup])
    client = AmazonPay.client
    headers = { "x-amz-pay-Idempotency-Key" => SecureRandom.uuid.delete('-') }
    response = client.create_checkout_session(payload, headers: headers)
    response = JSON.parse(response.body)

    render_json(response)
  end

  def generate_payload
    payload_type = params[:payload_type] || 'signin'

    payload = case payload_type
              when 'signin'
                signin_payload(params)
              when 'apb'
                apb_payload(params)
              else
                raise ArgumentError, "Unknown payload_type: #{payload_type}"
              end

    client = AmazonPay.client
    signature = client.generate_button_signature(payload)

    render json: { payload: payload, signature: signature }
  end

  # チェックアウトセッション情報を取得
  #
  # 指定されたセッションIDの詳細情報をAmazon Pay APIから取得する
  def show
    client = AmazonPay.client
    response = client.get_checkout_session(params[:id])
    response = JSON.parse(response.body)
    buyer_id = response.dig("buyer", "buyerId")
    # 他のユーザーに紐づいていないかチェック
    external_account = ExternalAccount.find_by(uid: buyer_id, provider: "amazon_pay")
    return render_json(response) if external_account.blank?

    if current_user != external_account.user
      return render_unprocessable_entity("Amazonアカウントが既に他ユーザーに紐づいています。")
    end

    render_json(response)
  end

  private

  # ユーザー情報を読み込み
  #
  # 認証済みユーザーまたはカートトークンからユーザーを特定する
  def load_user
    if current_user.present?
      @user = current_user
    else
      @user = Cart.find_by(cart_tokens: request.headers[:cartTokens])&.user
    end
  end

  # 決済ボタンのペイロードを生成
  #
  # 注文種別に応じてチェックアウトセッションのペイロードを作成する
  # サブスクリプション注文の場合は定期課金の設定を含める
  #
  # @param order_type [String] 注文種別（"subscription" または nil）
  # @return [Hash] チェックアウトセッションのペイロード
  def checkout_payload(order_type = nil, is_store_pickup = nil)
    if is_store_pickup.present? && is_store_pickup == "true"
      callback_url = UriUtils.create_front_url(@vendor.name, "/checkout?vendor=#{@vendor.name}&step=pickup_store")
    else
      callback_url = UriUtils.create_front_url(@vendor.name, "/checkout?vendor=#{@vendor.name}&step=pickup_time")
    end

    payload = {
      "webCheckoutDetails" => {
        "checkoutReviewReturnUrl" => callback_url
      },
      "storeId" => Settings.amazon_pay.store_id,
      "scopes" => ["email", "phoneNumber"],
      "chargePermissionType" => (order_type == "subscription" ? "Recurring" : "OneTime")
    }

    if order_type == "subscription"
      payload["recurringMetadata"] = {
        "frequency" => {
          "unit" => "Month",
          "value" => "1"
        }
      }
    else
      # 再オーソリの有効期限が180日から13ヶ月に延長(強制決済や長期予約を考慮)
      # ボタンレンダリング時に設定しないと後で設定しても適用されない
      payload["paymentDetails"] = {
        "extendExpiration" => true
      }
    end
    payload
  end

  # APB決済ボタンのペイロード
  def apb_payload(data = {})
    process = data[:process]
    case process
    when "purchase"
      order_item = OrderItem.find(data[:order_item_id])
      order = order_item.order
      payment_amount = data[:payment_amount]
      callback_url = "#{Settings.default_url_options}/api/v1/rentals/#{order_item.id}/purchase_amazon_pay_callback"
    when "return"
      order = Order.find(data[:order_id])
      payment_amount = data[:payment_amount]
      callback_url = "#{Settings.default_url_options}/api/v1/orders/#{order.id}/return_amazon_pay_callback"
    when "additional_charge"
      additional_charge = OrderAdditionalCharge.find_by(order_additional_charge_id: data[:additional_charge_id])
      order = additional_charge.order
      payment_amount = data[:payment_amount]
      callback_url = "#{Settings.default_url_options}/api/v1/additional_charges/" \
                     "#{additional_charge.order_additional_charge_id}/amazon_pay_callback"
    end

    payload = {
      "webCheckoutDetails" => {
        "checkoutResultReturnUrl" => callback_url,
        "checkoutCancelUrl" => UriUtils.create_front_url(order.vendor.name, "/my-page/usage-list/#{order.id}"),
        "checkoutMode" => 'ProcessOrder'
      },
      "storeId" => Settings.amazon_pay.store_id,
      "chargePermissionType" => 'OneTime',
      "paymentDetails" => {
        "paymentIntent" => 'AuthorizeWithCapture',
        "canHandlePendingAuthorization" => false,
        "chargeAmount" => {
          "amount" => payment_amount.to_s,
          "currencyCode" => 'JPY'
        },
        "extendExpiration" => true
      },
      "merchantMetadata": {
        "merchantReferenceId": order.id.to_s,
        "merchantStoreName": order.vendor.service_name,
        "noteToBuyer": order.vendor.name_kanji
      },
      "scopes" => ["email"]
    }

    payload
  end

  def signin_payload(data = {})
    process = data[:process]
    vendor_name = data[:vendor_name]
    case process
    when "mypage"
      callback_url = UriUtils.create_front_url(vendor_name, "configuration/external-accounts")
      cancel_url = UriUtils.create_front_url(vendor_name, "configuration")
    else
      callback_url = UriUtils.create_front_url(vendor_name, "after-signin?vendor=#{vendor_name}&loginType=amazon_pay")
      cancel_url = UriUtils.create_front_url(vendor_name, "login")
    end
    payload = {
      "signInReturnUrl" => callback_url,
      "signInCancelUrl" => cancel_url,
      "storeId" => Settings.amazon_pay.store_id,
      "signInScopes" => ["email"]
    }
    payload
  end
end
