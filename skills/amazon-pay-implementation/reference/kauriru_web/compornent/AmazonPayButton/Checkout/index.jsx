import React, { useEffect, useRef } from 'react';
import PropTypes from 'prop-types';
import { getAmazonPayConfig } from 'utils/amazonPay/amazonPayScript';
import { initializeSafeContainer } from 'utils/amazonPay/cleanup';

const AmazonPayCheckoutButton = props => {
  const { uniqueButtonId, items, isStorePickup } = props;
  const refAmazonPayButton = useRef(null);

  // ベンダー名
  const vendorName = items[0]?.vendor_name;

  // 注文タイプ
  const orderType = items[0]?.order_type;

  useEffect(() => {
    if (!window.amazon?.Pay) return;

    initializeSafeContainer(
      refAmazonPayButton.current,
      uniqueButtonId,
      refAmazonPayButton,
    );

    const amazonPayConfig = getAmazonPayConfig('PayAndShip', 'Cart');
    window.amazon.Pay.renderButton(`#${uniqueButtonId}`, {
      ...amazonPayConfig,
      createCheckoutSession: {
        url: `${
          window.APIEndpointBaseURL
        }/amazon_pay/checkout_sessions?vendor=${vendorName}&order_type=${orderType}&is_store_pickup=${isStorePickup}`,
      },
    });
  }, [uniqueButtonId, vendorName, orderType, isStorePickup]);

  return <div ref={refAmazonPayButton} id={uniqueButtonId} />;
};

AmazonPayCheckoutButton.propTypes = {
  uniqueButtonId: PropTypes.string,
  items: PropTypes.arrayOf(PropTypes.object),
  isStorePickup: PropTypes.bool,
};

AmazonPayCheckoutButton.defaultProps = {
  uniqueButtonId: 'AmazonPayButton',
  items: [],
  isStorePickup: false,
};

export default AmazonPayCheckoutButton;
