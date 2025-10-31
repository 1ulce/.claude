# frozen_string_literal: true

##
# Amazon Pay API のHTTPエラーレスポンスを表すエラークラス
#
# HTTPステータスコードとレスポンス内容を元に、
# 詳細なエラー情報を提供し、再試行可能性を判定する
#
class AmazonPay::HttpStatusError < AmazonPay::Error
  attr_reader :status, :method, :reason_code

  ##
  # HttpStatusErrorを初期化する
  #
  # @param status [Integer] HTTPステータスコード
  # @param method [String, nil] HTTPメソッド（GET, POST等）
  # @param response_body [String, nil] APIレスポンスのボディ（JSON文字列）
  # @param reason_code [String, nil] エラーの理由コード（手動指定時）
  def initialize(status, method: nil, response_body: nil, reason_code: nil)
    @status = status
    @method = method
    @response_body = response_body
    @reason_code = reason_code || extract_reason_code(response_body)

    message = build_error_message
    super(message)
  end

  ##
  # エラーが再試行可能かどうかを判定する
  #
  # 一時的なエラー（レート制限、サーバーエラー等）の場合は再試行可能と判定
  #
  # @return [Boolean] 再試行可能な場合はtrue
  def retry_able?
    # HTTPステータスコードで再試行可能かチェック（429, 500, 503）
    [429, 500, 503].include?(@status)
  end

  ##
  # エラーコードとメッセージの組み合わせを取得する
  #
  # reason_codeがある場合は対応するメッセージを返し、
  # ない場合はHTTPステータスコードベースのメッセージを返す
  #
  # @return [String] エラーコードとメッセージの組み合わせ
  def error_code_message
    if @reason_code
      reason_message = fetch_reason_message(@reason_code)
      if reason_message
        return "#{@reason_code} : #{reason_message}"
      end
    end

    # reason_codeがない場合やメッセージが見つからない場合
    "HTTP_#{@status} : HTTPステータス: #{@status}"
  end

  private

  ##
  # レスポンスボディからreason_codeを抽出する
  #
  # @param response_body [String, nil] APIレスポンスのボディ（JSON文字列）
  # @return [String, nil] 抽出されたreason_code、取得できない場合はnil
  def extract_reason_code(response_body)
    return nil unless response_body.is_a?(String)

    begin
      data = JSON.parse(response_body)
      @api_message = data['message'] # APIから返されるメッセージも保存
      data['reasonCode']
    rescue JSON::ParserError
      nil
    end
  end

  ##
  # reason_codeに対応するエラーメッセージを取得する
  #
  # @param reason_code [String] エラーの理由コード
  # @return [String, nil] 対応するメッセージ、見つからない場合はnil
  def fetch_reason_message(reason_code)
    # 共通エラーコードをチェック
    if defined?(AmazonPay::Consts::ErrorCode::ERROR_MESSAGES)
      message = AmazonPay::Consts::ErrorCode::ERROR_MESSAGES[reason_code]
      return message if message
    end

    nil
  end

  ##
  # エラーメッセージを構築する
  #
  # エラーコードメッセージとAPIメッセージを組み合わせて
  # 詳細なエラーメッセージを作成する
  #
  # @return [String] 構築されたエラーメッセージ
  def build_error_message
    message = error_code_message

    # API Messageは改行して表示
    if @api_message
      message += "\nAPI Message: #{@api_message}"
    end

    message
  end
end
