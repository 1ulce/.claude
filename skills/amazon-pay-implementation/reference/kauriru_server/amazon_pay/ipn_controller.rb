require 'securerandom'

# Amazon Pay IPN（Instant Payment Notification）処理コントローラ
#
# Amazon Payからの非同期通知を受信し、返金処理の状態変更を処理する
# IPN通知により、Amazon Pay側での返金処理の完了や拒否を検知する
# @see https://developer.amazon.com/ja/docs/amazon-pay-checkout/set-up-instant-payment-notifications.html#refund
# @see https://developer.amazon.com/ja/docs/amazon-pay-checkout/asynchronous-processing.html
class Api::V1::AmazonPay::IpnController < Api::V1::ApiController

  # 返金処理のIPN通知を処理
  #
  # Amazon Payから送信されるIPN通知を受信し、
  # AmazonPayChargeレコードの状態を更新する
  #
  # 処理フロー:
  # 1. IPN通知の内容を解析
  # 2. 返金関連の通知のみを処理（他の通知は無視）
  # 3. 対象のAmazonPayChargeレコードを特定
  # 4. Amazon Pay APIから最新の返金状態を取得
  # 5. 状態に応じてレコードのステータスを更新
  def update_status
    ipn_content = request.body.read
    ipn_data = JSON.parse(ipn_content)
    @message_data = JSON.parse(ipn_data["Message"])
    object_type = @message_data["ObjectType"]

    # AmazonPay側の返金は全て非同期となるため、返金状況のみ検知する
    return head :ok unless object_type == "REFUND"

    begin
      # AmazonPay請求情報を取得
      @refund_id = @message_data["ObjectId"]
      charge_permission_id = @message_data["ChargePermissionId"]

      @amazon_pay_charge = AmazonPayCharge.find_by(charge_permission_id: charge_permission_id, refund_id: @refund_id)
      if @amazon_pay_charge.blank?
        raise ::AmazonPay::Error, "対象のAmazonPay請求情報が見つかりません。"
      end

      Tasks::AmazonPay::UpdateStatusCommand.run!(amazon_pay_charge: @amazon_pay_charge)

      head :ok
    rescue => e
      message = "【AmazonPay IPN】 返金処理に失敗しました。"
      message << " message_data: #{@message_data}"
      message << " refund_id: #{@refund_id}"
      message << " error: #{e.message}"
      Sentry.capture_message(message)
      Sentry.capture_exception(e)
      SlackNotificationsWorker.perform_async(message)
      head :ok
    end
  end

  private

  def get_refund_state
    client = AmazonPay.client
    response = client.get_refund(@refund_id)
    refund_data = JSON.parse(response.body)
    @refund_state = refund_data.dig("statusDetails", "state")
    @refund_state
  rescue => e
    raise ::AmazonPay::Error, "返金ステータス取得失敗。error: #{e.message}"
  end

  def send_slack(message)
    message = "【AmazonPay IPN】 #{message}"
    message << " 注文ID: #{@amazon_pay_charge.order_id}"
    message << " 返金ID: #{@refund_id}"
    message << " ステータス: #{@refund_state}"
    SlackNotificationsWorker.perform_async(message)
  end
end
