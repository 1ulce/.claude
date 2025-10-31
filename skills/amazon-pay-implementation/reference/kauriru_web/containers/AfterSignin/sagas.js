import { call, put, all, fork, takeLeading } from 'redux-saga/effects';
import * as Sentry from '@sentry/browser';
import { get } from 'lodash/fp';
import history from 'utils/history';
import { vendorPageUrl } from 'utils/location';
import request from 'utils/request';
import { handleGenericError } from 'utils/handleGenericError';
import { switchLocale as switchLocaleAction } from 'containers/Translate/actions';
import { INITIALIZE } from './actionType';
import { initializeSucceed, initializeFailed } from './actions';

const requestLogin = async data => {
  const { loginType, token } = data;
  const cartTokens = window.Cookies.get('rentalCartToken') || null;
  const response = await request('post', 'login', {
    data: { login_type: loginType, token },
    headers: { cartTokens },
  });
  return response;
};

function* handleInitialize(payload) {
  const { vendorName } = payload.data;
  const { state } = history.location;
  try {
    const response = yield call(requestLogin, payload.data);
    const { access_token: accessToken, id, email, locale } = response.data.user;
    localStorage.setItem('userToken', accessToken);
    localStorage.setItem('userId', id);
    localStorage.setItem('email', email);
    Sentry.setUser({ id });
    yield put(switchLocaleAction(locale));
    window.Cookies.remove('confirmationToken');
    window.Cookies.remove('rentalCartToken');
    window.Cookies.remove('getNumberItems');
    window.Cookies.remove('guestLikeItems'); // 未使用になったが、古いcookieが残ってるかもしれないので削除は一応残しておく
    if (get('loginToCheckout')(state)) {
      const checkoutVendorName = JSON.parse(
        localStorage.getItem('orderDetails'),
      )[0].vendor_name;
      history.push(
        `/checkout?vendor=${checkoutVendorName}&step=delivery_address`,
      );
    } else {
      const redirectUrl = localStorage.getItem('redirect_url');
      if (redirectUrl) {
        history.push(redirectUrl);
      } else {
        history.push(vendorName ? vendorPageUrl(vendorName) : '/');
      }
    }
    yield put(initializeSucceed());
  } catch (error) {
    yield put(initializeFailed());
    yield call(handleGenericError, error);
    history.push('/login');
  }
}

function* watchInitialize() {
  yield takeLeading(INITIALIZE, handleInitialize);
}

export default function* watchSaga() {
  yield all([fork(watchInitialize)]);
}
