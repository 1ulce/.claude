/**
 * Shadow DOMがある場合に要素を安全に初期化する
 *
 * @param {HTMLElement} container - 対象コンテナ
 * @param {string} uniqueButtonId - ボタンID
 * @param {object} containerRef - React ref
 * @returns {HTMLElement} - 初期化されたコンテナ
 */
export const initializeSafeContainer = (
  container,
  uniqueButtonId,
  containerRef,
) => {
  if (container.shadowRoot) {
    const newContainer = document.createElement('div');
    newContainer.id = uniqueButtonId;
    container.parentNode.replaceChild(newContainer, container);
    if (containerRef) {
      // eslint-disable-next-line no-param-reassign
      containerRef.current = newContainer;
    }
    return newContainer;
  }

  // eslint-disable-next-line no-param-reassign
  container.innerHTML = '';
  // eslint-disable-next-line no-param-reassign
  container.id = uniqueButtonId;
  return container;
};
