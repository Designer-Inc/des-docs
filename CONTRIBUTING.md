# Як змінювати контракт

`des-docs` є джерелом істини для product spec, OpenAPI, схеми БД, seed, прикладів і тестових векторів. Зміна контракту починається тут, а не в `des-backend` або `des-frontend`.

## Правило одного PR

Один PR у `des-docs` має містити всі пов'язані зміни:

1. `PRODUCT_SPEC.md`, якщо змінилася поведінка або бізнес-правило.
2. `openapi.yaml`, якщо змінився API.
3. `database/schema.sql`, якщо змінилася модель даних.
4. `database/seed.sql`, якщо змінилися демо-дані.
5. `examples/`, якщо змінився payload.
6. `TEST_VECTORS.md`, якщо змінилися очікувані результати.
7. `CHANGELOG.md` у секції `Unreleased`.

Якщо PR змінює тільки текст або виправляє помилку, достатньо spec і changelog.

## Гілки та коміти

- Гілка: `docs/<коротка-назва>`, `api/<коротка-назва>`, `db/<коротка-назва>`, `contract/<коротка-назва>`.
- Коміти: Conventional Commits.
  - `docs: clarify checkout flow`
  - `api: add design versions endpoint`
  - `db: add mockup px per mm`
  - `contract!: remove legacy text object`
- `!` або `BREAKING CHANGE:` у тілі коміту позначає breaking change.

## Рев'ю

Мінімум два схвалення:

- Tech Lead: API, БД, сумісність.
- BA: поведінка, бізнес-правила, acceptance criteria.
- PM: додатково, якщо змінюються межі релізу або терміни.

`CODEOWNERS` має містити реальні GitHub handles. Поки що це шаблон.

## Версіонування

- `MAJOR`: breaking change для frontend або backend.
- `MINOR`: нові endpoint, поле, таблиця або сумісна поведінка.
- `PATCH`: виправлення тексту, прикладів, тестових векторів без зміни контракту.

Після мержу в `main`:

1. Оновити `CHANGELOG.md`.
2. Поставити тег `contract-vX.Y.Z`.
3. Повідомити обидві команди.
4. Оновити копії контракту в app-репозиторіях.

## Синхронізація з app-репозиторіями

Для семестрового проєкту:

- `des-backend` і `des-frontend` містять копії `openapi.yaml` і `database/schema.sql` з header `Synced from des-docs@contract-vX.Y.Z`.
- Копії не редагують вручну.
- Оновлення: PR у `des-docs`, tag, потім PR у кожному app-репозиторії.
- CI app-репозиторію перевіряє, що версія в header збігається з очікуваною.

## Заборонено

- Секрети, токени, `.env`, ключі LiqPay, Nova Poshta, Resend, R2.
- Реальні персональні дані клієнтів.
- Код застосунків, `node_modules`, `dist`.
- Пряме редагування `openapi.yaml` в app-репозиторіях.
- Зміна `schema.sql` без міграції після першого production-застосування.

## Перевірки перед merge

```bash
bun run check
docker run --rm -d --name des-docs-pg -e POSTGRES_PASSWORD=test docker.io/library/postgres:15-alpine
docker cp database/schema.sql des-docs-pg:/tmp/schema.sql
docker cp database/seed.sql des-docs-pg:/tmp/seed.sql
docker exec des-docs-pg psql -U postgres -v ON_ERROR_STOP=1 -f /tmp/schema.sql
docker exec des-docs-pg psql -U postgres -v ON_ERROR_STOP=1 -f /tmp/seed.sql
docker rm -f des-docs-pg
```

GitHub Actions робить те саме автоматично.
