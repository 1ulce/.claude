import React, { useState, useEffect } from 'react';
import { isEmpty, get } from 'lodash/fp';
import {
  ToCurrency,
  totalAmount,
  totalOptionPrice,
  originalTotalAmount,
  minSubscriptionAmount,
  maxSubscriptionAmount,
} from 'utils/price';
import formatDateTime, { formats } from 'utils/dateTime';
import PropTypes from 'prop-types';
import Loading from 'components/Loading';
import ErrorModal from 'components/Modal/ErrorModal';
import { useIntl, usePageLocale } from 'containers/Translate/hooks';
import getCartUrl from 'utils/getCartUrl';
import { PAYMENT_TYPE } from 'containers/Checkout/constants';
import { useSelector } from 'react-redux';
import Translate from 'containers/Translate';
import { useConfirm } from 'components/Confirm/hooks';
import queryString from 'query-string';
import { useSelectAmazonPayData } from 'containers/Checkout/selectors';
import CartPlan from './CartPlan';
import CartItem from './CartItem';
import ActiveContract from './ActiveContract';
import Modal from '../Modal';
import Price from '../Price';
import translations from '../translations';

const formatPostalCode = postalCode => {
  return `〒${postalCode.slice(0, 3)}-${postalCode.slice(3)}`;
};

const convDeliveryTime = (text, locale) => {
  if (locale === 'ja') {
    return text;
  }
  // "10時 ～ 12時" => "10:00 ～ 12:00"
  let translateText = text.replace('時', ':00');
  translateText = translateText.replace('時', ':00');
  return translateText;
};

const Verify = props => {
  const {
    history,
    vendorInfo,
    setCheckoutData,
    checkoutData,
    getNumberInventory,
    numberInventory,
    updateItemQuantity,
    createOrder,
    buyItem,
    loading,
    createOrderSuccess,
    isPurchase,
    selectedStore,
    loadingHomeAddress,
    receivingMethod,
    isGuaranteeOption,
    includeTemporaryReservation,
  } = props;
  const intl = useIntl();
  const locale = usePageLocale();
  const { addressData, pickupTime, cartInfo } = checkoutData || {};
  const checkoutSessionId = queryString.parse(history.location.search)
    .amazonCheckoutSessionId;
  const amazonPayData = useSelectAmazonPayData();

  const cartPlan = useSelector(state => state.checkout?.cartPlan);
  const activeContract = useSelector(state => state.checkout?.activeContract);
  const confirm = useConfirm();

  const isStorePickup = receivingMethod === 'pickup_store';
  const [errorMessage, setErrorMessage] = useState('');
  const remarks = pickupTime && pickupTime.remarks;
  const orderDetails = get('orderDetails')(cartInfo);
  const firstOrderDetail = checkoutData?.cartInfo?.orderDetails[0];
  const orderType = firstOrderDetail?.order_type;
  const isCompany = !!checkoutData?.addressData?.companyName;
  const isDisabledPrice =
    get('totalPrice')(checkoutData.cartInfo) > 0 &&
    get('totalPrice')(checkoutData.cartInfo) < 50;

  useEffect(() => {
    if (!isEmpty(checkoutData)) return;

    const pathname = history.location.search.split('step');

    // AmazonPayセッションがない場合は配送先入力画面に遷移
    if (!checkoutSessionId) {
      history.push(`/checkout${pathname[0]}step=delivery_address`);
      return;
    }

    // 店舗受け取りの場合は店舗選択画面に遷移
    if (localStorage.getItem('is_store_pickup') === 'true') {
      history.push(
        `/checkout${
          pathname[0]
        }step=pickup_store&amazonCheckoutSessionId=${checkoutSessionId}`,
      );
      localStorage.removeItem('is_store_pickup');
      return;
    }

    // 配送の場合は受取時間入力画面に遷移
    history.push(
      `/checkout${
        pathname[0]
      }step=pickup_time&amazonCheckoutSessionId=${checkoutSessionId}`,
    );
  }, [checkoutData, checkoutSessionId]);

  /**
   * Amazon Pay変更ボタンのバインド設定
   * - Amazon Payでの決済時に、住所変更・支払方法変更ボタンをバインド
   */
  useEffect(() => {
    // Amazon Payセッションがない場合は処理をスキップ
    if (!checkoutSessionId) return;

    // 決済方法がAmazon Pay以外の場合は処理をスキップ
    if (cartInfo?.paymentType !== PAYMENT_TYPE.AMAZON_PAY) return;

    // Amazon Pay SDKが読み込まれていない場合は処理をスキップ
    if (!window.amazon?.Pay) return;

    // 住所変更ボタン
    window.amazon.Pay.bindChangeAction('#AmazonPayChangeAddress', {
      amazonCheckoutSessionId: checkoutSessionId,
      changeAction: 'changeAddress',
    });

    // 支払方法変更ボタン
    window.amazon.Pay.bindChangeAction('#AmazonPayChangePayment', {
      amazonCheckoutSessionId: checkoutSessionId,
      changeAction: 'changePayment',
    });
  }, [checkoutSessionId, cartInfo?.paymentType]);

  const handleNumberSelect = (e, itemId) => {
    orderDetails.map(order => {
      if (order.id === itemId) {
        Object.assign(order, {
          quantity: Number(e.target.value),
        });
      }
      return order;
    });

    const optionItemIds = orderDetails
      .find(order => order.id === itemId)
      .options.reduce((acc, cur) => [...acc, cur.option_item_id], []);
    updateItemQuantity({
      id: itemId,
      quantity: e.target.value,
      optionItemIds,
    });
    const originalTotal = originalTotalAmount(orderDetails);
    const subTotal = totalAmount(orderDetails);
    const optionTotal = totalOptionPrice(orderDetails);
    const freeShip =
      vendorInfo.min_cost_free_ship !== null &&
      subTotal >= vendorInfo.min_cost_free_ship;
    const shippingCost =
      orderType === 'rental'
        ? vendorInfo.shipping_cost
        : Math.floor(vendorInfo.shipping_cost / 2);
    setCheckoutData({
      ...checkoutData,
      cartInfo: {
        ...checkoutData.cartInfo,
        orderDetails,
        originalTotal,
        subTotal,
        optionTotal,
        shippingCost: freeShip ? 0 : shippingCost,
        totalPrice: freeShip
          ? subTotal + optionTotal
          : subTotal + shippingCost + optionTotal,
      },
    });
  };

  const handleMoverDown = itemId => {
    if (vendorInfo.vendor_type === 'swapable') return;
    getNumberInventory({
      itemId,
      startDate: orderDetails[0].start_date,
      endDate: orderDetails[0].end_date,
      wayToReceive: isStorePickup ? 1 : 0,
      orderType,
    });
  };

  const confirmation = async () => {
    if (createOrderSuccess) {
      setErrorMessage(intl.get(translations.createOrderError.id));
      return;
    }

    // サブスクかつクレカ決済かつ割引がある場合、与信枠確保のために確認ダイアログを表示
    if (
      orderType === 'subscription' &&
      cartInfo.paymentType === PAYMENT_TYPE.CREDIT &&
      cartInfo.hasDiscount
    ) {
      let messageId = null;
      if (cartInfo.totalPrice === 0) {
        messageId = translations.creditCardAuthNoteZero.id;
      } else {
        messageId = translations.creditCardAuthNote.id;
      }
      const confirmResult = await confirm({
        message: messageId,
      });
      if (!confirmResult) {
        return;
      }
    }

    const data = {
      vendor_id: vendorInfo.id,
      address_id: checkoutData.addressData.addressId,
      payment_type: cartInfo.paymentType,
      credit_card_id:
        cartInfo.paymentType === PAYMENT_TYPE.CREDIT
          ? cartInfo.creditCardId
          : null,
      delivery_time: pickupTime.designatedTime,
      notes: pickupTime.remarks || null,
      type: get('[0].type')(orderDetails) || 'Rental',
      way_to_receive: receivingMethod === 'pickup_store' ? 1 : 0,
    };
    if (isStorePickup) {
      data.store_id = selectedStore && selectedStore.id;
    }

    if (isPurchase) {
      data.start_date = checkoutData.pickupTime.receiveDate;
    }
    if (checkoutSessionId) {
      data.checkout_session_id = checkoutSessionId;
    }
    if (isPurchase) {
      buyItem(data, get('[0].item_id')(orderDetails));
    } else {
      createOrder(data, orderDetails, vendorInfo);
    }
  };

  const specifiedTime = time => {
    const deliveryTime =
      get('transport_company.transport_time_range')(vendorInfo) &&
      vendorInfo.transport_company.transport_time_range.includes(time)
        ? time
        : intl.get(translations.noSpecifiedTime.id);
    return deliveryTime;
  };

  const [showModal, setShowModal] = React.useState(false);

  const goToCart = () => {
    history.push(getCartUrl(vendorInfo));
  };

  const handleOnClickChange = () => {
    if (localStorage.getItem('userToken')) {
      goToCart();
    } else {
      setShowModal(true);
    }
  };

  const handleCloseModal = () => {
    setShowModal(false);
  };

  const handlePickupStoreChange = () => {
    const baseUrl = `/checkout?vendor=${vendorInfo.name}&step=pickup_store`;
    const url = checkoutSessionId
      ? `${baseUrl}&amazonCheckoutSessionId=${checkoutSessionId}`
      : baseUrl;
    history.push(url);
  };

  return (
    <div className="row row--16 row-lg--8">
      {loading && loadingHomeAddress && <Loading isFullScreen />}
      <div className="col-lg-7">
        <div className="kr-cart-selection__time kr-cart-verification">
          <h2 className="kr-cart-selection__title mb-4">
            {intl.get(translations.verifyTitle.id)}
          </h2>
          {orderType !== 'swapable' && (
            <div className="kr-cart-verification__item">
              <div className="kr-cart-verification__heading">
                {intl.get(translations.rentalPeriod.id)}
              </div>
              <div className="kr-cart-verification__content">
                <div className="kr-cart-verification__main align-items-end">
                  {orderType === 'rental' ? (
                    <>
                      <div className="kr-cart-verification__detail">
                        <p className="range-date">{`${formatDateTime(
                          get('[0]start_date')(orderDetails),
                          formats.shortDateWithDay,
                        )}~${formatDateTime(
                          get('[0]end_date')(orderDetails),
                          formats.shortDateWithDay,
                        )}`}</p>
                        <p className="come-back">
                          {`${formatDateTime(
                            get('[0]end_date')(orderDetails),
                            formats.shortDateWithDay,
                          )} `}
                          <Translate message="返却日" />
                        </p>
                        <p className="num-days">
                          <Translate
                            message={get('[0]period_rental')(orderDetails)}
                          />
                        </p>
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="kr-cart-verification__detail">
                        <p className="range-date">
                          {`${formatDateTime(
                            get('[0]start_date')(orderDetails),
                            formats.shortDateWithDay,
                          )}`}
                          ~
                        </p>
                        <p className="subscription-period">
                          {intl.get(translations.minSubscriptionPeriod.id)}
                          {'：'}
                          {intl.get(
                            translations.minSubscriptionPeriodMonth.id,
                            {
                              minSubscriptionPeriod:
                                firstOrderDetail?.min_subscription_period,
                            },
                          )}
                          {`（${ToCurrency(
                            minSubscriptionAmount(firstOrderDetail),
                          )}）`}
                          <span className="annotation">
                            <Translate
                              message={`※最低${
                                firstOrderDetail?.min_subscription_period
                              }ヶ月分の月額費用が発生します`}
                            />
                          </span>
                        </p>
                        <p className="subscription-period">
                          {!firstOrderDetail?.max_subscription_period ? (
                            <>
                              {intl.get(translations.maxSubscriptionPeriod.id)}
                              {'：'}
                              {intl.get(translations.noLimit.id)}
                            </>
                          ) : (
                            <>
                              {intl.get(translations.maxSubscriptionPeriod.id)}
                              {'：'}
                              {intl.get(
                                translations.maxSubscriptionPeriodMonth.id,
                                {
                                  maxSubscriptionPeriod:
                                    firstOrderDetail?.max_subscription_period,
                                },
                              )}
                              {`（${ToCurrency(
                                maxSubscriptionAmount(firstOrderDetail),
                              )}）`}
                              <span className="annotation">
                                {firstOrderDetail?.item_subscription_purchase_price ? (
                                  <>
                                    {firstOrderDetail?.item_subscription_residual_value >
                                      0 && (
                                      <Translate
                                        message={`※最大利用期間後はご返却か${ToCurrency(
                                          firstOrderDetail?.item_subscription_residual_value,
                                        )}でそのままご購入か選択できます`}
                                      />
                                    )}
                                    {firstOrderDetail?.item_subscription_residual_value ===
                                      0 && (
                                      <Translate message="※最大利用期間後は、ご返却の必要はございません" />
                                    )}
                                  </>
                                ) : (
                                  <Translate message="※利用期間内でのご返却をお願いします" />
                                )}
                              </span>
                            </>
                          )}
                        </p>
                        <p className="subscription-period mt-2">
                          ・
                          <Translate
                            message={`解約（ご返却）のない場合、${!!firstOrderDetail?.max_subscription_period &&
                              '最大利用期間まで、'}毎月更新日（レンタル開始日の翌月以降の各月の同日、同日のない場合は、その前日）に、レンタル契約は自動更新され、更新日ごとに月額料金が発生します。`}
                          />
                          <br />
                          ・
                          <Translate message="解約（ご返却）手続きはマイページより行えます" />
                        </p>
                      </div>
                    </>
                  )}
                  <div className="kr-cart-verification__button kr-cart-verification__button--time">
                    <button
                      type="button"
                      className="button button--gray button-icon kr-cart-verification__btn"
                      onClick={handleOnClickChange}
                    >
                      <span className="button__icon button__icon--before icon-change" />
                      <span className="button__text">
                        {intl.get(translations.changeButton.id)}
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
          {orderType === 'swapable' && activeContract && (
            <div className="kr-cart-verification__item">
              <div className="kr-cart-verification__heading">
                <Translate message="ご契約内容" />
              </div>
              <div className="kr-cart-verification__content mt-2">
                <ActiveContract contract={activeContract} />
              </div>
            </div>
          )}
          {orderType === 'swapable' && cartPlan && (
            <div className="kr-cart-verification__item">
              <div className="kr-cart-verification__heading">
                <Translate message="ご契約内容" />
              </div>
              <div className="kr-cart-verification__content mt-2">
                <CartPlan cartPlan={cartPlan} />
              </div>
            </div>
          )}
          <div className="kr-cart-verification__item">
            <div className="kr-cart-verification__heading">
              {intl.get(translations.orderDetails.id)}
            </div>
            <div className="kr-cart-verification__content">
              <h3 className="kr-cart__header kr-cart__header--erification">
                <span className="icon-store" />
                <Translate message={get('service_name')(vendorInfo)} />
              </h3>
              {orderDetails &&
                orderDetails.map(cartItem => {
                  return (
                    <CartItem
                      cartItem={cartItem}
                      key={`cart-item-${cartItem.item_id}`}
                      numberInventory={numberInventory}
                      handleNumberSelect={handleNumberSelect}
                      handleMoverDown={handleMoverDown}
                      history={history}
                    />
                  );
                })}
            </div>
          </div>
          <div className="kr-cart-verification__item">
            <div className="kr-cart-verification__heading">
              {intl.get(translations.emailLabel.id)}
            </div>
            <div className="kr-cart-verification__content">
              <div className="kr-cart-verification__detail">
                <p className="email font-weight-bold">{`${get('email')(
                  addressData,
                )}`}</p>
                <p className="kr-cart-selection__des">
                  {intl.get(translations.hintText.id)}
                </p>
              </div>
            </div>
          </div>
          <div className="kr-cart-verification__item">
            <div className="kr-cart-verification__heading">
              {isStorePickup
                ? intl.get(translations.billingHeading.id)
                : intl.get(translations.addressHeading.id)}
            </div>
            <div className="kr-cart-verification__content">
              <div className="kr-cart-verification__main align-items-end">
                <div className="kr-cart-verification__detail">
                  {addressData?.companyName && (
                    <h4 className="kr-cart-verification__title">
                      {addressData?.companyName}
                    </h4>
                  )}
                  <h4 className="kr-cart-verification__title">
                    {locale === 'en'
                      ? `${get('firstName')(addressData)} ${get('lastName')(
                          addressData,
                        )}`
                      : `${get('lastName')(addressData)} ${get('firstName')(
                          addressData,
                        )}`}
                  </h4>
                  {get('nameKana')(addressData) && (
                    <h4 className="kr-cart-verification__title">
                      {`${get('nameKana')(addressData)}`}
                    </h4>
                  )}
                  <p className="address">
                    {locale === 'en' ? (
                      <>
                        {get('buildingNumber')(addressData)}
                        <br />
                        {`${get('address')(addressData)}, ${get(
                          'municipalities',
                        )(addressData)}`}
                        <br />
                        {`${get('prefecture')(addressData)} ${formatPostalCode(
                          addressData.postalCode,
                        )}`}
                      </>
                    ) : (
                      <>
                        {get('postalCode')(addressData) &&
                          formatPostalCode(addressData.postalCode)}
                        <br />
                        {`${get('prefecture')(addressData)}${get(
                          'municipalities',
                        )(addressData)}${get('address')(addressData)}`}
                        <br />
                        {get('buildingNumber')(addressData)}
                      </>
                    )}
                  </p>
                  <p className="phone">{get('phoneNumber')(addressData)}</p>
                </div>
                <div
                  className="kr-cart-verification__button"
                  id={checkoutSessionId ? 'AmazonPayChangeAddress' : undefined}
                >
                  <button
                    type="button"
                    className="button button--gray button-icon kr-cart-verification__btn"
                    onClick={
                      checkoutSessionId
                        ? undefined
                        : () =>
                            history.push(
                              `/checkout?vendor=${
                                vendorInfo.name
                              }&step=delivery_address`,
                            )
                    }
                  >
                    <span className="button__icon button__icon--before icon-change" />
                    <span className="button__text">
                      {intl.get(translations.changeButton.id)}
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>
          <div className="kr-cart-verification__item">
            <div className="kr-cart-verification__heading">
              {intl.get(translations.transportName.id)}
            </div>
            {isStorePickup ? (
              <div className="kr-cart-verification__content">
                <div className="kr-cart-verification__main align-items-end">
                  <div className="kr-cart-verification__detail">
                    <h4 className="kr-cart-verification__title">
                      {intl.get(translations.storePickup.id)}
                    </h4>
                    <p className="date">
                      {
                        <>
                          <Translate
                            message={`${get('receiveDate')(
                              checkoutData.pickupTime,
                            )} 営業時間内`}
                          />
                          <br />
                          <br />
                        </>
                      }
                      <Translate message={selectedStore.name} />
                      <br />
                      <Translate message={selectedStore.address} />
                      <br />
                      {selectedStore.receive_times}
                      <br />
                      {selectedStore.tel}
                    </p>
                  </div>
                  <div className="kr-cart-verification__button">
                    <button
                      type="button"
                      className="button button--gray button-icon kr-cart-verification__btn"
                      onClick={handlePickupStoreChange}
                    >
                      <span className="button__icon button__icon--before icon-change" />
                      <span className="button__text">
                        {intl.get(translations.changeButton.id)}
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            ) : (
              <div className="kr-cart-verification__content">
                <div className="kr-cart-verification__main align-items-center">
                  <div className="kr-cart-verification__detail">
                    <h4 className="kr-cart-verification__title">
                      {intl.get(translations.delivery.id)}
                      <Translate
                        message={get('transportCompany.name')(pickupTime)}
                      />
                    </h4>
                    {orderType !== 'swapable' && (
                      <p className="date">
                        {isPurchase
                          ? `${intl.get(
                              translations.noSpecifiedTimeBuy.id,
                            )} (${convDeliveryTime(
                              specifiedTime(get('designatedTime')(pickupTime)),
                              locale,
                            )})`
                          : `${get('receiveDate')(
                              pickupTime,
                            )} ${convDeliveryTime(
                              specifiedTime(get('designatedTime')(pickupTime)),
                              locale,
                            )}`}
                      </p>
                    )}
                    {orderType === 'swapable' && (
                      <p className="date">
                        {isPurchase
                          ? `${intl.get(
                              translations.noSpecifiedTimeBuy.id,
                            )} (${convDeliveryTime(
                              specifiedTime(get('designatedTime')(pickupTime)),
                              locale,
                            )})`
                          : `${convDeliveryTime(
                              specifiedTime(get('designatedTime')(pickupTime)),
                              locale,
                            )}`}
                      </p>
                    )}
                  </div>
                  <div className="kr-cart-verification__button">
                    <button
                      type="button"
                      className="button button--gray button-icon kr-cart-verification__btn"
                      onClick={() =>
                        history.push(
                          `/checkout?vendor=${
                            vendorInfo.name
                          }&step=pickup_time&amazonCheckoutSessionId=${checkoutSessionId}`,
                        )
                      }
                    >
                      <span className="button__icon button__icon--before icon-change" />
                      <span className="button__text">
                        {intl.get(translations.changeButton.id)}
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
          {remarks && (
            <div className="kr-cart-verification__item">
              <div className="kr-cart-verification__heading">
                {intl.get(translations.remarks.id).slice(0, -1)}
              </div>
              <div className="kr-cart-verification__content">
                <p style={{ whiteSpace: 'pre-wrap', wordWrap: 'break-word' }}>
                  {remarks}
                </p>
              </div>
            </div>
          )}
          {!vendorInfo.rental_zero_option && (
            <div className="kr-cart-verification__item">
              <div className="kr-cart-verification__heading">
                {intl.get(translations.paymentMethod.id)}
              </div>
              <div className="kr-cart-verification__content">
                <div className="kr-cart-verification__main align-items-center">
                  <div className="kr-cart-verification__detail">
                    <h4 className="kr-cart-verification__title mb-0">
                      {
                        <Translate
                          message={
                            (
                              ((vendorInfo.available_payment_types || {})[
                                orderType
                              ] || {})[(cartInfo?.paymentType)] || {}
                            ).name
                          }
                        />
                      }
                    </h4>
                    {cartInfo?.paymentType === PAYMENT_TYPE.CREDIT && (
                      <>
                        <p className="credit mt-2">
                          {`XXXX XXXX XXXX ${get('creditCardLast4')(cartInfo)}`}
                        </p>
                        {orderType === 'subscription' && (
                          <p className="credit mt-2">
                            <Translate message="2ヶ月目以降は毎月更新日に支払われます" />
                          </p>
                        )}
                      </>
                    )}
                    {cartInfo?.paymentType === PAYMENT_TYPE.STORE && (
                      <p className="credit mt-2">
                        {intl.get(translations.storeNote.id)}
                      </p>
                    )}
                    {cartInfo?.paymentType === PAYMENT_TYPE.OTHERS && (
                      <p className="credit mt-2 text-pre-wrap">
                        <Translate
                          message={
                            (
                              ((vendorInfo.available_payment_types || {})[
                                orderType
                              ] || {})[cartInfo.paymentType] || {}
                            ).note
                          }
                        />
                      </p>
                    )}
                    {checkoutSessionId && (
                      <>
                        <p className="credit mt-2">
                          {
                            amazonPayData?.paymentPreferences?.[0]
                              ?.paymentDescriptor
                          }
                        </p>
                        {orderType === 'subscription' && (
                          <p className="credit mt-2">
                            <Translate message="2ヶ月目以降は毎月更新日に支払われます" />
                          </p>
                        )}
                      </>
                    )}
                  </div>
                  <div
                    className="kr-cart-verification__button"
                    id={
                      checkoutSessionId ? 'AmazonPayChangePayment' : undefined
                    }
                  >
                    <button
                      type="button"
                      className="button button--gray button-icon kr-cart-verification__btn"
                      onClick={
                        checkoutSessionId
                          ? undefined
                          : () => {
                              history.push(
                                `/checkout?vendor=${
                                  vendorInfo?.name
                                }&step=payment`,
                              );
                            }
                      }
                    >
                      <span className="button__icon button__icon--before icon-change" />
                      <span className="button__text">
                        {intl.get(translations.changeButton.id)}
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
      <Price
        history={history}
        goToNextStep={confirmation}
        step="last_verification"
        originalTotal={get('originalTotal')(checkoutData.cartInfo) || 0}
        subTotal={get('subTotal')(checkoutData.cartInfo) || 0}
        checkoutData={checkoutData}
        shippingCost={get('shippingCost')(checkoutData.cartInfo)}
        minCost={vendorInfo.min_cost_free_ship}
        isStorePickup={isStorePickup}
        disabled={isDisabledPrice || loading}
        vendorInfo={vendorInfo}
        orderType={orderType}
        isGuaranteeOption={isGuaranteeOption}
        isCompany={isCompany}
        optionTotal={get('optionTotal')(checkoutData.cartInfo) || 0}
        hasOption={get('hasOption')(checkoutData.cartInfo)}
        hasDiscount={get('hasDiscount')(checkoutData.cartInfo)}
        minSubscriptionPeriod={get('minSubscriptionPeriod')(
          checkoutData.cartInfo,
        )}
        includeTemporaryReservation={includeTemporaryReservation}
      />
      <Modal
        showModal={showModal}
        handleClose={handleCloseModal}
        goToNewPage={goToCart}
      />
      <ErrorModal
        errorMessage={errorMessage}
        setErrorMessage={setErrorMessage}
      />
    </div>
  );
};

Verify.propTypes = {
  history: PropTypes.objectOf(PropTypes.any).isRequired,
  vendorInfo: PropTypes.objectOf(PropTypes.any).isRequired,
  setCheckoutData: PropTypes.func,
  checkoutData: PropTypes.objectOf(PropTypes.any),
  getNumberInventory: PropTypes.func,
  numberInventory: PropTypes.objectOf(PropTypes.any),
  updateItemQuantity: PropTypes.func,
  createOrder: PropTypes.func,
  loading: PropTypes.bool,
  buyItem: PropTypes.func,
  createOrderSuccess: PropTypes.bool,
  selectedStore: PropTypes.shape({
    address: PropTypes.string.isRequired,
    id: PropTypes.number.isRequired,
    name: PropTypes.string.isRequired,
    receive_times: PropTypes.string.isRequired,
    tel: PropTypes.string.isRequired,
  }),
  loadingHomeAddress: PropTypes.bool,
  isPurchase: PropTypes.bool.isRequired,
  receivingMethod: PropTypes.oneOf(['shipping', 'pickup_store']),
  isGuaranteeOption: PropTypes.bool,
  includeTemporaryReservation: PropTypes.bool,
};

Verify.defaultProps = {
  setCheckoutData: () => {},
  checkoutData: {},
  getNumberInventory: () => {},
  numberInventory: {},
  updateItemQuantity: () => {},
  createOrder: () => {},
  loading: false,
  buyItem: () => {},
  createOrderSuccess: false,
  selectedStore: null,
  loadingHomeAddress: false,
  receivingMethod: null,
  isGuaranteeOption: false,
  includeTemporaryReservation: false,
};

export default React.memo(Verify);
