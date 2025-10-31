class PaymentGateway

  def initialize(gateway)
    @name = gateway&.to_sym
    case @name
    when :payjp
      @proxy_class = PaymentGateway::Payjp
    when :gmo_fincode
      @proxy_class = PaymentGateway::Fincode
    when :amazon_pay
      @proxy_class = PaymentGateway::AmazonPay
    else
      raise ArgumentError, "Unsupported gateway: #{gateway}"
    end
  end

  # ゲートウェイの名前を返す
  attr_reader :name

  # 決済関連の処理を行うクラスを返す
  def charge
    @proxy_class::ChargeProxy
  end

  # このクラスに定義されていないメソッドは @proxy_class に委譲する
  def method_missing(method, *args, &block)
    @proxy_class.send(method, *args, &block)
  end
end
