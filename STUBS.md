# Заглушки бізнес-інтеграцій

Мета: розробники можуть пройти повний сценарій без реальних LiqPay, Нової Пошти, Resend і друкарні. Публічний OpenAPI не змінюється: заглушки реалізують ті самі інтерфейси, що й реальні адаптери.

## Перемикачі

```env
PAYMENT_PROVIDER=stub        # stub | liqpay
DELIVERY_PROVIDER=stub       # stub | nova_poshta
PRINT_RENDERER=stub          # stub | fabric
EMAIL_PROVIDER=console       # console | resend
DEMO_MODE=true
```

## 1. PaymentProvider

```ts
interface PaymentProvider {
  createPayment(input: {
    orderId: string;
    amountMinor: number;
    currency: string;
    description: string;
    returnUrl: string;
  }): Promise<{ paymentId: string; paymentUrl: string }>;

  verifyWebhook(request: Request): Promise<{
    eventId: string;
    paymentId: string;
    status: "success" | "failed" | "refunded";
    amountMinor: number;
  }>;

  refund(paymentId: string, amountMinor?: number): Promise<void>;
}
```

Stub:

- `createPayment` створює `payments` рядок зі статусом `pending` і повертає `paymentUrl` на dev-сторінку frontend: `http://localhost:5173/dev/payment/{paymentId}`.
- Dev-сторінка має кнопки «Success» і «Fail». Вони викликають dev-only endpoint `POST /dev/payments/{paymentId}/complete` з `{status}`. Цей endpoint не входить у публічний OpenAPI і працює тільки при `DEMO_MODE=true`.
- `verifyWebhook` для stub не потрібен; dev endpoint сам оновлює `payments.status`, а trigger `payments_status_sync` переводить замовлення.
- Реальний LiqPay adapter пізніше перевіряє `data`/`signature` і повертає нормалізований event.

## 2. DeliveryProvider

```ts
interface DeliveryProvider {
  listCities(query?: string): Promise<DeliveryCity[]>;
  listWarehouses(cityId: string, query?: string): Promise<DeliveryWarehouse[]>;
  quote(cityId: string, warehouseId: string, items: CartItem[]): Promise<{
    deliveryMinor: number;
    estimatedDaysMin?: number;
    estimatedDaysMax?: number;
  }>;
  createShipment(orderId: string): Promise<{
    trackingNumber: string;
    raw: unknown;
  }>;
  track(trackingNumber: string): Promise<ShipmentStatus>;
}
```

Stub:

- Міста: Київ, Львів, Одеса.
- Відділення: по 3 на місто, типи `branch` і `parcel_locker`.
- `quote`: 80 грн для всіх, 1-3 дні.
- `createShipment`: `DEMO-{orderNumber}`, статус `created`.
- `track`: повертає `in_transit`, поки адміністратор не змінить вручну.
- Реальний Nova Poshta adapter пізніше використовує test API key і методи Нової Пошти.

## 3. PrintRenderer

```ts
interface PrintRenderer {
  render(input: {
    orderId: string;
    orderItemId: string;
    designVersionId: string;
    kind: "direct" | "mirrored";
  }): Promise<{ fileId: string }>;
}
```

Stub:

- Бере `design_versions.preview_file_id` або генерує простий placeholder PNG.
- Для `mirrored` робить горизонтальне відображення через `imagescript` або canvas.
- Створює `print_files` зі статусом `ready`.
- `print_jobs` переводить у `ready`.
- Не застосовує CMYK, bleed, safe area або специфічний формат друкарні. Це свідомо: без партнерської друкарні немає сенсу гадати.
- Реальний render worker пізніше використовує Fabric.js + node-canvas і формат, погоджений із друкарнею.

## 4. EmailProvider

```ts
interface EmailProvider {
  send(input: {
    to: string;
    template: string;
    data: Record<string, unknown>;
  }): Promise<{ id: string }>;
}
```

Stub:

- Пише лист у лог Worker-а і створює `notifications` запис.
- Не викликає Resend.
- Реальний adapter пізніше використовує Resend API і шаблони.

## 5. Що тестувати на заглушках

1. Checkout з `PAYMENT_PROVIDER=stub`: замовлення створюється, payment URL веде на dev-сторінку, Success переводить у `paid`.
2. Checkout з Fail: замовлення лишається `pending_payment`, `payments.status=failed`, можна повторити.
3. Delivery stub: міста, відділення, quote 80 грн, ЕН `DEMO-...`.
4. Print stub: `print_jobs` стає `ready`, `print_files` має direct і mirrored.
5. Email stub: лист у лог, `notifications` створено.
6. Повторний webhook/dev success не дублює замовлення або платіж.

## 6. Що не робити

- Не додавати в публічний OpenAPI dev-only endpoint-и. Вони живуть тільки при `DEMO_MODE=true` і не є контрактом.
- Не хардкодити LiqPay/Nova Poshta ключі у frontend.
- Не реалізовувати CMYK/bleed/формат друкарні, поки немає письмового формату від партнера.
- Не використовувати stub у production.
