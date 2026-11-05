# Changelog

Усі зміни контракту «Дизайнер». Формат: [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/), версіонування: [Semantic Versioning](https://semver.org/lang/uk/).

## [Unreleased]

### Added

- Нічого.

### Changed

- Нічого.

### Fixed

- Нічого.

## [1.1.1] - 2026-11-05

### Changed

- Уточнено major-версію SvelteKit: 3 (фактичний scaffold frontend).

## [1.1.0] - 2026-11-05

### Added

- ADR-0006: SvelteKit 3 з гібридним SSR/SSG/CSR.

### Changed

- Frontend stack: React SPA → SvelteKit 3, Svelte 5, Vite, Fabric.js 6.
- Production API base URL: same-origin `/api` через SvelteKit server proxy; CORS у production не потрібен.
- Refresh cookie: `Path=/` для same-origin `/api/auth/*`.
- Frontend deploy: Cloudflare Workers замість статичного Cloudflare Pages.

## [1.0.1] - 2026-11-05

### Fixed

- Seed для `auth.users` тепер ініціалізує `confirmation_token`, `recovery_token`, `email_change_token_new` і `email_change`, бо hosted Supabase Auth не приймає `NULL` у цих колонках.

## [1.0.0] - 2026-11-05

### Added

- Product specification v1.0: ролі, FR, бізнес-правила, стани, NFR, інтеграції.
- OpenAPI 3.0.3: 78 path-ів, 93 операції, 135 схем.
- PostgreSQL 15 schema: 29 таблиць, RLS, тригери, версії дизайну.
- Seed: 5 демо-користувачів, 5 товарів, 20 варіантів, 5 дизайнів, демо-замовлення.
- ER-діаграми та правила цілісності.
- Free-tier deployment profile.
- Geometry contract: px, `pxPerMm`, `mockupPxPerMm`.
- 5 шрифтів із кирилицею та OFL-ліцензіями.
- 3 JSON-приклади payload-ів.
- Development guide: auth, CORS, cookies, Postman, міграції, DoD.
- Stubs для payment, delivery, print, email.
- Frontend route map.
- Test vectors.
