# AGENTS.md — des-docs

Це **контрактний** репозиторій проєкту «Дизайнер». Тут немає app-коду: тільки специфікація, OpenAPI, схема БД, seed, ER, ADR, приклади й шрифти.

`des-docs` — джерело істини для `des-backend` і `des-frontend`. Зміна API або схеми починається тут, а не в app-репозиторіях.

## Спочатку прочитай

- `README.md`
- `PRODUCT_SPEC.md`
- `openapi.yaml`
- `database/schema.sql`
- `database/seed.sql`
- `adr/0006-sveltekit-hybrid.md`
- `DEVELOPMENT.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`

## Порядок змін

Одна логічна зміна — один PR. Порядок:

1. `PRODUCT_SPEC.md`, якщо змінюється поведінка або бізнес-правило.
2. `openapi.yaml`.
3. `database/schema.sql` + план міграції.
4. `database/seed.sql`.
5. `examples/`, документація, `CHANGELOG.md`.

Не змінюй OpenAPI або schema тільки в app-репозиторії. Не редагуй опубліковані ADR; додавай новий ADR, який замінює потрібну частину.

## Команди

```bash
bun install
bun run check       # redocly lint + openapi-typescript
bun run build:docs  # dist/index.html
bun run preview:docs
```

`.tmp/` і `dist/` — generated, не комітити.

## CI

`.github/workflows/docs.yml`:

- `validate` — OpenAPI lint, schema + seed у чистому PostgreSQL, Markdown links;
- `build` — збірка HTML-документації.

Обидва jobs обов'язкові для PR.

## Правила

- Репозиторій публічний. Не додавай секрети, токени, приватні ключі, персональні дані.
- Seed має працювати і на hosted Supabase, і на локальній schema-stub. Оновлення auth token-колонок умовне.
- OpenAPI production server — same-origin `/api`; локально `http://localhost:8787`.
- Refresh cookie: `HttpOnly; Secure; SameSite=Lax; Path=/`.
- Не редагуй згенерований `.tmp/api.d.ts`.
- Не роби destructive schema-змін без міграційного плану.
- Не пуш у `main`: branch protection вимагає PR, `build` + `validate`, 1 review і CODEOWNER.
- Conventional Commits. Не роби force-push і не переписуй теги.

## Після merge

1. Постав tag `contract-vX.Y.Z`.
2. В app-репозиторіях онови copy:

```bash
# у des-backend
scripts/sync-contract.sh contract-vX.Y.Z
```

Поточна версія на 2026-11-05 — `contract-v1.1.2`; перевіряй останню:

```bash
git tag --list 'contract-*' | sort -V | tail -1
```
