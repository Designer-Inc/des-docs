# План підготовки до розробки

Це не готові репозиторії, а чек-лист і домовленості, які треба закрити перед стартом. Мета: frontend і backend працюють незалежно, без щоденних питань «а як малось на увазі».

## 1. Локальний запуск

Мінімальний порядок:

```bash
# 1. Supabase hosted
bunx supabase link --project-ref <ref>
bunx supabase db push --remote

# 2. Backend
bun install
bun run dev          # wrangler dev, http://localhost:8787

# 3. Frontend
bun install
bun run dev          # SvelteKit/Vite, http://localhost:5173
```

Frontend проксіює `/api` на `http://localhost:8787`, тому в коді завжди відносний шлях `/api/...`, без абсолютних URL.

## 2. Авторизація і JWT

- Access token: Supabase JWT у `Authorization: Bearer <token>`.
- `sub` у токені це UUID користувача. Не використовуйте `user_metadata` для ролі.
- Backend перевіряє підпис токена через `SUPABASE_JWT_SECRET` (HS256) або `supabase.auth.getUser(token)`.
- Після перевірки backend читає `public.users` за `sub` і перевіряє `status='active'` та `deleted_at is null`.
- Роль береться тільки з `public.users.role`. Кешуйте її максимум 60 секунд, якщо хочете зменшити кількість запитів.
- Якщо користувача заблоковано, повертайте 403, навіть якщо JWT ще валідний.
- Access token живе 15 хвилин. У Supabase Auth виставте JWT expiry 900 секунд.
- Refresh token живе 7 діб. Він у HttpOnly cookie, не в localStorage.

Псевдокод middleware:

```ts
const token = req.headers.get("authorization")?.replace("Bearer ", "");
if (!token) return jsonError(401, "UNAUTHORIZED");
const payload = await verifyJwt(token, env.SUPABASE_JWT_SECRET);
const user = await db.users.find(payload.sub);
if (!user || user.status !== "active" || user.deleted_at) {
  return jsonError(403, "FORBIDDEN");
}
c.set("user", user);
```

## 3. Cookies і CORS

Refresh cookie:

```text
refresh_token=<token>; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=604800
```

- На localhost без HTTPS `Secure` треба вимкнути або запускати HTTPS через `mkcert`. Інакше браузер не збереже cookie.
- `Path=/` потрібен, бо браузер ходить через `/api/auth/*`, а SvelteKit проксіює на `/auth/*`. Cookie same-origin, тому refresh працює і в браузері, і в SSR.
- Не використовуйте cross-site `api.*` + `SameSite=None`: це залежить від третіх сторін і нестабільно.
- Frontend робить `fetch(..., { credentials: "include" })` для `/api/auth/*`.

CORS:

- Production: SvelteKit server проксіює `/api/*` на Worker, тому frontend і API same-origin. CORS не потрібен.
- Local: Vite проксіює `/api` на `http://localhost:8787`; прямі запити до API дозволені з `http://localhost:5173` і `http://localhost:4173`.
- Заборонено `Access-Control-Allow-Origin: *` разом із `credentials`.
- Дозволені headers: `Authorization`, `Content-Type`, `Idempotency-Key`, `X-Request-Id`.
- Дозволені methods: `GET`, `POST`, `PATCH`, `PUT`, `DELETE`, `OPTIONS`.
- `Access-Control-Allow-Credentials: true`, `Access-Control-Max-Age: 600`.

CSRF:

- Мутації використовують bearer token, не cookie, тому CSRF-ризик низький.
- `/auth/refresh` і `/auth/logout` перевіряють `Origin` або `Referer` проти allowlist.
- `SameSite=Lax` достатньо для MVP.

## 4. Postman і mock

Так, `openapi.yaml` можна імпортувати в Postman як OpenAPI 3.0. Postman створить колекцію запитів. Але це не означає, що одразу буде повноцінний mock.

- Postman може згенерувати mock із OpenAPI. Точні тіла гарантовані лише там, де є response examples; для складних payload-ів використовуйте `examples/` або MSW.
- Без прикладів Postman згенерує placeholder-и зі схеми, часто з `string`/`0`.
- Postman mock статичний: він не перевіряє JWT, не тримає стан, не робить upload, не приймає webhook, не міняє статуси замовлень.
- Для stateful-сценаріїв використовуйте локальний Hono stub або MSW/Prism. Postman підходить для read-only перевірок і ручних запитів.
- Імпортуйте саме `openapi.yaml`, а не `des-api-example/openapi.yaml`. Це різні проєкти.

## 5. Джерела даних для frontend

Поки backend не готовий:

- `examples/*.json` для ручних запитів.
- MSW handlers на основі `openapi.yaml`.
- Seed-база для реальних ID і ролей.

Демо-користувачі після `seed.sql`:

| Email | Пароль | Роль |
| --- | --- | --- |
| `customer@demo.dyzainer.ua` | `DemoPass123!` | customer |
| `author@demo.dyzainer.ua` | `DemoPass123!` | customer + авторські дизайни |
| `moderator@demo.dyzainer.ua` | `DemoPass123!` | moderator |
| `admin@demo.dyzainer.ua` | `DemoPass123!` | admin |
| `b2b@demo.dyzainer.ua` | `DemoPass123!` | customer + company profile |

## 6. Геометрія canvas

Перед першим кодом конструктора зафіксуйте:

- усі об'єкти в пікселях canvas, `unit: "px"`;
- `DesignCanvas.pxPerMm` і `PrintArea.mockupPxPerMm` не взаємозамінні;
- `mm = px / pxPerMm`;
- `printPx = mm × 300 / 25.4`;
- `mockupPx = mm × mockupPxPerMm`;
- `angle` у градусах, нормалізується до [0, 360);
- `fontSize` і `padding` у пікселях canvas;
- `charSpacing` у 1/1000 em;
- жоден об'єкт після scale/rotate/flip не виходить за межі зони друку.

Деталі: `PRODUCT_SPEC.md`, розділ 5.2.1.

## 7. Міграції

- `schema.sql` це fresh-install snapshot. Після першого застосування його не редагують.
- Кожна зміна: `supabase/migrations/NNNN_description.sql`, append-only.
- Перед merge: `supabase db reset`, `schema.sql`, `seed.sql`, тести RLS.
- Enum-и розширюються через `ALTER TYPE ... ADD VALUE`, не перестворюються.

## 8. Definition of Done для коду

Кожен PR:

- код проходить `oxlint` і `tsc --noEmit`;
- є unit або integration тест на нову бізнес-логіку;
- OpenAPI оновлений, якщо змінився контракт;
- міграція додана, якщо змінилася БД;
- `npx @redocly/cli lint openapi.yaml` зелений;
- staging deploy успішний;
- перевірений хоча б один реальний сценарій через UI або curl;
- немає секретів у коді або логах.

## 9. GitHub Actions

Це можна закрити в репозиторіях, без окремого інструмента:

- Backend: lint, typecheck, unit/integration tests, OpenAPI lint, `supabase db reset` + schema + seed, deploy staging.
- Frontend: lint, typecheck, build, unit tests, Playwright smoke, перевірка згенерованих типів з OpenAPI, deploy Pages.
- Contract: `openapi-typescript` генерує типи, diff не порожній без зміни контракту.
- Scheduled: keepalive, backup, print worker.

## 10. Readiness checklist

- [x] Product spec і межі MVP/v1.1
- [x] OpenAPI з помилками, auth, пагінацією, idempotency
- [x] PostgreSQL schema, RLS, тригери, версії
- [x] Seed з демо-користувачами, товарами й шаблонами
- [x] Явна геометрія canvas і mockup
- [x] 5 шрифтів із кирилицею
- [x] 3 payload-приклади
- [x] Auth, CORS, cookies
- [x] Заглушки payment/delivery/print/email
- [x] Frontend route map
- [x] Test vectors
- [ ] Каркаси репозиторіїв (свідомо відкладено)
- [ ] GitHub Actions workflows (робити в репозиторіях)
- [ ] Реальні LiqPay, Nova Poshta, друкарня (після погодження)

## 11. Що залишається заглушками

- Payment: LiqPay adapter за інтерфейсом, sandbox або stub.
- Delivery: Nova Poshta adapter за інтерфейсом, stub з 3 містами.
- Print: stub renderer, без CMYK/bleed, доки немає партнерської друкарні.
- Email: console/DB у dev, Resend у staging.

Деталі: `STUBS.md`.
