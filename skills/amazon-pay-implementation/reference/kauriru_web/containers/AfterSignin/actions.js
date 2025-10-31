import {
  INITIALIZE,
  INITIALIZE_SUCCEED,
  INITIALIZE_FAILED,
  SET_LOADING,
} from './actionType';

export const initialize = data => ({
  type: INITIALIZE,
  data,
});

export const initializeSucceed = () => ({
  type: INITIALIZE_SUCCEED,
});

export const initializeFailed = () => ({
  type: INITIALIZE_FAILED,
});

export const setLoading = loading => ({
  type: SET_LOADING,
  payload: {
    loading,
  },
});
