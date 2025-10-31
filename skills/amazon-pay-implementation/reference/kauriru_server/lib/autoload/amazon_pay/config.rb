# frozen_string_literal: true

module AmazonPay
  # Amazon Pay APIの設定を管理するクラス
  #
  # API接続に必要な認証情報やリージョン設定を一元管理し、
  # Amazon Pay SDKで使用可能な形式での設定提供を行う
  class Config
    attr_reader :region, :public_key_id, :private_key, :sandbox, :store_id, :max_retries

    # 設定の初期化
    #
    # Rails設定およびcredentialsから必要な情報を取得し、
    # 環境に応じてサンドボックスモードを設定する
    def initialize
      @region = 'jp'
      @public_key_id = Settings.amazon_pay.public_key_id
      @private_key = Rails.application.credentials.dig(Rails.env.to_sym, :amazon_pay, :private_key)
      @sandbox = !Rails.env.production?
      @store_id = Settings.amazon_pay.store_id
      @max_retries = 3
    end

    # Amazon Pay SDK用の設定ハッシュを生成
    #
    # SDKの初期化に必要な基本設定項目のみを含むハッシュを返す
    #
    # @return [Hash] SDK設定ハッシュ
    def to_sdk_config
      {
        region: region,
        public_key_id: public_key_id,
        private_key: private_key,
        sandbox: sandbox
      }
    end

    # デフォルト設定インスタンスを作成
    #
    # @return [AmazonPay::Config] 新しい設定インスタンス
    def self.default
      new
    end
  end
end
