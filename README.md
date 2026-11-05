# «Дизайнер»: des-docs

Це репозиторій контракту для frontend і backend. Обидві команди працюють паралельно: frontend бере `openapi.yaml`, backend бере `database/schema.sql` та той самий `openapi.yaml`. `des-docs` є джерелом істини, app-репозиторії містять лише синхронізовані копії контракту.

## Файли

| Файл | Призначення |
| --- | --- |
| `PRODUCT_SPEC.md` | Повна специфікація продукту: межі, ролі, FR, бізнес-правила, стани, NFR, інтеграції, трасування user stories |
| `openapi.yaml` | OpenAPI 3.0.3, 78 path-ів, 93 операції, 135 схем. Єдине джерело істини для запитів і відповідей |
| `database/schema.sql` | PostgreSQL 15+ DDL для Supabase: 29 таблиць, enum-и, індекси, тригери, RLS, версії дизайну |
| `database/seed.sql` | Демо-користувачі, товари, варіанти, зони друку, 5 дизайнів і демо-замовлення |
| `database/ER.md` | Mermaid-діаграми та правила цілісності |
| `FREE_TIER.md` | Безкоштовний профіль: ліміти, render worker, R2, backups, keep-alive, чек-лист |
| `DEVELOPMENT.md` | Локальний запуск, JWT, CORS, cookies, Postman, міграції, DoD, GitHub Actions |
| `STUBS.md` | Заглушки оплати, доставки, друку та email |
| `FRONTEND.md` | Карта route-ів, guards і стани UI |
| `TEST_VECTORS.md` | Очікувані результати для цін, DPI, геометрії, статусів, auth, пагінації |
| `examples/` | 3 JSON-приклади для Postman, MSW і ручних запитів |
| `assets/fonts/` | 5 family TTF із кирилицею, 400/700, normal/italic, OFL-ліцензії |
| `CHANGELOG.md` | Історія версій контракту |
| `CONTRIBUTING.md` | Як змінювати контракт, рев'ю, версіонування, синхронізація |
| `CODEOWNERS` | Обов'язкові рев'ювери |
| `adr/` | Architecture Decision Records |
| `.github/workflows/docs.yml` | CI: OpenAPI, типи, schema+seed, links, GitHub Pages |
| `redocly.yaml` | Правила lint для OpenAPI |

## Порядок читання

1. `PRODUCT_SPEC.md`, розділи 1-5: що будуємо і за якими правилами.
2. `PRODUCT_SPEC.md`, розділ 7: наскрізні правила API.
3. `openapi.yaml`: конкретні endpoint-и та схеми.
4. `database/ER.md`: модель даних.
5. `database/schema.sql`: реалізація моделі.
6. `database/seed.sql`: демо-дані для старту.
7. `DEVELOPMENT.md`: локальний запуск, auth, CORS, Postman, DoD.
8. `STUBS.md`: що залишається заглушкою.
9. `FRONTEND.md`: route map і guards.
10. `TEST_VECTORS.md`: очікувані результати.
11. `FREE_TIER.md`: як запустити все на $0 і що для цього змінити.
12. `CHANGELOG.md`: поточна версія контракту.
13. `CONTRIBUTING.md`: процес зміни контракту.
14. `adr/`: чому ухвалені ключові рішення.

## Для frontend-команди

- Генеруйте типи з `openapi.yaml` (`openapi-typescript`, `orval`, `openapi-fetch`). Не пишіть типи вручну.
- Base URL: `/api` у production (Cloudflare Pages proxy), `http://localhost:8787` локально.
- Авторизація: access token у пам'яті, refresh token у HttpOnly cookie. `fetch(..., { credentials: "include" })`.
- Перехоплюйте 401 один раз, викликайте `POST /auth/refresh`, повторіть запит. Не робіть refresh-цикл.
- Помилки: перемикайтеся на `error.code`, не на `error.message`.
- Списки: завжди `{ items, page, limit, total, hasMore }`.
- Гроші: `*Minor` це ціле число копійок. Форматуйте на UI, не діліть на 100 у бізнес-логіці.
- Кошик: Zustand + localStorage. Перед checkout викликайте `POST /cart/quote`, потім `POST /orders` з `Idempotency-Key`.
- Завантаження: `POST /uploads` -> `PUT uploadUrl` -> `POST /uploads/{id}/complete`. Не завантажуйте напряму в Supabase.
- Дизайн: `canvas` це Fabric.js JSON. Підтримуються кілька `ImageObject`, `TextboxObject` і `ShapeObject` (до 20 об'єктів), будь-який `angle` від -360 до 360, 5 захардкожених шрифтів із `GET /config`. Не змінюйте формат без узгодження з backend, бо worker рендерить його у print-ready.
- Версії: після замовлення позиція містить `designVersionId`. Не показуйте редагування опублікованого дизайну. Для зміни макета створюйте новий дизайн через fork; старі замовлення залишаються на своїй версії.
- Не показуйте рейтинг товару, промокод і відгуки: їх немає в цій версії.
- Для моків використовуйте `openapi.yaml` та `examples/`. Не вигадуйте нові поля.
- Route map і guards: `FRONTEND.md`. Очікувані результати: `TEST_VECTORS.md`.

## Для backend-команди

- Стек: Hono на Cloudflare Workers, Supabase Auth, PostgreSQL 15+, Supabase Storage.
- Застосуйте `database/schema.sql` на чисту БД. Це fresh-install snapshot. Далі тільки append-only міграції.
- Для демо-даних застосуйте `database/seed.sql`: 5 користувачів, 5 товарів, 20 варіантів, дизайни й одне замовлення. Пароль: `DemoPass123!`.
- Backend підключається до Supabase з `service_role`, тому RLS не замінює перевірки в Hono. Перевіряйте роль і власність у кожному handler-і.
- Бізнес-інтеграції можна почати з `STUBS.md`: payment, delivery, print, email. Публічний контракт при цьому не змінюється.
- Геометрія canvas: об'єкти в px, `pxPerMm` і `mockupPxPerMm` не взаємозамінні. Деталі в `PRODUCT_SPEC.md`, 5.2.1.
- Шрифти: 5 family TTF у `assets/fonts` (400/700, italic де є); віддавайте ті самі файли frontend і print worker.
- Не віддавайте `service_role` key на frontend. Signed upload URL створює backend.
- Гроші рахуйте в integer копійках. Не використовуйте float.
- `POST /orders` виконуйте в одній транзакції: order, order_items, payment/invoice, author_bonuses, legal_acceptances. Перевіряйте stock атомарно.
- Версії: для опублікованого дизайну беріть `designs.current_version_id`, для приватної чернетки створюйте `design_versions` з `source=order_snapshot` і `status=pending_moderation`. `order_items.design_version_id` обов'язковий для позиції з дизайном. Print worker читає canvas тільки з версії.
- Webhook оплати: перевірте підпис, вставте `payment_events` з unique `(provider, event_id)`, оновіть `payments.status`. Тригер `payments_status_sync` переведе замовлення.
- Print-ready генерація: після `in_production` створюйте `print_jobs`, рендерте canvas у 300 DPI через Fabric.js + node-canvas у Node-сумісному worker-і або headless browser із тими самими 5 font-файлами, пишіть `print_files` direct і mirrored. 3 повтори, потім `failed`. Cloudflare Workers самі не мають node-canvas, тому потрібен окремий render service або Browser Rendering.
- Email: Resend. Невдача email не відкочує бізнес-операцію.
- Не змінюйте enum-и без міграції `ALTER TYPE ... ADD VALUE`.
- Перед merge: `npx @redocly/cli lint openapi.yaml`, `psql -f database/schema.sql` на чистій БД, тести RLS.

## Версіонування і синхронізація

- Кожен контрактний реліз отримує тег `contract-vX.Y.Z`.
- `MAJOR` це breaking change, `MINOR` нові сумісні поля або endpoint-и, `PATCH` виправлення тексту й прикладів.
- App-репозиторії містять копії `openapi.yaml` і `database/schema.sql` з header `Synced from des-docs@contract-vX.Y.Z`.
- Копії не редагують вручну. Зміна починається в `des-docs`.
- Історія: `CHANGELOG.md`. Процес: `CONTRIBUTING.md`.

## CI і GitHub Pages

GitHub Actions у цьому репозиторії перевіряє:

- `redocly lint openapi.yaml`;
- генерацію типів через `openapi-typescript`;
- застосування `database/schema.sql` і `database/seed.sql` на PostgreSQL 15;
- Markdown-посилання;
- збірку HTML-документації OpenAPI.

На `main` документація деплоїться на GitHub Pages. У налаштуваннях репозиторію Pages source має бути `GitHub Actions`.

Локально:

```bash
bun install
bun run check
bun run preview:docs
```

## Що не входить у репозиторій

- Код React, Hono або Supabase Edge Functions.
- Секрети, `.env`, ключі LiqPay, Nova Poshta, Resend, R2.
- Реальні персональні дані.
- `node_modules`, `dist`, згенеровані типи.
- Великі медіафайли: фото товарів, print-ready, PDF замовлень.
- Шрифти є винятком: це невеликі contract assets із OFL-ліцензіями.

## Наскрізні правила, які не можна змінювати самостійно

1. Форма помилки `{ error: { code, message, details?, requestId } }`.
2. Пагінація `{ items, page, limit, total, hasMore }`.
3. Гроші в копійках, `currency` UAH.
4. Час ISO 8601 UTC.
5. ID UUID у рядках.
6. Enum-и в нижньому регістрі з підкресленнями.
7. Access JWT 15 хв, refresh 7 діб, HttpOnly cookie.
8. `Idempotency-Key` для створення замовлення, платежу, рахунку, відправлення, повернення, файлу друку.
9. Завантаження тільки через двоетапний signed upload.
10. Публічні дизайни тільки зі статусом `published`.

Будь-яка зміна цих правил це breaking change. Спочатку змінюється `PRODUCT_SPEC.md`, потім `openapi.yaml`, потім `schema.sql`, і обидві команди погоджують це в одному PR.

## Перевірка

OpenAPI:

```bash
npx --yes @redocly/cli@latest lint openapi.yaml
npx --yes @redocly/cli@latest preview-docs openapi.yaml
```

Очікуваний результат: `valid`. Style warnings про `4xx` і `localhost` не є помилками.

SQL:

```bash
docker run --rm -d --name dyzainer-pg \
  -e POSTGRES_PASSWORD=test docker.io/library/postgres:15-alpine
docker cp database/schema.sql dyzainer-pg:/tmp/schema.sql
docker cp database/seed.sql dyzainer-pg:/tmp/seed.sql
docker exec dyzainer-pg psql -U postgres -v ON_ERROR_STOP=1 -f /tmp/schema.sql
docker exec dyzainer-pg psql -U postgres -v ON_ERROR_STOP=1 -f /tmp/seed.sql
docker rm -f dyzainer-pg
```

На Supabase `auth` schema вже існує. Локальний Postgres отримує shim із `schema.sql`.

Демо-дані: 5 користувачів, 5 товарів, 20 варіантів, 5 зон друку, 5 дизайнів/шаблонів і демо-замовлення. Пароль усіх демо-користувачів: `DemoPass123!`. Деталі в `database/seed.sql` і `DEVELOPMENT.md`.

## Що не входить у контракт

- 3D/AR, нативні застосунки.
- Автоматичні виплати роялті.
- Багатокористувацький B2B-кабінет.
- Відгуки, рейтинги, обране, промокоди.
- Власне виробництво та склад.

Причини та деталі в `PRODUCT_SPEC.md`, розділ 2.3.

## Джерела

Матеріали команди в Google Drive: `Team_4_2026`, папки `Лаб-1`...`Лаб-8`, зокрема Product Vision v1.1, SRS, Requirements, NFR Specification, Product Backlog, Use Case Specification, User Roles, User Personas, ER Diagram, System Architecture Diagram, Seq: Order->Payment, Seq: Moderation.
