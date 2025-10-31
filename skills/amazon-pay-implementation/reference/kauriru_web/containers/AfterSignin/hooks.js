import { useEffect } from 'react';
import { useDispatch } from 'react-redux';
import { initialize } from './actions';

export const useInitialize = payload => {
  const dispatch = useDispatch();
  useEffect(() => {
    dispatch(initialize(payload));
  }, []);
};
