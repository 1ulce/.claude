import React, { useEffect, useRef } from 'react';
import PropTypes from 'prop-types';
import history from 'utils/history';
import { getAmazonPayConfig } from 'utils/amazonPay/amazonPayScript';
import { initializeSafeContainer } from 'utils/amazonPay/cleanup';

// APB決済、サインインで表示するAmazon Payのボタン
const AmazonPayButton = props => {
  const {
    uniqueButtonId,
    productType,
    amazonData,
    placement,
    configType,
  } = props;
  const refAmazonPayButton = useRef(null);

  useEffect(() => {
    if (!window.amazon?.Pay || !amazonData?.payload || !amazonData?.signature) {
      return;
    }

    initializeSafeContainer(
      refAmazonPayButton.current,
      uniqueButtonId,
      refAmazonPayButton,
    );

    // ボタンを設定するための初期設定
    const amazonPayConfig = getAmazonPayConfig(productType, placement);
    const amazonPayButton = window.amazon.Pay.renderButton(
      `#${uniqueButtonId}`,
      { ...amazonPayConfig },
    );

    // ボタン押下時の処理
    amazonPayButton.onClick(() => {
      if (history.location.pathname === '/checkout/cart') {
        localStorage.setItem('redirect_url', history.location.pathname);
      } else if (history.location.pathname === '/registration') {
        localStorage.setItem('redirect_url', '/checkout/cart');
      }

      window.amazon.Pay.initCheckout({
        ...amazonPayConfig,
        [configType]: {
          payloadJSON: JSON.stringify(amazonData.payload),
          signature: amazonData.signature,
          publicKeyId: window.AmazonPayPublicKeyId,
          algorithm: 'AMZN-PAY-RSASSA-PSS-V2',
        },
      });
    });
  }, [amazonData, uniqueButtonId, placement]);

  return <div ref={refAmazonPayButton} id={uniqueButtonId} />;
};

AmazonPayButton.propTypes = {
  uniqueButtonId: PropTypes.string,
  amazonData: PropTypes.objectOf(PropTypes.any),
  productType: PropTypes.string,
  placement: PropTypes.string,
  configType: PropTypes.string,
};

AmazonPayButton.defaultProps = {
  uniqueButtonId: 'AmazonPayButton',
  amazonData: {},
  productType: 'SignIn',
  placement: 'Other',
  configType: 'signInConfig',
};

export default React.memo(AmazonPayButton);
