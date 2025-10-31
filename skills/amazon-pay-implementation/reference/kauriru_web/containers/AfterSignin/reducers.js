import {
  INITIALIZE,
  INITIALIZE_SUCCEED,
  INITIALIZE_FAILED,
  SET_LOADING,
} from './actionType';

export const initialState = {
  loading: true,
  error: {},
};

const afterSigninReducer = (state = initialState, action) => {
  let draft;
  switch (action.type) {
    case INITIALIZE: {
      draft = {
        ...initialState,
      };
      break;
    }
    case INITIALIZE_SUCCEED: {
      draft = {
        ...state,
        loading: false,
      };
      break;
    }
    case INITIALIZE_FAILED: {
      draft = {
        ...state,
        loading: false,
      };
      break;
    }
    case SET_LOADING: {
      draft = {
        ...state,
        loading: action.payload.loading,
      };
      break;
    }
    default:
      draft = state;
      break;
  }
  return draft;
};

export default afterSigninReducer;
