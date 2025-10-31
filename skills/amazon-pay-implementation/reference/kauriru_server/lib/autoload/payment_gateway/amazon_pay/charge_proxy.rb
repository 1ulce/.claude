# Amazon PayのAPIをオブジェクトでラップするクラス
#
# 他の決済サービスとの差異を吸収するために、このクラスを利用する
class PaymentGateway::AmazonPay::ChargeProxy < PaymentGateway::Charge
  # APIレスポンスデータ
  attr_reader :response

  protected

  # コンストラクタ
  # @param response [Hash] Amazon Pay APIのレスポンスデータ
  def initialize(retrieve_response)
    @retrieve = retrieve_response
  end

  public

  # 決済情報を作成する
  # @param shop_id [String] ショップID（Amazon Payでは使用しないが、インターフェース互換性のため）
  # @param customer_id [String] 顧客ID（Amazon Payでは使用しない）
  # @param card_id [String] カードID（Amazon Payでは使用しない）
  # @param amount [Integer] 金額
  # @param capture [Boolean] 実売上の実施有無
  # @param tds2 [Boolean] 3Dセキュア2.0の実施有無（Amazon Payでは使用しない）
  # @param tds2_tenant_name [String] 3Dセキュア2.0のテナント名（Amazon Payでは使用しない）
  # @param tds2_callback_url [String] 3Dセキュア2.0のコールバックURL（Amazon Payでは使用しない）
  # @param meta_data [Hash] メタデータ（charge_permission_idまたはcheckout_session_idが必須）
  # @param kwargs [Hash] 追加パラメータ
  def self.create(
    shop_id: nil,
    customer_id: nil,
    card_id: nil,
    amount:,
    capture: true,
    tds2: false,
    tds2_tenant_name: nil,
    tds2_callback_url: nil,
    meta_data: {},
    **kwargs
  )

    # セッションIDがある場合はチェックアウトセッションを完了
    if kwargs[:checkout_session_id].present?
      return self.complete_checkout_session(
        checkout_session_id: kwargs[:checkout_session_id],
        amount: amount
      )
    end

    charge_permission_id = kwargs[:charge_permission_id]
    if charge_permission_id.blank?
      raise PaymentGateway::Error, 'charge_permission_idが必要です'
    end

    client = AmazonPay.client
    create_charge_payload = {
      "chargePermissionId": charge_permission_id,
      "chargeAmount": {
        "amount": amount,
        "currencyCode": "JPY"
      },
      "captureNow": true,
      "canHandlePendingAuthorization": false
    }
    headers = {
      "x-amz-pay-Idempotency-Key": SecureRandom.uuid.delete('-') # AmazonPayは最大32文字のため
    }

    if !Rails.env.production? && kwargs[:simulation_code].present?
      headers['x-amz-pay-Simulation-Code'] = kwargs[:simulation_code]
    end

    response = client.create_charge(create_charge_payload, headers: headers)
    charge_data = JSON.parse(response.body)

    charge_state = charge_data.dig("statusDetails", "state")
    if charge_state != AmazonPay::Consts::Charge::CAPTURED
      raise PaymentGateway::Error, "【Amazon Pay create】決済処理が失敗しました。"
    end

    self.new(charge_data)
  rescue => e
    raise PaymentGateway::Error, e
  end

  # チェックアウトセッションを完了する
  # @param checkout_session_id [String] チェックアウトセッションID
  # @param amount [Integer] 金額
  # @param kwargs [Hash] 追加パラメータ
  def self.complete_checkout_session(
    checkout_session_id:,
    amount:
  )

    payload = {
      "chargeAmount": {
        "amount": amount,
        "currencyCode": "JPY"
      }
    }

    client = AmazonPay.client
    response = client.complete_checkout_session(checkout_session_id, payload)
    checkout_data = JSON.parse(response.body)

    checkout_state = checkout_data.dig("statusDetails", "state")
    if checkout_state != AmazonPay::Consts::CheckoutSession::STATE_COMPLETED
      raise PaymentGateway::Error, "【Amazon Pay complete_checkout_session】決済処理が失敗しました。"
    end

    self.new(checkout_data)
  rescue => e
    raise PaymentGateway::Error, e
  end

  # 決済IDを取得する
  # @return [String] 決済ID
  def id
    @retrieve['chargeId']
  end

  # 決済情報を取得する
  # Amazon Payでは GetCharge APIを使用
  # @param shop_id [String] ショップID（Amazon Payでは使用しないが、インターフェース互換性のため）
  # @param payment_id [String] 決済ID
  # @return [PaymentGateway::AmazonPay::ChargeProxy] 決済情報
  # @raise [PaymentGateway::NotFoundError] 決済情報が見つからない場合
  # @raise [PaymentGateway::Error] 決済情報の取得でその他のエラーが発生した場合
  def self.retrieve!(shop_id, payment_id)
    response = AmazonPay.client.get_charge(payment_id)
    response = JSON.parse(response.body)
    self.new(response)
  rescue => e
    raise PaymentGateway::Error, e
  end

  # 決済情報の元データを取得する
  # @return [Hash] 決済情報の元データ（APIレスポンス）
  def original_charge_data
    @retrieve
  end

  # 3Dセキュアの実施状況を取得する
  # Amazon Payでは独自の決済フローを使用するため、常に:noneを返す
  def tds2_status
    :none
  end

  # 3Dセキュア2.0の認証を完了する
  # Amazon Payでは使用しないため、何もせずに:noneを返す
  def tds2_finish
    :none
  end

  # 3Dセキュア2.0の実施状況でunknownの場合のオリジナルのステータスを取得する
  # @return [String] オリジナルのTDS2ステータス
  def tds2_unknown_status
    nil
  end

  # 3Dセキュア2.0のリダイレクト先URLを取得する
  # @return [String] リダイレクト先URL
  def tds2_redirect_url
    nil
  end

  # 決済が認証済みかどうかを判定する
  # @return [Boolean] 認証済みの場合はtrue
  def paid?
    @retrieve.present?
  end

  # キャンセル可能かどうかを判定する
  # @return [Boolean] キャンセル可能な場合はtrue
  def cancelable?
    @retrieve.present? && !self.canceled?
  end

  # 決済のキャンセル（全額返金）を行う
  def cancel
    return unless self.cancelable?

    # 現在の最新の請求状態を取得
    client = AmazonPay.client
    get_charge_response = client.get_charge(self.id)
    get_charge_response = JSON.parse(get_charge_response.body)
    charge_state = get_charge_response.dig('statusDetails', 'state')
    capture_amount = get_charge_response.dig('captureAmount', 'amount')

    # オーソリ状態の場合は、オーソリをクローズする
    if charge_state == AmazonPay::Consts::Charge::AUTHORIZED
      charge_id = get_charge_response['chargeId']
      if charge_id.blank?
        raise PaymentGateway::Error, "ChargeIDが取得できませんでした。"
      end
      return self.cancel_charge(charge_id)
    end

    # オーソリ状態の場合は、オーソリをクローズする
    if charge_state == AmazonPay::Consts::Charge::AUTHORIZED
      charge_id = @retrieve['chargeId']
      if charge_id.blank?
        raise PaymentGateway::Error, "ChargeIDが取得できませんでした。"
      end
      return self.cancel_charge(charge_id)
    end

    # 決済金額が0の場合は以下の処理を行わない
    if capture_amount.to_i <= 0
      return self
    end

    payload = {
      "chargeId" => self.id,
      "refundAmount" => {
        "amount" => capture_amount,
        "currencyCode" => "JPY"
      },
    }
    headers = {
      "x-amz-pay-Idempotency-Key": SecureRandom.uuid.delete('-')
    }
    refund_response = client.create_refund(payload, headers: headers)
    refund_response = JSON.parse(refund_response.body)
    refund_state = refund_response.dig('statusDetails', 'state')
    if refund_state != AmazonPay::Consts::Refund::REFUND_INITIATED
      raise PaymentGateway::Error, "Amazon Pay: 返金処理に失敗しました。"
    end

    @retrieve = @retrieve.merge('refundId' => refund_response['refundId'])
    self
  rescue => e
    raise PaymentGateway::Error, e
  end

  # 部分返金を行う
  # @param amount [Integer] 返金額
  # @return [self]
  # 返金処理はAmazon側は非同期で処理される
  def refund(refund_amount = 0)
    raise ArgumentError, 'refund_amount is required' if refund_amount.nil?
    raise ArgumentError, 'refund_amount must be greater than 0' if refund_amount <= 0
    raise ArgumentError, 'refund_amount must be less than or equal to charge amount' if refund_amount > self.amount

    # 全額返金の場合はcancelメソッドを呼び出す
    return self.cancel if refund_amount == self.amount

    client = AmazonPay.client
    refund_payload = {
      chargeId: self.id,
      refundAmount: {
        amount: refund_amount.to_s,
        currencyCode: 'JPY'
      },
    }
    headers = {
      "x-amz-pay-Idempotency-Key": SecureRandom.uuid.delete('-')
    }

    response = client.create_refund(refund_payload, headers: headers)
    response = JSON.parse(response.body)
    @retrieve = @retrieve.merge('refundId' => response['refundId'])
    self
  rescue => e
    raise PaymentGateway::Error, e
  end

  # オーソリから売上確定への変更を行う
  def capture_change(amount, **kwargs)
    charge_id = kwargs[:charge_id]

    capture_charge_payload = {
      captureAmount: {
        amount: amount,
        currencyCode: "JPY"
      }
    }
    headers = {
      "x-amz-pay-Idempotency-Key": SecureRandom.uuid.delete('-')
    }
    client = AmazonPay.client
    response = client.capture_charge(charge_id, capture_charge_payload, headers: headers)
    capture_charge_data = JSON.parse(response.body)
    capture_charge_state = capture_charge_data.dig("statusDetails", "state")
    if capture_charge_state != AmazonPay::Consts::CaptureCharge::CAPTURED
      raise PaymentGateway::Error, "売上確定処理に失敗しました。"
    end

    self.class.new(capture_charge_data)
  rescue => e
    raise PaymentGateway::Error, e
  end

  def cancel_charge(charge_id)
    client = AmazonPay.client
    cancel_payload = {
      "cancellationReason": "決済金額が0円のため、オーソリのキャンセルを行いました。",
    }
    response = client.cancel_charge(charge_id, cancel_payload)
    cancel_response = JSON.parse(response.body)
    cancel_state = cancel_response.dig("statusDetails", "state")
    if cancel_state != AmazonPay::Consts::Charge::CANCELED
      raise PaymentGateway::Error, "オーソリのキャンセルに失敗しました。"
    end

    self.class.new(cancel_response)
  rescue => e
    raise PaymentGateway::Error, e
  end

  # 決済のステータスが成功(売上確定)かどうかを判定する
  def captured?
    @retrieve['statusDetails']&.[]('state') == AmazonPay::Consts::Charge::CAPTURED
  end

  # 決済のステータスがキャンセルかどうかを判定する
  def canceled?
    # Canceledステータスをチェック（Completedはチェックアウト完了状態）
    @retrieve['statusDetails']&.[]('state') == AmazonPay::Consts::Charge::CANCELED
  end

  # 決済のステータスが返金済みかどうかを判定する
  def refunded?
    @retrieve['statusDetails']&.[]('state') == AmazonPay::Consts::Refund::REFUNDED
  end

  # 決済の利用金額を取得する
  def amount
    @retrieve&.dig('chargeAmount', 'amount').to_i
  end

  # 返金IDを取得する
  # @return [String, nil] 返金ID
  def refund_id
    # 最後の返金IDがあればそれを返す
    @retrieve['refundId'] || nil
  end

end
