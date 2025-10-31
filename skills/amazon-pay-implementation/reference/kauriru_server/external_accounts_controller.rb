module Api::V1
  class ExternalAccountsController < ApiController
    # 現在の連携状況
    def current_integrations
      connected_providers = ExternalAccount.providers.keys.select do |provider|
        current_user.external_accounts.exists?(provider: provider)
      end
      render_json connected_providers
    end

    # マイページからの外部アカウント紐付け
    # 既存ユーザーに外部アカウント（Amazon Pay等）を連携する
    def create
      provider = params[:provider]
      current_user.with_lock do
        case provider
        when "amazon_pay"
          client = ::AmazonPay::Client.new
          response = JSON.parse(client.get_buyer(params[:token]).body)
          buyer_id = response["buyerId"]
          external_account = ExternalAccount.find_by(provider: provider, uid: buyer_id)
          if external_account.present?
            return render_unprocessable_entity("Amazonアカウントが既に他ユーザーに紐づいています。")
          end
          current_user.external_accounts.create!(provider: provider, uid: buyer_id)
          render_json_no_content
        end
      end
    end
  end
end
