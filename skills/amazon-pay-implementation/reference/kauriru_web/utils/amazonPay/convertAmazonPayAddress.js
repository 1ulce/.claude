import { PAYMENT_TYPE } from 'containers/Checkout/constants';
import amazonPayDivider from './amazonPayDivider';

/**
 * Amazon Pay住所データをカウリルの住所データに変換する
 *
 * @param {object} params - パラメータオブジェクト
 * @param {object} params.shippingAddress - Amazon Payの配送先住所
 * @param {object} params.buyer - Amazon Payのバイヤー情報
 * @returns {Promise<object>} カウリルの住所データ
 */
const convertAmazonPayAddress = async ({ shippingAddress, email }) => {
  const fullName = shippingAddress?.name?.trim();
  if (!fullName) {
    throw new Error('氏名が取得できませんでした');
  }

  // 住所分割
  const divideAddressAsync = addressData =>
    new Promise(resolve =>
      amazonPayDivider.divideAddress(addressData, resolve),
    );

  // 氏名分割
  const divideNameAsync = name =>
    new Promise(resolve => amazonPayDivider.divideName(name, resolve));

  const [dividedAddress, dividedName] = await Promise.all([
    divideAddressAsync({
      addressLine1: shippingAddress.addressLine1 || '',
      addressLine2: shippingAddress.addressLine2 || '',
      addressLine3: shippingAddress.addressLine3 || '',
    }),
    divideNameAsync(fullName),
  ]);

  // AmazonPay側の郵便番号がハイフンを含んでいる場合があるのでハイフンを削除
  const postalCode = shippingAddress?.postalCode?.replace(/-/g, '');

  // AmazonPay側の電話番号がハイフンを含んでいる場合があるのでハイフンを削除
  const phoneNumber = shippingAddress?.phoneNumber?.replace(/-/g, '');

  // 氏名分割でfirstNameが空になった場合の補正処理
  // ひらがな・カタカナ・漢字のみの名前で分割ロジックが姓と名を区別できないケースがある、
  // 姓の内容を名前にもコピーして、受け取り画面でのバリデーションエラーを回避(Pay側の要望でこのようにしている)
  if (
    dividedName?.firstName === '' &&
    dividedName?.lastName &&
    /^[ぁ-んァ-ン一-鿿]+$/.test(dividedName?.lastName)
  ) {
    dividedName.firstName = dividedName.lastName;
  }

  // カウリルの住所データを構築
  return {
    addressId: null,
    email,
    companyName: null,
    firstName: dividedName?.firstName || '',
    lastName: dividedName?.lastName || '',
    firstNameKana: '', // Amazon Payからはカナ情報は取得できないため空
    lastNameKana: '', // Amazon Payからはカナ情報は取得できないため空
    phoneNumber: phoneNumber || '',
    postalCode: postalCode || '',
    prefecture: shippingAddress?.stateOrRegion || '',
    municipalities: dividedAddress?.city || '',
    address: dividedAddress?.town || '',
    buildingNumber: [dividedAddress?.streetNumber, dividedAddress?.building]
      .filter(Boolean)
      .join(' '),
    paymentType: PAYMENT_TYPE.AMAZON_PAY,
  };
};

export default convertAmazonPayAddress;
