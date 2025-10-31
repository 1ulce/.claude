export const getAmazonPayConfig = (productType, placement) => {
  return {
    merchantId: window.AmazonPayMerchantId,
    ledgerCurrency: 'JPY',
    sandbox: window.Environment !== 'prd',
    checkoutLanguage: 'ja_JP',
    productType,
    placement,
    buttonColor: 'Gold',
  };
};
