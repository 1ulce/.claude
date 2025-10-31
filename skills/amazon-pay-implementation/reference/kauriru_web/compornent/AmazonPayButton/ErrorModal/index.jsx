import React from 'react';
import PropTypes from 'prop-types';
import Modal from 'react-bootstrap/Modal';
import history from 'utils/history';
import { useIntl } from 'containers/Translate/hooks';
import translations from './translations';

// AmazonPayの住所が無効な場合、カスタムエラーメッセージを表示
const FIELDS = [
  {
    name: '郵便番号',
    keywords: ['郵便番号'],
    reason: '7桁でない、半角数字以外の文字を使用',
  },
  {
    name: '都道府県',
    keywords: ['都道府県'],
    reason: '正しい都道府県名でない、英語表記になっている',
  },
  {
    name: '市区町村',
    keywords: ['市区町村'],
    reason: '未入力、日本語以外の文字、文字数超過',
  },
  {
    name: '番地・建物名',
    keywords: ['番地・建物名', '番地'],
    reason: '未入力または文字数超過',
  },
  { name: '姓', keywords: ['姓'], reason: '未入力または文字数超過' },
  {
    name: '名',
    keywords: ['名を入力', '名'],
    reason: '未入力または文字数超過',
  },
  {
    name: '電話番号',
    keywords: ['電話', 'phone'],
    reason: '未入力、10-11桁でない、数字以外の文字を使用',
  },
  {
    name: 'メールアドレス',
    keywords: ['メール', 'email'],
    reason: '正しいメール形式でない',
  },
];

const ErrorModal = props => {
  const intl = useIntl();
  const { errorMessage, setErrorMessage } = props;

  const handleClose = e => {
    if (e) e.preventDefault();
    setErrorMessage(null);
    history.push('/checkout/cart');
  };

  const errorFields = errorMessage
    ? FIELDS.filter(field =>
        field.keywords.some(keyword => errorMessage.includes(keyword)),
      )
    : [];

  return (
    <Modal show={!!errorMessage} onHide={handleClose} centered>
      <Modal.Body>
        {errorFields.length > 0 ? (
          <>
            <p className="mb-1 mb-md-2">{intl.get(translations.title.id)}</p>
            <ul className="mb-3">
              {errorFields.map((field, index) => (
                <li key={index}>・{field.name}</li>
              ))}
            </ul>
            <div className="text-muted">
              <p className="mb-2">
                <strong>{intl.get(translations.reasonsTitle.id)}</strong>
              </p>
              <ul className="mb-0">
                {errorFields.map((field, index) => (
                  <li key={index}>
                    {field.name}: {field.reason}
                  </li>
                ))}
              </ul>
            </div>
          </>
        ) : (
          <p className="mb-0">{errorMessage}</p>
        )}
      </Modal.Body>
      <Modal.Footer>
        <button type="button" onClick={handleClose} className="close-button">
          {intl.get(translations.closeButton.id)}
        </button>
      </Modal.Footer>
    </Modal>
  );
};

ErrorModal.propTypes = {
  errorMessage: PropTypes.string,
  setErrorMessage: PropTypes.func,
};

ErrorModal.defaultProps = {
  errorMessage: null,
  setErrorMessage: () => {},
};

export default React.memo(ErrorModal);
