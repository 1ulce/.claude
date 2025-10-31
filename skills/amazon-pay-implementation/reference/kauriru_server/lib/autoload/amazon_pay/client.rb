# frozen_string_literal: true

require 'amazon-pay-api-sdk-ruby'

class AmazonPay::Client
  attr_reader :config

  def initialize(config: nil, max_retries: nil)
    @config = config || AmazonPay::Config.default
    @client = AmazonPayClient.new(@config.to_sdk_config)
    @max_retries = max_retries || @config.max_retries || 3
  end

  # === ボタン署名の生成 ===
  def generate_button_signature(payload)
    @client.generate_button_signature(payload)
  end

  # === 店子事業者アカウント関連 ===
  def create_merchant_account(payload, headers: {})
    with_retry(:create_merchant_account) do
      @client.create_merchant_account(payload, headers: headers)
    end
  end

  # === チェックアウトセッション関連 ===

  # チェックアウトセッションを作成
  def create_checkout_session(payload, headers: {})
    with_retry(:create_checkout_session) do
      @client.create_checkout_session(payload, headers: headers)
    end
  end

  # チェックアウトセッション情報を取得
  def get_checkout_session(checkout_session_id, headers: {})
    with_retry(:get_checkout_session) do
      @client.get_checkout_session(checkout_session_id, headers: headers)
    end
  end

  # チェックアウトセッションを更新
  def update_checkout_session(checkout_session_id, payload, headers: {})
    with_retry(:update_checkout_session) do
      @client.update_checkout_session(checkout_session_id, payload, headers: headers)
    end
  end

  # チェックアウトセッションを完了
  def complete_checkout_session(checkout_session_id, payload, headers: {})
    with_retry(:complete_checkout_session) do
      @client.complete_checkout_session(checkout_session_id, payload, headers: headers)
    end
  end

  # === 決済（Charge）関連 ===

  # 決済を作成
  def create_charge(payload, headers: {})
    with_retry(:create_charge) do
      @client.create_charge(payload, headers: headers)
    end
  end

  # 決済情報を取得
  def get_charge(charge_id, headers: {})
    with_retry(:get_charge) do
      @client.get_charge(charge_id, headers: headers)
    end
  end

  # 決済をキャプチャ（売上確定）
  def capture_charge(charge_id, payload, headers: {})
    with_retry(:capture_charge) do
      @client.capture_charge(charge_id, payload, headers: headers)
    end
  end

  # 決済をキャンセル
  def cancel_charge(charge_id, payload, headers: {})
    with_retry(:cancel_charge) do
      @client.cancel_charge(charge_id, payload, headers: headers)
    end
  end

  def get_charge_permission(charge_permission_id, headers: {})
    with_retry(:get_charge_permission) do
      @client.get_charge_permission(charge_permission_id, headers: headers)
    end
  end

  # === 返金関連 ===

  # 返金を作成
  def create_refund(payload, headers: {})
    with_retry(:create_refund) do
      @client.create_refund(payload, headers: headers)
    end
  end

  # 返金情報を取得
  def get_refund(refund_id, headers: {})
    with_retry(:get_refund) do
      @client.get_refund(refund_id, headers: headers)
    end
  end

  # 会員情報を取得
  def get_buyer(buyer_token, headers: {})
    with_retry(:get_buyer) do
      @client.get_buyer(buyer_token, headers: headers)
    end
  end

  # === その他のSDKメソッド ===
  # 上記以外のメソッドは直接SDKに委譲
  def method_missing(name, *args, &block)
    if @client.respond_to?(name)
      @client.send(name, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @client.respond_to?(method_name) || super
  end

  private

  # レスポンスが成功かチェック
  def success_response?(response)
    response.respond_to?(:code) && (200..299).include?(response.code.to_i)
  end

  # HTTPレスポンスのエラーチェック
  def handle_response(response, method_name)
    return response if success_response?(response)

    raise AmazonPay::HttpStatusError.new(
      response.code.to_i,
      method: method_name.to_s,
      response_body: response.body
    )
  end

  # リトライ機能付きでブロックを実行
  # AmazonPay公式準拠：HTTPステータスコード429、500、503の場合のみリトライ
  def with_retry(method_name)
    retries = 0
    begin
      response = yield
      handle_response(response, method_name)
    rescue AmazonPay::HttpStatusError => e
      # リトライ可能なエラーの場合のみリトライ（429、500、503）
      if e.retry_able? && retries < @max_retries
        retries += 1
        delay = calculate_backoff_delay(retries)
        Rails.logger.info "Amazon Pay API retry: #{method_name} attempt #{retries}/#{@max_retries}, " \
                          "waiting #{delay}s... (HTTP #{e.status}: #{e.reason_code})"
        sleep delay
        retry
      end
      raise e
    end
  end

  # 指数的バックオフの待機時間を計算
  def calculate_backoff_delay(retry_count)
    base_delay = 2**(retry_count - 1) # 1秒、2秒、4秒...
    # ジッターを追加して同時リトライを避ける（0〜1秒のランダムな遅延）
    base_delay + rand(0.0..1.0)
  end
end
