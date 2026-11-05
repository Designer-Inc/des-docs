# Frontend route map

Мінімальна карта сторінок, щоб frontend міг працювати без окремих питань. Усі API-виклики йдуть на відносний `/api`.

## Публічні сторінки

| Route | Сторінка | Дані |
| --- | --- | --- |
| `/` | Головна, банер, каталог | `GET /products`, `GET /categories` |
| `/catalog` | Каталог із фільтрами | `GET /products`, `GET /categories` |
| `/product/:id` | Картка товару | `GET /products/{id}` |
| `/design/:id` | Картка авторського дизайну | `GET /designs/{id}` |
| `/search?q=` | Пошук | `GET /search` |
| `/login` | Вхід | `POST /auth/login` |
| `/register` | Реєстрація | `POST /auth/register` |
| `/forgot-password` | Запит скидання | `POST /auth/password/forgot` |
| `/reset-password?token=` | Новий пароль | `POST /auth/password/reset` |

## Покупець

| Route | Сторінка | Доступ |
| --- | --- | --- |
| `/editor/:productId` | Конструктор | Авторизований, будь-яка роль |
| `/cart` | Кошик | Авторизований |
| `/checkout` | Оформлення | Авторизований, кошик не порожній |
| `/account` | Профіль | Авторизований |
| `/account/orders` | Історія замовлень | Авторизований |
| `/account/orders/:id` | Деталі замовлення | Власник або staff |
| `/account/designs` | Мої дизайни | Власник |
| `/account/designs/:id` | Деталі дизайну | Власник або staff |
| `/account/company` | B2B-реквізити | Авторизований |
| `/account/notifications` | Сповіщення | Авторизований |

## Автор

| Route | Сторінка | Доступ |
| --- | --- | --- |
| `/account/designs` | Чернетки, rejected, published | Власник |
| `/account/designs/:id/edit` | Редактор чернетки | Власник, статус draft/rejected |
| `/account/designs/:id/versions` | Історія версій | Власник або staff |
| `/account/earnings` | Винагорода | Авторизований автор |
| `/account/stats` | Статистика автора | Авторизований автор |

## Модератор

| Route | Сторінка | Доступ |
| --- | --- | --- |
| `/moderation` | Черга дизайнів | moderator/admin |
| `/moderation/designs/:id` | Картка дизайну, DPI, права | moderator/admin |
| `/moderation/orders` | Черга замовлень | moderator/admin |
| `/moderation/orders/:id` | Замовлення на модерацію | moderator/admin |
| `/moderation/reports` | Скарги | moderator/admin |

## Адміністратор

| Route | Сторінка | Доступ |
| --- | --- | --- |
| `/admin` | Дашборд | admin |
| `/admin/products` | Товари | admin |
| `/admin/products/new` | Новий товар | admin |
| `/admin/products/:id` | Редагування товару | admin |
| `/admin/categories` | Категорії | admin |
| `/admin/orders` | Усі замовлення | admin |
| `/admin/orders/:id` | Замовлення, друк, платіж | admin |
| `/admin/print-queue` | Черга друку | admin |
| `/admin/users` | Користувачі | admin |
| `/admin/audit-logs` | Журнал дій | admin |

## Guards

- Гість на захищеному route: redirect на `/login?next=<encoded path>`.
- Після логіну: повернутися на `next`, інакше `/account`.
- Немає ролі: 403-сторінка, не порожній екран.
- Чужий ресурс: 404, не 403, щоб не розкривати існування.
- Кошик порожній на `/checkout`: redirect на `/cart` з повідомленням.
- Опублікований дизайн: кнопки редагування немає, тільки «Взяти за основу» (fork).
- Чернетка: кнопки «Зберегти», «Опублікувати», «Видалити».
- Замовлення після оплати: скасування недоступне, тільки інформація.

## Стани, які треба передбачити

- Loading skeleton для каталогу, картки, історії.
- Empty state для кошика, дизайнів, замовлень, черг.
- Error state з `error.code` і `requestId`.
- 401: один refresh, потім redirect на логін.
- 403: сторінка «Немає доступу».
- 404: сторінка «Не знайдено».
- 409: показати конфлікт і запропонувати оновити дані.
- 422: підсвітити поля або показати бізнес-помилку.
- 429: показати `Retry-After`.
- Offline: не втрачати чернетку, показати статус.

## Що не робити

- Не тримати access token у localStorage.
- Не викликати Supabase напряму для даних, тільки через `/api`.
- Не дублювати розрахунок ціни на клієнті: джерело істини `POST /cart/quote`.
- Не показувати рейтинг, промокод, відгуки або обране: їх немає в контракті.
- Не редагувати `designVersionId` або `orderItem` на клієнті.
