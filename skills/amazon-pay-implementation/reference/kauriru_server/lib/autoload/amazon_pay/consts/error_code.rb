# frozen_string_literal: true

module AmazonPay::Consts::ErrorCode
  # 共通エラーコード（全APIで使用される可能性があるエラー）

  # 400 BAD_REQUEST
  INVALID_HEADER_VALUE = "InvalidHeaderValue"
  INVALID_REQUEST = "InvalidRequest"
  INVALID_PARAMETER_VALUE = "InvalidParameterValue"
  INVALID_REQUEST_FORMAT = "InvalidRequestFormat"
  MISSING_HEADER = "MissingHeader"
  MISSING_HEADER_VALUE = "MissingHeaderValue"
  MISSING_PARAMETER_VALUE = "MissingParameterValue"
  UNRECOGNIZED_FIELD = "UnrecognizedField"
  INVALID_SANDBOX_SIMULATION_SPECIFIED = "InvalidSandboxSimulationSpecified"
  DUPLICATE_IDEMPOTENCY_KEY = "DuplicateIdempotencyKey"
  INVALID_PARAMETER_COMBINATION = "InvalidParameterCombination"
  CURRENCY_MISMATCH = "CurrencyMismatch"
  INVALID_API_VERSION = "InvalidAPIVersion"
  TRANSACTION_AMOUNT_EXCEEDED = "TransactionAmountExceeded"
  PERIODIC_AMOUNT_EXCEEDED = "PeriodicAmountExceeded"

  # 401 UNAUTHORIZED
  UNAUTHORIZED_ACCESS = "UnauthorizedAccess"

  # 403 FORBIDDEN
  INVALID_AUTHENTICATION = "InvalidAuthentication"
  INVALID_ACCOUNT_STATUS = "InvalidAccountStatus"
  INVALID_REQUEST_SIGNATURE = "InvalidRequestSignature"
  INVALID_AUTHORIZATION_TOKEN = "InvalidAuthorizationToken"

  # 404 NOT_FOUND
  RESOURCE_NOT_FOUND = "ResourceNotFound"

  # 405 METHOD_NOT_ALLOWED
  UNSUPPORTED_OPERATION = "UnsupportedOperation"
  REQUEST_NOT_SUPPORTED = "RequestNotSupported"

  # 408 REQUEST_TIMEOUT（公式ドキュメントでは再試行対象外）
  REQUEST_TIMEOUT = "RequestTimeout"

  # 409 CONFLICT
  AMOUNT_MISMATCH = "AmountMismatch"

  # 422 UNPROCESSABLE_ENTITY
  INVALID_CHARGE_STATUS = "InvalidChargeStatus"
  TRANSACTION_COUNT_EXCEEDED = "TransactionCountExceeded"
  AMAZON_REJECTED = "AmazonRejected"
  INVALID_CHECKOUT_SESSION_STATUS = "InvalidCheckoutSessionStatus"
  CHECKOUT_SESSION_CANCELED = "CheckoutSessionCanceled"
  HARD_DECLINED = "HardDeclined"
  PAYMENT_METHOD_NOT_ALLOWED = "PaymentMethodNotAllowed"
  MFANotCompleted = "MFANotCompleted"
  TRANSACTION_TIMED_OUT = "TransactionTimedOut"
  INVALID_CHARGE_PERMISSION_STATUS = "InvalidChargePermissionStatus"
  SOFT_DECLINED = "SoftDeclined"

  # 426 UPGRADE_REQUIRED
  TLS_VERSION_NOT_SUPPORTED = "TLSVersionNotSupported"

  # 429 TOO_MANY_REQUESTS
  TOO_MANY_REQUESTS = "TooManyRequests"

  # 500 INTERNAL_SERVER_ERROR
  INTERNAL_SERVER_ERROR = "InternalServerError"
  PROCESSING_FAILURE = "ProcessingFailure" # 返金関連

  # 503 SERVICE_UNAVAILABLE
  SERVICE_UNAVAILABLE = "ServiceUnavailable"

  # エラーメッセージマッピング
  ERROR_MESSAGES = {
    # 400 BAD_REQUEST
    INVALID_HEADER_VALUE => "APIヘッダーパラメータに無効な値が含まれています",
    INVALID_REQUEST => "リクエストが無効です",
    INVALID_PARAMETER_VALUE => "APIパラメータに無効な値が含まれています",
    INVALID_REQUEST_FORMAT => "リクエストのJSON形式が無効です",
    MISSING_HEADER => "必須のヘッダーパラメータが不足しています",
    MISSING_HEADER_VALUE => "ヘッダーパラメータの値が不足しています",
    MISSING_PARAMETER_VALUE => "必須のリクエストパラメータが不足しています",
    UNRECOGNIZED_FIELD => "リクエストに認識できないフィールドが含まれています",
    INVALID_SANDBOX_SIMULATION_SPECIFIED => "サンドボックスで無効な操作が試行されました",
    DUPLICATE_IDEMPOTENCY_KEY => "冪等キーが既に使用されています",
    INVALID_PARAMETER_COMBINATION => "無効なパラメータの組み合わせです",
    CURRENCY_MISMATCH => "通貨コードが一致しません",
    INVALID_API_VERSION => "サポートされていないAPIバージョンです",
    TRANSACTION_AMOUNT_EXCEEDED => "許可されている最大請求または返金金額を超えました。",
    PERIODIC_AMOUNT_EXCEEDED => "許可されている月間最大請求額を超えました。",
    # 401 UNAUTHORIZED
    UNAUTHORIZED_ACCESS => "このリクエストを実行する権限がありません",
    # 403 FORBIDDEN
    INVALID_AUTHENTICATION => "認証に失敗しました",
    INVALID_ACCOUNT_STATUS => "アカウントが適切な状態ではありません",
    INVALID_REQUEST_SIGNATURE => "リクエスト署名が無効です",
    INVALID_AUTHORIZATION_TOKEN => "認証トークンが無効です",
    # 404 NOT_FOUND
    RESOURCE_NOT_FOUND => "リソースが見つかりません",
    # 405 METHOD_NOT_ALLOWED
    UNSUPPORTED_OPERATION => "この操作はサポートされていません",
    REQUEST_NOT_SUPPORTED => "このHTTPメソッドはサポートされていません",
    # 408 REQUEST_TIMEOUT
    REQUEST_TIMEOUT => "リクエストがタイムアウトしました。再試行してください（ただし、正常なレスポンスは保証されません）",
    # 409 CONFLICT
    AMOUNT_MISMATCH => "決済金額が一致していません",
    # 422 UNPROCESSABLE_ENTITY
    INVALID_CHARGE_STATUS => "現在の決済の状態では呼び出せない処理を呼び出そうとしました",
    TRANSACTION_COUNT_EXCEEDED => "1つの注文に対する最大請求または返金回数を超えました。",
    AMAZON_REJECTED => "Amazonによって請求または返金が拒否されました。",
    INVALID_CHECKOUT_SESSION_STATUS => "許可されていないステータスのチェックアウトセッションに対して処理を実行しようとしました。",
    CHECKOUT_SESSION_CANCELED => "購入者が取引をキャンセルしたか、支払いが拒否されたため、決済に失敗しました",
    PAYMENT_METHOD_NOT_ALLOWED => "購入者が選択した支払い方法は、この決済に対しては許可されていません",
    MFANotCompleted => "トランザクションを処理するには、購入者が多要素認証(MFA)を完了する必要があります",
    TRANSACTION_TIMED_OUT => "処理がタイムアウトしました。Amazon Pay以外のお支払い方法への変更をご検討ください。",
    INVALID_CHARGE_PERMISSION_STATUS => "変更できない状態のAmazon注文IDを変更しようとしました",
    SOFT_DECLINED => "決済が一時的に拒否されました。時間をおいて再度お試しいただくか、Amazon Pay以外のお支払い方法への変更をご検討ください。",
    HARD_DECLINED => "決済が拒否されました。購入者様にお支払い方法の変更をお願いするか、Amazon Pay以外のお支払い方法への変更をご検討ください。",
    # 426 UPGRADE_REQUIRED
    TLS_VERSION_NOT_SUPPORTED => "TLSバージョンがサポートされていません",
    # 429 TOO_MANY_REQUESTS
    TOO_MANY_REQUESTS => "リクエスト数が制限を超えています",
    # 500 INTERNAL_SERVER_ERROR
    INTERNAL_SERVER_ERROR => "サーバー内部エラーが発生しました",
    PROCESSING_FAILURE => "内部処理エラーのため、Amazonでは処理ができませんでした。",
    # 503 SERVICE_UNAVAILABLE
    SERVICE_UNAVAILABLE => "サービスが一時的に利用できません",
  }.freeze
end
