import { useSelector } from 'react-redux';

const selectGlobal = state => state.afterSignin;

export const selectLoading = state => selectGlobal(state)?.loading;
export const useSelectLoading = () => {
  return useSelector(selectLoading);
};

export const selectAfterSignin = state => selectGlobal(state)?.afterSignin;
export const useSelectAfterSignin = () => {
  return useSelector(selectAfterSignin);
};

export const selectError = state => selectGlobal(state)?.error;
export const useSelectError = () => {
  return useSelector(selectError);
};
