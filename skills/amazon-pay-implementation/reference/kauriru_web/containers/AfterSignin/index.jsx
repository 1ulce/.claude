import React from 'react';
import { useLocation } from 'react-router-dom';
import injectReducer from 'utils/injectReducer';
import injectSaga from 'utils/injectSaga';
import { compose } from 'redux';
import Loading from 'components/Loading';
import { useInitialize } from './hooks';
import { useSelectLoading } from './selectors';
import reducer from './reducers';
import saga from './sagas';

const AfterSignin = () => {
  // URLからクエリパラメータを取得
  const location = useLocation();
  const loading = useSelectLoading();
  const searchParams = new URLSearchParams(location.search);
  const token = searchParams.get('buyerToken');
  const vendor = searchParams.get('vendor');
  const loginType = searchParams.get('loginType');

  const payload = {
    loginType,
    token,
    vendorName: vendor,
  };
  useInitialize(payload);

  return loading && <Loading isFullScreen />;
};

export default compose(
  injectReducer({ key: 'afterSignin', reducer }),
  injectSaga({ key: 'afterSignin', saga }),
)(AfterSignin);
