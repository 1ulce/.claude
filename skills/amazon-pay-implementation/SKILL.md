# Amazon Pay 実装スキル

## 概要

このスキルは、kauriru システムの既存実装を参考にして、kaeruru プラットフォームに Amazon Pay 機能を実装するためのガイダンスを提供します。

## 参考実装

### バックエンド (Rails)

- **kaeuru_app**: 現在の kaeuru Rails API 実装
- **kauriru-server**: kauriru システムの参考実装

### フロントエンド (Next.js)

- **kaeuru_web**: 現在の kaeuru Next.js 実装
- **kauriru_web**: kauriru システムの参考実装
  features/ ディレクトリ構造完全ガイド

  📁 全体構造

  src/features/
  ├── address/ # ドメイン機能（配送先住所管理）
  ├── analytics/ # ドメイン機能（分析）
  ├── checkout/ # ドメイン機能（チェックアウト）
  ├── credit-card/ # ドメイン機能（クレジットカード）
  ├── operation-infomations/# ドメイン機能（運営情報）
  ├── components/ # 共通コンポーネント
  ├── layouts/ # 共通レイアウト
  └── pages/ # ページ固有のロジック
  ├── auth/ # 認証関連ページ
  ├── item/ # 商品関連ページ
  ├── mypage/ # マイページ
  └── shop/ # ショップページ

  ***

  🎯 2 つの主要なパターン

  パターン 1: ドメイン機能 (Domain Features)

  再利用可能なビジネスロジックとコンポーネントをまとめたモジュール。

  例: checkout/, address/, credit-card/

  パターン 2: ページ固有機能 (Page Features)

  特定のページにのみ必要なロジックとコンポーネント。

  例: pages/mypage/, pages/auth/

  ***

  📦 ドメイン機能の標準構造

  例: features/checkout/

  checkout/
  ├── index.ts # 公開 API（エントリーポイント）
  ├── types.ts # 型定義
  ├── constants.ts # 定数
  ├── utils.ts # ユーティリティ関数
  ├── components/ # 再利用可能な UI コンポーネント
  │ ├── CartItem.tsx
  │ ├── PriceSummary.tsx
  │ └── **tests**/ # コンポーネントのテスト
  │ └── PriceSummary.test.tsx
  ├── hooks/ # カスタムフック
  │ ├── useCart.ts
  │ └── useCheckoutNavigate.ts
  ├── services/ # API 呼び出しレイヤー
  │ ├── cart-api.ts # GraphQL API
  │ └── amazon-pay-api.ts # REST API
  ├── stores/ # 状態管理（Zustand）
  │ ├── useCartStore.ts
  │ └── useCheckoutStore.ts
  ├── pages/ # この機能に関連するページコンポーネント
  │ ├── Cart/
  │ │ └── index.tsx
  │ ├── Address/
  │ │ ├── index.tsx
  │ │ └── hooks.ts # ページ固有の hooks
  │ └── Confirm/
  │ ├── index.tsx
  │ └── hooks.ts
  └── **tests**/ # ユーティリティのテスト
  └── utils.test.ts

  ***

  📋 各ディレクトリ・ファイルの役割

  1. index.ts - 公開 API

  役割: 外部から使用する要素をまとめてエクスポート

  // features/checkout/index.ts

  import useCheckoutNavigate from './hooks/useCheckoutNavigate';
  import useCart from './hooks/useCart';
  import useCartStore from './stores/useCartStore';
  import CartPage from './pages/Cart';
  import ConfirmPage from './pages/Confirm';

  // オブジェクトにまとめる（名前空間として使える）
  const Checkout = {
  CartPage,
  ConfirmPage,
  useCheckoutNavigate,
  useCart,
  useCartStore,
  };

  // 個別エクスポート
  export {
  CartPage,
  ConfirmPage,
  useCheckoutNavigate,
  useCart,
  useCartStore,
  };

  // デフォルトエクスポート
  export default Checkout;

  使い方:
  // 他のファイルから使用
  import { CartPage, useCart } from '@/features/checkout';
  // または
  import Checkout from '@/features/checkout';
  const page = <Checkout.CartPage />;

  ***

  2. types.ts - 型定義

  役割: この機能で使う型を一元管理

  // features/checkout/types.ts

  import { STEPS, SHIPPING_METHODS } from '@/features/checkout/constants';
  import type { AddressSchema } from '@/features/address';

  // ステップの型（constants から生成）
  export type StepType = typeof STEPS[number];

  // 配送情報
  export type ShippingType = {
  shippingMethod: typeof SHIPPING_METHODS[number];
  };

  // 支払い情報
  export type PaymentType = {
  totalPrice: number;
  totalPriceWithTax: number;
  freeShippingThreshold: number | null;
  shippingFee: number;
  paymentAmount: number;
  };

  // クレジットカード情報
  export type CreditCardType = {
  token: string | null;
  creditCardNumber: string | null;
  expirationDate: string | null;
  nameOnCard: string | null;
  };

  ポイント:

  - GraphQL の型は @/gql/graphql から import
  - ビジネスロジック固有の型はここで定義
  - 他の feature の型を再利用する場合は import

  ***

  3. constants.ts - 定数

  役割: マジックナンバー・マジックストリングを排除

  // features/checkout/constants.ts

  // ステップの定義
  export const STEPS = [
  "cart",
  "address",
  "verify",
  "complete",
  ] as const;

  // 配送方法の定義
  export const SHIPPING_METHODS = [
  'standard',
  'scheduled'
  ] as const;

  ポイント:

  - as const を使って型安全に
  - types.ts で typeof を使って型を生成

  ***

  4. utils.ts - ユーティリティ関数

  役割: 純粋関数のビジネスロジック

  // features/checkout/utils.ts

  import type { PaymentType } from '@/features/checkout/types';

  // 支払い計算ロジック
  export const calculatePayment = ({
  cartItems = [],
  freeShippingThreshold,
  fee,
  }: {
  cartItems: { price?: number; quantity: number }[];
  freeShippingThreshold?: number | null;
  fee?: number | null;
  }): PaymentType => {
  const totalPrice = cartItems.reduce(
  (sum, item) => sum + (item.price ?? 0) \* item.quantity,
  0
  );
  // ... 計算ロジック
  return { totalPrice, totalPriceWithTax, shippingFee, paymentAmount };
  };

  ポイント:

  - 副作用なし（Pure Function）
  - テストしやすい
  - コンポーネントから独立

  ***

  5. components/ - 再利用可能な UI コンポーネント

  役割: この機能で再利用する UI コンポーネント

  // features/checkout/components/CartItem.tsx

  import Image from 'next/image';
  import { Link } from '@/i18n/navigation';

  export default function CartItem({
  item,
  onRemove,
  }: {
  item: OrderCartItem;
  onRemove: (id: string) => void;
  }) {
  return (
  <div className="w-full flex gap-[8px]">
  <Image src={item.image} alt={item.name} />
  <div>{item.name}</div>
  <button onClick={() => onRemove(item.id)}>削除</button>
  </div>
  );
  }

  ポイント:

  - プレゼンテーションに集中
  - ビジネスロジックは含めない（props で受け取る）
  - 複数のページで使う場合はここに配置

  使い分け:

  - components/ = この機能内で再利用
  - @/components/ = プロジェクト全体で再利用

  ***

  6. hooks/ - カスタムフック

  役割: 状態管理とビジネスロジック

  // features/checkout/hooks/useCart.ts

  import { useState, useCallback } from 'react';
  import useCartStore from '@/features/checkout/stores/useCartStore';
  import cartApi from '@/features/checkout/services/cart-api';
  import { toastErrors } from '@/lib/toast-utils';

  const useCart = () => {
  const cartToken = useCartStore((state) => state.cartToken);
  const setCart = useCartStore((state) => state.setCart);
  const [loading, setLoading] = useState(false);

      const addCartItem = useCallback(async ({ itemId, quantity }) => {
        try {
          setLoading(true);
          const result = await cartApi.addItemToCart({ itemId, quantity, cartToken });

          if (result.errors.length > 0) {
            toastErrors(result.errors);
            return { errors: result.errors };
          }

          setCart(result.currentCart);
          return { currentCart: result.currentCart, errors: [] };
        } catch (error) {
          logger.error({ error }, 'Failed to add item');
          throw error;
        } finally {
          setLoading(false);
        }
      }, [cartToken, setCart]);

      return { loading, addCartItem };

  };

  export default useCart;

  責務:

  - Services 層の呼び出し
  - ローディング状態管理
  - エラーハンドリング
  - ストアとの連携

  ***

  7. services/ - API 呼び出しレイヤー

  役割: バックエンド API との通信

  GraphQL API の場合

  // features/checkout/services/cart-api.ts

  import { requestWithAuth } from '@/lib/graphql-client';
  import { GetCartQuery, GetCartDocument } from '@/gql/graphql';

  export const fetchCart = async ({ cartToken }: { cartToken: string | null }) => {
  const res = await requestWithAuth<GetCartQuery>(GetCartDocument, {
  cartToken: cartToken,
  });
  return res?.order?.currentCart ?? null;
  };

  export const addItemToCart = async ({
  cartToken,
  itemId,
  quantity
  }: {
  cartToken: string | null;
  itemId: string;
  quantity: number
  }) => {
  const params = {
  input: { itemId, quantity, cartToken }
  };
  const res = await requestWithAuth<OrderAddItemToCartMutation>(
  OrderAddItemToCartDocument,
  params
  );
  return {
  currentCart: res?.order?.addItemToCart?.currentCart ?? null,
  errors: res?.order?.addItemToCart?.errors ?? []
  };
  };

  export default { fetchCart, addItemToCart };

  REST API の場合

  // features/checkout/services/amazon-pay-api.ts

  import { logger } from '@/lib/logger';

  export interface AmazonCheckoutSession {
  checkoutSessionId?: string;
  buyer?: { name?: string; email?: string };
  // ... 型定義
  }

  const getAmazonPayApiBaseUrl = (): string => {
  const isServer = typeof window === 'undefined';
  const graphqlUrl = isServer
  ? process.env.NEXT_PRIVATE_API_ENDPOINT_URL!
  : process.env.NEXT_PUBLIC_API_ENDPOINT_URL!;
  return graphqlUrl.replace('/graphql', '');
  };

  export const fetchCheckoutSession = async (
  sessionId: string
  ): Promise<AmazonCheckoutSession> => {
  const baseUrl = getAmazonPayApiBaseUrl();
  const url = `${baseUrl}/amazon_pay/checkout_sessions/${sessionId}`;

      logger.info({ url, sessionId }, 'Fetching checkout session');

      const response = await fetch(url, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch: ${response.status}`);
      }

      return await response.json();

  };

  export default { fetchCheckoutSession };

  責務:

  - API 呼び出し
  - URL の構築
  - レスポンスの型変換
  - HTTP エラーハンドリング
  - ログ出力

  ***

  8. stores/ - 状態管理（Zustand）

  役割: グローバル状態の管理

  // features/checkout/stores/useCartStore.ts

  import { create } from 'zustand';
  import { persist } from 'zustand/middleware';
  import type { OrderCart } from '@/gql/graphql';

  interface CartStore {
  cartToken: string | null;
  cart: OrderCart | null;
  groupedCartItems: OrderCartItem[];
  setCart: (cart: OrderCart | null) => void;
  setCartToken: (token: string | null) => void;
  }

  const useCartStore = create<CartStore>()(
  persist(
  (set) => ({
  cartToken: null,
  cart: null,
  groupedCartItems: [],
  setCart: (cart) => set({ cart, groupedCartItems: cart?.items ?? [] }),
  setCartToken: (token) => set({ cartToken: token }),
  }),
  {
  name: 'cart-storage',
  partialize: (state) => ({ cartToken: state.cartToken }),
  }
  )
  );

  export default useCartStore;

  ポイント:

  - persist でローカルストレージに永続化
  - partialize で保存する項目を限定

  ***

  9. pages/ - ページコンポーネント

  役割: 特定のルートに対応するページ

  // features/checkout/pages/Cart/index.tsx

  'use client';

  import { useCallback } from 'react';
  import CartItems from '@/features/checkout/components/CartItems';
  import PriceSummary from '@/features/checkout/components/PriceSummary';
  import useCart from '@/features/checkout/hooks/useCart';
  import useCheckoutStore from '@/features/checkout/stores/useCheckoutStore';

  export default function CartPage({ slug }: { slug: string }) {
  const { loading, removeCartItem } = useCart();
  const { cartItems, payment } = useCheckoutStore();

      const handleRemove = useCallback(async (id: string) => {
        await removeCartItem({ cartItemId: id });
      }, [removeCartItem]);

      return (
        <div>
          <CartItems items={cartItems} onRemove={handleRemove} />
          <PriceSummary payment={payment} />
        </div>
      );

  }

  ページ固有の hooks

  // features/checkout/pages/Confirm/hooks.ts

  import { useState, useEffect } from 'react';
  import amazonPayApi from '@/features/checkout/services/amazon-pay-api';

  export const usePage = ({ slug }: { slug: string }) => {
  const [session, setSession] = useState(null);

      useEffect(() => {
        const fetchSession = async () => {
          const data = await amazonPayApi.fetchCheckoutSession(sessionId);
          setSession(data);
        };
        fetchSession();
      }, []);

      return { session };

  };

  ポイント:

  - ページ固有の hooks は hooks.ts または \_hooks.ts に
  - 再利用しないロジックはここに配置

  ***

  10. **tests**/ - テスト

  役割: ユニットテスト・統合テスト

  // features/checkout/**tests**/utils.test.ts

  import { calculatePayment } from '@/features/checkout/utils';

  describe('calculatePayment', () => {
  it('should calculate total price correctly', () => {
  const result = calculatePayment({
  cartItems: [
  { price: 1000, quantity: 2 },
  { price: 500, quantity: 1 },
  ],
  fee: 500,
  });

        expect(result.totalPrice).toBe(2500);
        expect(result.shippingFee).toBe(500);
      });

  });

  ***

  🆚 features/checkout vs features/pages の違い

  features/checkout/ (ドメイン機能)

  - 目的: チェックアウト機能を提供
  - 再利用性: 高い
  - 独立性: 高い（他の機能に依存しない）
  - エクスポート: index.ts で公開 API 定義
  - テスト: 必須

  使い方:
  import { CartPage, useCart } from '@/features/checkout';

  ***

  features/pages/mypage/ (ページ固有機能)

  - 目的: マイページの表示
  - 再利用性: 低い（そのページでのみ使用）
  - 独立性: 低い（複数のドメイン機能を組み合わせる）
  - エクスポート: 通常なし
  - テスト: 任意

  構造:
  features/pages/mypage/
  ├── address/
  │ ├── list/
  │ │ ├── index.tsx # マイページの住所一覧画面
  │ │ └── \_hooks.ts # この画面固有の hooks
  │ └── detail/
  │ ├── index.tsx # マイページの住所詳細画面
  │ └── \_hooks.ts
  └── order/
  ├── index.tsx # マイページの注文履歴画面
  └── \_hooks.ts

  使い方:
  // app/[locale]/mypage/address/page.tsx
  import AddressListPage from '@/features/pages/mypage/address/list';

  export default function Page() {
  return <AddressListPage />;
  }

  ***

  📖 実践ガイド：新機能追加の手順

  ケース 1: 新しいドメイン機能を追加

  例: 「お気に入り機能」を追加

  ステップ 1: ディレクトリ構造を作成

  mkdir -p src/features/favorites/{components,hooks,services,stores,pages}
  touch src/features/favorites/{index.ts,types.ts,constants.ts}

  ステップ 2: 型定義 (types.ts)

  // features/favorites/types.ts

  export type FavoriteItem = {
  id: string;
  itemId: string;
  createdAt: string;
  };

  ステップ 3: Services 層 (services/favorites-api.ts)

  // features/favorites/services/favorites-api.ts

  import { requestWithAuth } from '@/lib/graphql-client';
  import { GetFavoritesQuery, GetFavoritesDocument } from '@/gql/graphql';

  export const fetchFavorites = async () => {
  const res = await requestWithAuth<GetFavoritesQuery>(GetFavoritesDocument);
  return res?.customer?.user?.favorites ?? [];
  };

  export const addToFavorites = async (itemId: string) => {
  // ... 実装
  };

  export default { fetchFavorites, addToFavorites };

  ステップ 4: Hooks 層 (hooks/useFavorites.ts)

  // features/favorites/hooks/useFavorites.ts

  import { useState, useCallback } from 'react';
  import favoritesApi from '@/features/favorites/services/favorites-api';

  const useFavorites = () => {
  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(false);

      const addFavorite = useCallback(async (itemId: string) => {
        setLoading(true);
        try {
          const result = await favoritesApi.addToFavorites(itemId);
          setFavorites(result);
        } finally {
          setLoading(false);
        }
      }, []);

      return { favorites, loading, addFavorite };

  };

  export default useFavorites;

  ステップ 5: エクスポート (index.ts)

  // features/favorites/index.ts

  import useFavorites from './hooks/useFavorites';

  export { useFavorites };
  export default { useFavorites };

  ***

  ケース 2: 既存機能に REST API を追加

  例: checkout に Amazon Pay API を追加（今回の実装）

  ステップ 1: Services 層を作成

  // features/checkout/services/amazon-pay-api.ts

  export const fetchCheckoutSession = async (sessionId: string) => {
  // REST API 呼び出し
  };

  export default { fetchCheckoutSession };

  ステップ 2: 既存の Hooks で使用

  // features/checkout/pages/Confirm/hooks.ts

  import amazonPayApi from '@/features/checkout/services/amazon-pay-api';

  export const usePage = ({ slug }) => {
  const data = await amazonPayApi.fetchCheckoutSession(sessionId);
  // ...
  };

  ステップ 3: index.ts は更新不要

  Services 層は内部実装なので、公開 API に追加する必要はない。

  ***

  ✅ ベストプラクティス

  1. index.ts で公開 API を明確に

  // 良い例
  export { useCart, CartPage } from '@/features/checkout';

  // 悪い例（Services 層を公開しない）
  export { fetchCart } from '@/features/checkout/services/cart-api';

  2. Hooks から Services 層を呼ぶ

  // 良い例
  const useCart = () => {
  const result = await cartApi.fetchCart();
  };

  // 悪い例（コンポーネントから直接 Services 層を呼ばない）
  const CartPage = () => {
  const result = await cartApi.fetchCart();
  };

  3. 型定義は types.ts に集約

  // 良い例
  // features/checkout/types.ts
  export type PaymentType = { ... };

  // 悪い例（コンポーネント内で型定義）
  const CartPage = () => {
  type Payment = { ... }; // NG
  };

  4. constants は as const で型安全に

  // 良い例
  export const STEPS = ["cart", "address"] as const;
  export type StepType = typeof STEPS[number]; // "cart" | "address"

  // 悪い例
  export const STEPS = ["cart", "address"]; // string[]

  5. utils は純粋関数で

  // 良い例（副作用なし）
  export const calculatePayment = (items) => {
  return items.reduce(...);
  };

  // 悪い例（副作用あり）
  export const calculatePayment = (items) => {
  toast.success('計算完了'); // NG
  return items.reduce(...);
  };

  ***

  📚 まとめ

  | ファイル/ディレクトリ | 用途                 | 追加タイミング                       |
  | --------------------- | -------------------- | ------------------------------------ |
  | index.ts              | 公開 API             | 機能作成時                           |
  | types.ts              | 型定義               | 型が必要になったら                   |
  | constants.ts          | 定数                 | マジックストリングを排除したいとき   |
  | utils.ts              | 純粋関数             | ビジネスロジックを切り出したいとき   |
  | components/           | UI コンポーネント    | 再利用するコンポーネントができたとき |
  | hooks/                | カスタムフック       | ロジックを再利用したいとき           |
  | services/             | API 呼び出し         | バックエンドと通信するとき           |
  | stores/               | 状態管理             | グローバル状態が必要なとき           |
  | pages/                | ページコンポーネント | ルートに対応するページを作るとき     |
  | **tests**/            | テスト               | テストを書くとき                     |

  この構造に従うことで、保守性・再利用性・テスト容易性の高いコードベースを維持できます！

## 実装状況

### ✅ kaeuru_app で実装済み

- Amazon Pay Ruby SDK 統合 (`lib/amazon_pay/`)
- データベーススキーマ:
  - `vendor_amazon_pay_accounts` テーブル
  - `vendor_services`の`amazon_pay_enabled`フラグ
- Amazon Pay アカウント管理用の管理画面
- Payment モデルで Amazon Pay タイプをサポート

### ❌ 未実装

- フロントエンドの Amazon Pay ボタン (`kaeuru_web/src/features/checkout/pages/Cart/index.tsx:111`にプレースホルダーあり)
- チェックアウトセッション管理用の GraphQL ミューテーション
- IPN (Instant Payment Notification) 処理
- チェックアウト完了フロー

## kauriru システムの参考ファイル

### バックエンド (kauriru-server)

`.claude/skills/amazon-pay-implementation/reference/`に配置:

1. **コントローラー**:

   - `amazon_pay_controller.rb`: Amazon Pay 操作のメインコントローラー
   - `amazon_pay/checkouts_controller.rb`: チェックアウトセッション管理
   - `amazon_pay/ipn_controller.rb`: IPN ウェブフック処理

2. **モデル**:

   - `vendor_amazon_pay_account.rb`: ベンダーの Amazon Pay 設定

3. **主要エンドポイント**:
   - `POST /amazon_pay/checkout_sessions`: チェックアウトセッション作成
   - `GET /amazon_pay/checkout_sessions/:id`: セッション詳細取得
   - `POST /amazon_pay/checkout_sessions/:id/complete`: チェックアウト完了
   - `POST /amazon_pay/ipn`: Amazon Pay 通知処理

### フロントエンド (kauriru_web)

`.claude/skills/amazon-pay-implementation/reference/`に配置:

1. **コンポーネント**:

   - `AmazonPayButton.tsx`: メインボタンコンポーネント
   - `useAmazonPay.ts`: Amazon Pay SDK 用カスタムフック

2. **統合ポイント**:
   - Amazon Pay SDK の動的ロード
   - 適切な設定でボタンをレンダリング
   - Amazon Pay へのリダイレクト処理
   - Amazon Pay からの戻り処理

## 実装ガイドライン

### 1. フロントエンド実装 (kaeuru_web)

#### カートに Amazon Pay ボタンを追加

```typescript
// Cart/index.tsx:111のプレースホルダーコメントを置き換え
// AmazonPayButtonコンポーネントをインポートして使用（参考実装から適応）
```

#### 主要な考慮事項:

- REST API コールの代わりに GraphQL ミューテーションを使用
- 既存の Next.js App Router パターンと統合
- 国際化サポートを維持
- NextAuth を使った既存の認証パターンに従う

### 2. バックエンド実装 (kaeuru_app)

#### GraphQL ミューテーションを作成

```ruby
# 適切なGraphQLタイプに追加
field :create_amazon_pay_session, mutation: Mutations::CreateAmazonPaySession
field :complete_amazon_pay_checkout, mutation: Mutations::CompleteAmazonPayCheckout
```

#### コントローラーを GraphQL に適応

- REST エンドポイントを GraphQL リゾルバーに変換
- `lib/amazon_pay/`の既存 Amazon Pay SDK を使用
- 既存の`VendorAmazonPayAccount`モデルを活用

### 3. アーキテクチャの違い

#### kauriru (参考)

- Cookie ベースセッションを使用した REST API
- JavaScript エンハンスメントによるサーバーレンダリングビュー
- 直接的なコントローラーアクション

#### kaeuru (ターゲット)

- JWT 認証を使用した GraphQL API
- フルクライアントサイドレンダリングの Next.js App Router
- GraphQL を通じたミューテーションとクエリ

## 実装チェックリスト

### フェーズ 1: フロントエンドボタン

- [ ] `AmazonPayButton.tsx`を kaeuru_web に移植
- [ ] `useAmazonPay.ts`フックを Next.js 用に適応
- [ ] カートページにボタンを追加
- [ ] ベンダーの Amazon Pay 認証情報で設定

### フェーズ 2: チェックアウトセッション

- [ ] `CreateAmazonPaySession` GraphQL ミューテーションを作成
- [ ] 参考コントローラーからチェックアウトセッションロジックを移植
- [ ] リダイレクト URL 生成を処理
- [ ] セッション検証を実装

### フェーズ 3: 決済完了

- [ ] `CompleteAmazonPayCheckout` GraphQL ミューテーションを作成
- [ ] 参考から完了ロジックを移植
- [ ] 注文と決済ステータスを更新
- [ ] エラーケースを処理

### フェーズ 4: IPN 処理

- [ ] IPN ウェブフックエンドポイントを作成
- [ ] IPN 検証ロジックを移植
- [ ] 通知に基づいて決済ステータスを更新
- [ ] ロギングとモニタリングを追加

## テスト戦略

1. **ユニットテスト**:

   - GraphQL ミューテーションテスト
   - Amazon Pay SDK モックテスト

2. **統合テスト**:

   - 完全なチェックアウトフローテスト
   - IPN ウェブフックテスト

3. **手動テスト**:
   - Amazon Pay サンドボックスでテスト
   - ボタンレンダリングを確認
   - エンドツーエンドのチェックアウトを完了

## セキュリティ考慮事項

- ベンダーが Amazon Pay を有効にしていることを検証
- チェックアウトセッションの所有権を確認
- 署名検証で IPN エンドポイントを保護
- 監査のためすべての決済操作をログに記録

## よくある問題

1. **CORS 問題**: Amazon Pay ドメインがホワイトリストに登録されていることを確認
2. **リダイレクト URL**: 本番環境では HTTPS である必要があります
3. **通貨**: JPY フォーマットが Amazon Pay の要件と一致することを確認
4. **ボタンレンダリング**: レンダリング前に SDK をロードする必要があります

## リソース

- [Amazon Pay 統合ガイド](https://developer.amazon.com/docs/amazon-pay-api-v2/introduction.html)
- 既存の kaeuru Amazon Pay SDK: `kaeuru_app/lib/amazon_pay/`
- 参考実装: `.claude/skills/amazon-pay-implementation/reference/`
- Kiro 仕様: `docs/.kiro/specs/amazon-pay-checkout/`
