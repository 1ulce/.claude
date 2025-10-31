import React, { useState, useEffect } from 'react';
import { isEmpty, get } from 'lodash/fp';
import formatDateTime, { formats } from 'utils/dateTime';
import PropTypes from 'prop-types';
import { useIntl, usePageLocale } from 'containers/Translate/hooks';
import { PAYMENT_TYPE } from 'containers/Checkout/constants';
import Translate from 'containers/Translate';
import { totalOptionPrice } from 'utils/price';
import calculateOrder from 'utils/calculateOrder';
import queryString from 'query-string';
import convertAmazonPayAddress from 'utils/amazonPay/convertAmazonPayAddress';
import {
  useSelectAmazonPayData,
  useSelectError,
} from 'containers/Checkout/selectors';
import ErrorModal from 'components/AmazonPayButton/ErrorModal';
import Price from '../Price';
import translations from './translations';

const PickupStore = props => {
  const {
    history,
    vendorInfo,
    setCheckoutData,
    checkoutData,
    selectedPrefecture,
    setSelectedPrefecture,
    selectedStore,
    setSelectedStore,
    orderDetails,
    receivingMethod,
    createAddress,
    createSuccess,
    addressInfo,
    cartToken,
    originalTotal,
    subTotal,
    createGardia,
    createSubsCield,
    isGuaranteeOption,
  } = props;
  const intl = useIntl();
  const locale = usePageLocale();
  const [errorMessage, setErrorMessage] = useState(null);
  const error = useSelectError();

  const isCompany = !!checkoutData.addressData?.companyName;
  // Amazon Pay関連
  const checkoutSessionId = queryString.parse(history.location.search)
    .amazonCheckoutSessionId;
  const amazonPayData = useSelectAmazonPayData();
  const { shippingAddress } = amazonPayData;
  const [amazonPayStatus, setAmazonPayStatus] = useState('pending');

  if (isEmpty(checkoutData) && !checkoutSessionId) {
    const pathname = history.location.search.split('step');
    history.push(`/checkout${pathname[0]}step=delivery_address`);
    return null;
  }

  const orderType = orderDetails[0] && orderDetails[0].order_type;
  const isStorePickup = receivingMethod === 'pickup_store';
  const [pickupTime, setPickupTime] = useState({
    designatedTime: get('designatedTime')(checkoutData.pickupTime) || null,
    remarks: get('remarks')(checkoutData.pickupTime) || '',
  });
  const originalStores = (orderDetails[0] && orderDetails[0].stores) || [];
  const availablePrefectures = originalStores.reduce((acc, cur) => {
    const includedPrefecture = acc.some(
      prefecture => prefecture.id === cur.prefecture.id,
    );
    return !includedPrefecture ? [...acc, cur.prefecture] : acc;
  }, []);

  const [availableStores, setAvailableStores] = useState([...originalStores]);

  const isSingleStoreAvailable = availableStores.length === 1;

  useEffect(() => {
    if (error && error.data) {
      const { message } = error.data;
      setErrorMessage(message);
    }
  }, [error]);

  useEffect(() => {
    if (isSingleStoreAvailable) {
      setSelectedStore(availableStores[0]);
    }
  }, []);

  /**
   * Amazon Pay住所データをカウリルの住所データに変換
   */
  useEffect(() => {
    // Amazon Payセッションが無効または取得データが不十分な場合は処理をスキップ
    if (!checkoutSessionId || Object.keys(amazonPayData).length === 0) {
      return;
    }

    const processAmazonPayAddressData = async () => {
      try {
        const email = localStorage ? localStorage.getItem('email') : null;
        const newAddressData = await convertAmazonPayAddress({
          shippingAddress,
          email,
        });

        setCheckoutData({
          ...checkoutData,
          addressData: newAddressData,
        });
        setAmazonPayStatus('ready');
      } catch (amazonPayError) {
        // eslint-disable-next-line no-console
        console.error(
          'Amazon Pay 住所データ処理に失敗しました:',
          amazonPayError,
        );
        setErrorMessage(amazonPayError.message);
        setAmazonPayStatus('error');
      }
    };

    processAmazonPayAddressData();
  }, [checkoutSessionId, amazonPayData]);

  /**
   * Amazon Payデータ処理完了後、住所作成APIを呼び出し
   */
  useEffect(() => {
    // Amazon Payセッションが無効の場合は処理をスキップ
    if (!checkoutSessionId) return;

    // Amazon Pay住所/姓名分割処理が完了していない場合は処理をスキップ
    if (amazonPayStatus !== 'ready') return;

    createAddress(checkoutData.addressData);
  }, [checkoutSessionId, amazonPayStatus]);

  useEffect(() => {
    // Amazon Payセッションが無効の場合は処理をスキップ
    if (!checkoutSessionId) return;

    // 住所作成が成功していない場合は処理をスキップ
    if (!createSuccess) return;

    // 注文詳細データが存在しない場合は処理をスキップ
    if (orderDetails.length === 0) {
      return;
    }

    // app/components/Checkout/Address/index.jsxと同じ計算
    const optionTotal = totalOptionPrice(orderDetails);
    const hasOption = !!orderDetails.reduce(
      (acc, cur) => acc + cur.options.length,
      0,
    );

    const orderPrice = calculateOrder({
      vendorInfo,
      subTotal,
      isStorePickup: false,
      orderType,
      optionTotal,
    });

    setCheckoutData({
      ...checkoutData,
      cartInfo: {
        cartToken,
        orderDetails,
        originalTotal,
        subTotal,
        optionTotal,
        hasOption,
        totalPrice: orderPrice.totalPrice,
        shippingCost: orderPrice.shippingCost,
        vendorId: vendorInfo.id,
        hasDiscount: orderDetails[0].discount_amount > 0,
        minSubscriptionPeriod: orderDetails[0].min_subscription_period,
        paymentType: PAYMENT_TYPE.AMAZON_PAY,
      },
      pickupTime: {
        ...checkoutData.pickupTime,
        receiveDate: orderDetails[0] && orderDetails[0].start_date,
        returnDate: orderDetails[0] && orderDetails[0].end_date,
      },
      addressData: {
        ...checkoutData.addressData,
        addressId: addressInfo?.id,
      },
    });
  }, [
    originalTotal,
    subTotal,
    orderDetails,
    vendorInfo,
    checkoutSessionId,
    createSuccess,
  ]);

  useEffect(() => {
    if (createSuccess) {
      if (!isCompany && locale === 'ja') {
        createSubsCield(checkoutData.addressData);
        if (isGuaranteeOption) {
          createGardia(checkoutData.addressData);
        }
      }
    }
  }, [createSuccess]);

  const handleOnChangePrefecture = e => {
    const { value } = e.target;
    if (value === 'unselect') {
      setSelectedPrefecture(null);
      setAvailableStores(originalStores);
      setSelectedStore(null);
    } else {
      const prefecture = JSON.parse(value);
      const filteredStores = originalStores.filter(
        store => store.prefecture.id === prefecture.id,
      );
      setSelectedPrefecture(prefecture);
      setAvailableStores(filteredStores);
      setSelectedStore(filteredStores.length === 1 ? filteredStores[0] : null);
    }
  };

  const handleOnChangeStore = e => {
    const { value } = e.target;
    if (value === 'unselect') {
      setSelectedStore(null);
    } else {
      setSelectedStore(JSON.parse(value));
    }
  };

  const handleInputChange = e => {
    const { name, value } = e.target;
    setPickupTime({
      ...pickupTime,
      [name]: value,
    });
  };

  if (isEmpty(checkoutData) && !checkoutSessionId) {
    const pathname = history.location.search.split('step');
    history.push(`/checkout${pathname[0]}step=delivery_address`);
  }

  const goToNextStep = () => {
    setCheckoutData({
      ...checkoutData,
      store_id: selectedStore.id,
      pickupTime: {
        ...checkoutData.pickupTime,
        remarks: pickupTime.remarks,
      },
    });
    const step =
      vendorInfo.rental_zero_option || checkoutSessionId
        ? 'last_verification'
        : 'payment';

    if (checkoutSessionId) {
      history.push(
        `/checkout?vendor=${
          vendorInfo.name
        }&step=${step}&amazonCheckoutSessionId=${checkoutSessionId}`,
      );
      localStorage.setItem('is_store_pickup', true);
    } else {
      history.push(`/checkout?vendor=${vendorInfo.name}&step=${step}`);
    }
  };

  return (
    <>
      <div className="row row--16 row-lg--8">
        <div className="col-lg-7">
          <div className="kr-cart-selection__time">
            <h2 className="kr-cart-selection__title">
              {intl.get(translations.pickupStoreTitle.id)}
            </h2>
            <div className="mb-4 pb-2">
              <label className="kr-cart-selection__time-label">
                {intl.get(translations.pickupStoreWayToReceive.id)}
              </label>
              {availablePrefectures.length > 1 && originalStores.length > 10 && (
                <div className="kr-cart-selection__timein-choice input-selectbox-custom mt-2 mb-3">
                  <label className="select-box-label">
                    <Translate message="都道府県" />：
                  </label>
                  <div className="select-box">
                    <select
                      className="custom-select"
                      defaultValue={
                        JSON.stringify(selectedPrefecture) || 'unselect'
                      }
                      onChange={handleOnChangePrefecture}
                    >
                      <option value="unselect">
                        {intl.get(translations.select.id)}
                      </option>
                      {availablePrefectures &&
                        availablePrefectures.map(prefecture => (
                          <option
                            key={prefecture.id}
                            value={JSON.stringify(prefecture)}
                          >
                            {prefecture.name}
                          </option>
                        ))}
                    </select>
                  </div>
                </div>
              )}
              {(!!selectedStore ||
                !!selectedPrefecture ||
                originalStores.length < 11) && (
                <div className="kr-cart-selection__timein-choice input-selectbox-custom mt-2">
                  <label className="select-box-label">
                    <Translate message="受取店舗" />：
                  </label>
                  <div className="select-box">
                    <select
                      className="custom-select"
                      defaultValue={JSON.stringify(selectedStore) || 'unselect'}
                      onChange={handleOnChangeStore}
                      disabled={isSingleStoreAvailable}
                    >
                      {!isSingleStoreAvailable && (
                        <option value="unselect">
                          {intl.get(translations.select.id)}
                        </option>
                      )}
                      {availableStores &&
                        availableStores.map(store => (
                          <option key={store.id} value={JSON.stringify(store)}>
                            {store.name}
                          </option>
                        ))}
                    </select>
                  </div>
                </div>
              )}
              {selectedStore && (
                <div className="kr-cart-selection__store mt-3">
                  <p className="kr-cart-selection__time-value font-weight-bold">
                    <Translate message={selectedStore.name} />
                  </p>
                  <p className="kr-cart-selection__time-value">
                    {selectedStore.address}
                  </p>
                  {selectedStore.tel !== '' && (
                    <p className="kr-cart-selection__time-value">
                      {selectedStore.tel}
                    </p>
                  )}
                  {selectedStore.receive_times !== '' && (
                    <p className="kr-cart-selection__time-value receive-times">
                      {selectedStore.receive_times}
                    </p>
                  )}
                </div>
              )}
            </div>
            <div className="kr-cart-selection__timein">
              <div className="kr-cart-selection__timein-heading">
                <span className="kr-cart-selection__timein-icon icon-package-in" />
                <span className="kr-cart-selection__timein-text">
                  {intl.get(translations.receiveDate.id)}
                </span>
              </div>
              <div className="kr-cart-selection__timein-detail">
                <div className="kr-cart-selection__timein-date">
                  <span className="time">
                    {formatDateTime(
                      get('receiveDate')(checkoutData.pickupTime),
                      formats.shortDateWithoutDay,
                    )}
                  </span>
                  <span className="days">
                    {formatDateTime(
                      get('receiveDate')(checkoutData.pickupTime),
                      formats.shortDay,
                    )}
                  </span>
                </div>
                <p className="kr-cart-selection__timeout-hours">
                  {intl.get(translations.businessHours.id)}
                </p>
              </div>
            </div>
            {orderType === 'rental' && (
              <div className="kr-cart-selection__timeout">
                <div className="kr-cart-selection__timeout-heading">
                  <span className="kr-cart-selection__timeout-icon icon-package-out" />
                  <span className="kr-cart-selection__timeout-text">
                    {intl.get(translations.returnDate.id)}
                  </span>
                </div>
                <div className="kr-cart-selection__timeout-detail">
                  <div className="kr-cart-selection__timeout-date">
                    <span className="time">
                      {formatDateTime(
                        get('returnDate')(checkoutData.pickupTime),
                        formats.shortDateWithoutDay,
                      )}
                    </span>
                    <span className="days">
                      {formatDateTime(
                        get('returnDate')(checkoutData.pickupTime),
                        formats.shortDay,
                      )}
                    </span>
                  </div>
                  <p className="kr-cart-selection__timeout-hours">
                    {intl.get(translations.businessHours.id)}
                  </p>
                </div>
              </div>
            )}
            <div className="form-group form-customize">
              <label className="input-label">
                {intl.get(translations.remarks.id)}
              </label>
              <div className="input-field">
                <textarea
                  className="form-control"
                  type="text"
                  name="remarks"
                  row={5}
                  placeholder={intl.get(translations.remarksPlaceholder.id)}
                  value={pickupTime.remarks}
                  onChange={handleInputChange}
                />
              </div>
            </div>
          </div>
        </div>
        <Price
          history={history}
          goToNextStep={goToNextStep}
          shippingCost={vendorInfo.shipping_cost}
          minCost={vendorInfo.min_cost_free_ship}
          originalTotal={get('originalTotal')(checkoutData.cartInfo) || 0}
          subTotal={get('subTotal')(checkoutData.cartInfo) || 0}
          totalPrice={get('totalPrice')(checkoutData.cartInfo) || 0}
          isStorePickup={isStorePickup}
          disabled={!selectedStore}
          vendorInfo={vendorInfo}
          orderType={orderType}
          optionTotal={get('optionTotal')(checkoutData.cartInfo) || 0}
          hasOption={get('hasOption')(checkoutData.cartInfo)}
          hasDiscount={get('hasDiscount')(checkoutData.cartInfo)}
          minSubscriptionPeriod={get('minSubscriptionPeriod')(
            checkoutData.cartInfo,
          )}
          hideOnMobile={true}
        />
      </div>
      <ErrorModal
        errorMessage={errorMessage}
        setErrorMessage={setErrorMessage}
      />
    </>
  );
};

PickupStore.propTypes = {
  history: PropTypes.objectOf(PropTypes.any).isRequired,
  vendorInfo: PropTypes.objectOf(PropTypes.any).isRequired,
  setCheckoutData: PropTypes.func,
  checkoutData: PropTypes.objectOf(PropTypes.any),
  setSelectedPrefecture: PropTypes.func.isRequired,
  selectedPrefecture: PropTypes.shape({
    id: PropTypes.number,
    name: PropTypes.string,
  }),
  setSelectedStore: PropTypes.func.isRequired,
  selectedStore: PropTypes.shape({
    address: PropTypes.string.isRequired,
    id: PropTypes.number.isRequired,
    name: PropTypes.string.isRequired,
    receive_times: PropTypes.string.isRequired,
    tel: PropTypes.string.isRequired,
  }),
  orderDetails: PropTypes.arrayOf(PropTypes.any),
  receivingMethod: PropTypes.oneOf(['shipping', 'pickup_store']),
  createAddress: PropTypes.func,
  createSuccess: PropTypes.bool,
  addressInfo: PropTypes.objectOf(PropTypes.any),
  cartToken: PropTypes.string,
  originalTotal: PropTypes.number,
  subTotal: PropTypes.number,
  createGardia: PropTypes.func,
  createSubsCield: PropTypes.func,
  isGuaranteeOption: PropTypes.bool,
};

PickupStore.defaultProps = {
  setCheckoutData: () => {},
  checkoutData: {},
  selectedPrefecture: null,
  selectedStore: null,
  orderDetails: [],
  receivingMethod: null,
  createAddress: () => {},
  createSuccess: false,
  addressInfo: {},
  cartToken: '',
  originalTotal: 0,
  subTotal: 0,
  createGardia: () => {},
  createSubsCield: () => {},
  isGuaranteeOption: false,
};

export default React.memo(PickupStore);
