# Схема даних «Дизайнер»

Повний DDL: `schema.sql`. Цей файл пояснює призначення таблиць і зв'язки. Схема готова для Supabase PostgreSQL 15+.

## Огляд

29 таблиць у п'яти групах:

| Група | Таблиці |
| --- | --- |
| Користувачі та файли | `users`, `company_profiles`, `files` |
| Каталог | `categories`, `products`, `product_variants`, `print_areas`, `product_images`, `discount_tiers` |
| Дизайни | `designs`, `design_versions`, `design_files`, `personalization_lists` |
| Замовлення | `orders`, `order_items`, `payments`, `payment_events`, `invoices`, `print_jobs`, `print_files`, `shipments`, `order_status_history`, `author_bonuses` |
| Модерація та службові | `moderation_logs`, `design_reports`, `notifications`, `legal_acceptances`, `audit_logs`, `idempotency_keys` |

## Конвенції

- ID: UUID v4. Людські номери: `orders.order_number` (`ORD-YYYYMMDD-NNNNN`), `invoices.number` (`INV-YYYY-NNNNNN`).
- Гроші: `integer` у копійках, суфікс `_minor`. Ніяких `numeric` для грошей.
- Час: `timestamptz` у UTC. `created_at` і `updated_at` автоматичні.
- Файли: `files` є єдиним реєстром. Інші таблиці посилаються на `file_id`, не на URL.
- JSON: `designs.canvas` це Fabric.js JSON; `invoices.company_snapshot` це snapshot реквізитів; `audit_logs.before/after` це різниця станів.
- М'яке видалення: `users.deleted_at`, `designs.deleted_at`, `files.deleted_at`. Замовлення не видаляються.
- RLS: увімкнено на всіх таблицях. Backend використовує `service_role` і перевіряє права в Hono. Прямий доступ з `anon`/`authenticated` обмежений політиками.

## Діаграми

### Користувачі, файли, дизайни

```mermaid
erDiagram
  USERS {
    uuid id PK
    text email UK
    text full_name
    user_role role
    user_status status
    text locale
    uuid avatar_file_id FK
  }
  COMPANY_PROFILES {
    uuid user_id PK
    text company_name
    text legal_name
    text tax_id
    text iban
    text bank_name
  }
  FILES {
    uuid id PK
    uuid owner_id FK
    file_kind kind
    file_status status
    file_visibility visibility
    text bucket
    text storage_path
    text mime_type
    bigint size_bytes
    int width_px
    int height_px
    int dpi
  }
  DESIGNS {
    uuid id PK
    uuid author_id FK
    uuid base_product_id FK
    uuid print_area_id FK
    uuid forked_from_id FK
    uuid current_version_id FK
    text title
    text description
    text_array tags
    jsonb canvas
    design_status status
    numeric author_bonus_percent
    timestamptz rights_confirmed_at
    timestamptz published_at
  }
  DESIGN_VERSIONS {
    uuid id PK
    uuid design_id FK
    int version_number
    design_version_source source
    design_version_status status
    jsonb canvas
    uuid base_product_id FK
    uuid print_area_id FK
    uuid preview_file_id FK
    timestamptz rights_confirmed_at
    numeric author_bonus_percent
    timestamptz published_at
  }
  DESIGN_FILES {
    uuid design_id PK
    uuid file_id PK
    design_file_role role PK
  }

  USERS ||--o| COMPANY_PROFILES : "has"
  USERS ||--o{ FILES : "owns"
  USERS ||--o{ DESIGNS : "authors"
  DESIGNS ||--o{ DESIGNS : "forked_from"
  DESIGNS ||--o{ DESIGN_VERSIONS : "has"
  DESIGNS ||--o| DESIGN_VERSIONS : "current_version"
  FILES ||--o{ DESIGN_VERSIONS : "preview"
  DESIGNS ||--o{ DESIGN_FILES : "has"
  FILES ||--o{ DESIGN_FILES : "used_in"
```

### Каталог

```mermaid
erDiagram
  FILES {
    uuid id PK
    text mime_type
  }
  CATEGORIES {
    uuid id PK
    text name
    text slug UK
    int position
    boolean is_active
  }
  PRODUCTS {
    uuid id PK
    uuid category_id FK
    text name
    text slug UK
    int base_price_minor
    char currency
    product_production_method production_method
    text fabric_type
    boolean is_active
    boolean is_customizable
  }
  PRODUCT_VARIANTS {
    uuid id PK
    uuid product_id FK
    text sku UK
    text color_name
    text color_hex
    text size
    int price_delta_minor
    int stock_quantity
    uuid mockup_file_id FK
  }
  PRINT_AREAS {
    uuid id PK
    uuid product_id FK
    text name
    numeric width_mm
    numeric height_mm
    numeric offset_x_mm
    numeric offset_y_mm
    numeric mockup_px_per_mm
    int min_dpi
  }
  PRODUCT_IMAGES {
    uuid id PK
    uuid product_id FK
    uuid file_id FK
    int position
  }
  DISCOUNT_TIERS {
    uuid id PK
    uuid product_id FK
    int min_quantity
    numeric discount_percent
    boolean is_active
  }

  CATEGORIES ||--o{ PRODUCTS : "contains"
  PRODUCTS ||--o{ PRODUCT_VARIANTS : "has"
  PRODUCTS ||--o{ PRINT_AREAS : "has"
  PRODUCTS ||--o{ PRODUCT_IMAGES : "has"
  PRODUCTS ||--o{ DISCOUNT_TIERS : "has"
  FILES ||--o{ PRODUCT_IMAGES : "image"
  FILES ||--o{ PRODUCT_VARIANTS : "mockup"
```

### Замовлення, оплата, друк, доставка

```mermaid
erDiagram
  PRODUCTS {
    uuid id PK
    text name
  }
  PRODUCT_VARIANTS {
    uuid id PK
    text color_name
    text size
  }
  DESIGNS {
    uuid id PK
    text title
  }
  DESIGN_VERSIONS {
    uuid id PK
    uuid design_id FK
    int version_number
    design_version_source source
    design_version_status status
  }
  FILES {
    uuid id PK
    text mime_type
  }
  ORDERS {
    uuid id PK
    text order_number UK
    uuid user_id FK
    order_status status
    payment_status payment_status
    payment_method payment_method
    text customer_name
    text customer_email
    text customer_phone
    text delivery_city_id
    text delivery_warehouse_id
    int delivery_cost_minor
    int subtotal_minor
    int discount_minor
    int total_minor
    char currency
    timestamptz stock_released_at
  }
  ORDER_ITEMS {
    uuid id PK
    uuid order_id FK
    int position
    uuid product_id FK
    uuid variant_id FK
    uuid design_id FK
    uuid design_version_id FK
    text product_name
    text variant_name
    int unit_price_minor
    int quantity
    numeric discount_percent
    boolean is_sample
    uuid personalization_list_id FK
    int line_subtotal_minor
    int line_discount_minor
    int line_total_minor
  }
  PERSONALIZATION_LISTS {
    uuid id PK
    uuid user_id FK
    uuid file_id FK
    text_array names
    int row_count
    personalization_status status
  }
  PAYMENTS {
    uuid id PK
    uuid order_id FK
    payment_provider provider
    payment_method method
    payment_status status
    int amount_minor
    text provider_transaction_id
  }
  PAYMENT_EVENTS {
    uuid id PK
    uuid payment_id FK
    payment_provider provider
    text event_id
    jsonb payload
    text status
  }
  INVOICES {
    uuid id PK
    uuid order_id FK
    text number UK
    invoice_status status
    int total_minor
    timestamptz due_at
    uuid pdf_file_id FK
    jsonb company_snapshot
  }
  PRINT_JOBS {
    uuid id PK
    uuid order_id FK
    print_job_status status
    int attempts
    text last_error
  }
  PRINT_FILES {
    uuid id PK
    uuid order_item_id FK
    uuid print_job_id FK
    print_file_kind kind
    int personalization_index
    text personalized_name
    uuid file_id FK
    print_file_status status
  }
  SHIPMENTS {
    uuid id PK
    uuid order_id FK
    text provider
    text tracking_number UK
    shipment_status status
  }
  ORDER_STATUS_HISTORY {
    uuid id PK
    uuid order_id FK
    order_status from_status
    order_status to_status
    uuid changed_by FK
  }
  AUTHOR_BONUSES {
    uuid id PK
    uuid order_item_id FK
    uuid author_id FK
    uuid design_id FK
    int amount_minor
    numeric percent
    bonus_status status
  }

  ORDERS ||--o{ ORDER_ITEMS : "contains"
  PRODUCTS ||--o{ ORDER_ITEMS : "ordered_product"
  PRODUCT_VARIANTS ||--o{ ORDER_ITEMS : "ordered_variant"
  DESIGNS ||--o{ ORDER_ITEMS : "ordered_design"
  DESIGN_VERSIONS ||--o{ ORDER_ITEMS : "ordered_version"
  PERSONALIZATION_LISTS ||--o{ ORDER_ITEMS : "applied_to"
  ORDERS ||--o{ PAYMENTS : "paid_by"
  PAYMENTS ||--o{ PAYMENT_EVENTS : "receives"
  ORDERS ||--o| INVOICES : "invoiced_by"
  ORDERS ||--o{ PRINT_JOBS : "produces"
  PRINT_JOBS ||--o{ PRINT_FILES : "generates"
  ORDER_ITEMS ||--o{ PRINT_FILES : "has"
  ORDERS ||--o| SHIPMENTS : "ships"
  ORDERS ||--o{ ORDER_STATUS_HISTORY : "logs"
  ORDER_ITEMS ||--o| AUTHOR_BONUSES : "accrues"
  FILES ||--o{ INVOICES : "pdf"
  FILES ||--o{ PRINT_FILES : "artifact"
  FILES ||--o{ PERSONALIZATION_LISTS : "source"
```

### Модерація, сповіщення, аудит

```mermaid
erDiagram
  USERS {
    uuid id PK
    text email
  }
  DESIGNS {
    uuid id PK
    text title
  }
  ORDERS {
    uuid id PK
    text order_number
  }
  MODERATION_LOGS {
    uuid id PK
    moderation_target target_type
    uuid design_id FK
    uuid order_id FK
    uuid moderator_id FK
    moderation_action action
    text reason
    text notes
  }
  DESIGN_REPORTS {
    uuid id PK
    uuid design_id FK
    uuid reporter_id FK
    report_reason reason
    text details
    report_status status
    uuid resolved_by FK
    report_action resolution_action
  }
  NOTIFICATIONS {
    uuid id PK
    uuid user_id FK
    notification_type type
    text title
    text body
    jsonb data
    timestamptz read_at
  }
  LEGAL_ACCEPTANCES {
    uuid id PK
    uuid user_id FK
    consent_type consent_type
    text document_version
    consent_context context_type
    uuid context_id
  }
  AUDIT_LOGS {
    uuid id PK
    uuid actor_id FK
    text action
    text entity_type
    uuid entity_id
    jsonb before
    jsonb after
  }
  IDEMPOTENCY_KEYS {
    text key PK
    uuid user_id FK
    text endpoint
    text request_hash
    int response_status
    jsonb response_body
  }

  USERS ||--o{ MODERATION_LOGS : "moderates"
  DESIGNS ||--o{ MODERATION_LOGS : "reviewed"
  ORDERS ||--o{ MODERATION_LOGS : "reviewed"
  USERS ||--o{ DESIGN_REPORTS : "reports"
  DESIGNS ||--o{ DESIGN_REPORTS : "reported"
  USERS ||--o{ NOTIFICATIONS : "receives"
  USERS ||--o{ LEGAL_ACCEPTANCES : "accepts"
  USERS ||--o{ AUDIT_LOGS : "acts"
  USERS ||--o{ IDEMPOTENCY_KEYS : "requests"
```

## Правила цілісності

1. `designs.print_area_id` і `designs.base_product_id` мають складений FK. Зона друку обов'язково належить обраному товару.
2. `order_items.variant_id` і `order_items.product_id` мають складений FK. Варіант обов'язково належить товару.
3. `order_items.line_subtotal_minor`, `line_discount_minor`, `line_total_minor` є generated columns. Суми не можна розійтися з ціною, кількістю та знижкою.
4. `orders.total_minor` є generated column. Він завжди дорівнює `subtotal - discount + delivery`.
5. `recalculate_order_totals` перераховує `subtotal` і `discount` після будь-якої зміни `order_items` або `delivery_cost_minor`.
6. `validate_personalization_count` не дає створити позицію, де кількість імен не дорівнює кількості товару.
7. `enforce_design_publish_fields` не дає опублікувати дизайн без назви, canvas, підтвердження прав.
8. `prevent_last_admin_removal` не дає забрати роль або заблокувати останнього активного адміністратора.
9. `prevent_user_privilege_escalation` не дає користувачу змінити собі роль, статус або email через прямий доступ.
10. `payments_status_sync` переводить замовлення в `paid` або `refunded` на основі статусу платежу.
11. `order_status_history` пише кожен перехід статусу замовлення.
12. `print_jobs_active_uq` не дає мати два активні job для одного замовлення.
13. `protect_design_fields` не дає прямому користувачу змінити `author_bonus_percent`, лічильники або `published_at`.
14. `design_versions` має унікальну пару `(design_id, version_number)`. Версія без хоча б одного canvas-об'єкта не створюється.
15. `prevent_design_version_content_change` блокує зміну canvas, товару, зони друку, preview, прав і винагороди після `pending_moderation`.
16. `prevent_design_content_change` блокує зміну canvas, товару, зони друку, fork-посилання і винагороди після `pending_moderation`. Опублікований дизайн не повертається в редагування.
17. `protect_order_item_snapshot` робить позицію замовлення незмінною після створення: товар, варіант, ціна, кількість, знижка, версія дизайну і персоналізація.
18. `validate_order_item_design_version` перевіряє, що версія належить обраному дизайну і має статус `published` або `pending_moderation`.
19. `sync_design_current_version` після публікації author-версії оновлює `designs.current_version_id` і статус дизайну.
20. `designs` не може мати статус `published` без `current_version_id`.
21. `files.locked_at` фіксує файли, використані в незмінній версії. `DELETE /files/{id}` і cleanup job не видаляють locked-файли.

## Canvas contract

`designs.canvas` це Fabric.js JSON. Воно містить до 20 об'єктів:

- `image`: кілька зображень, кожне з `fileId`, `left`, `top`, `width`, `height`, `scaleX`, `scaleY`, `angle`, `flipX`, `flipY`, `opacity`, `zIndex`;
- `textbox`: `text`, `fontFamily` (5 hardcoded id), `fontSize`, `fontWeight`, `fontStyle`, `fill`, `textAlign`, `lineHeight`, `charSpacing`, `padding`, `splitByGrapheme` плюс ті самі transform-поля;
- `shape`: rect, circle, triangle, line, path.

`angle` приймає -360...360 і нормалізується до [0, 360). Усі `left`, `top`, `width`, `height`, `fontSize`, `padding` задані в пікселях canvas. `print_areas.mockup_px_per_mm` калібрує зону друку на mockup-зображенні: `mockupPx = mm * mockup_px_per_mm`. Backend друку рендерить ті самі Fabric.js об'єкти через Fabric.js + node-canvas у Node-сумісному worker-і або headless browser, тому перенос тексту й поворот збігаються з прев'ю.

## Стартові дані

`schema.sql` додає три глобальні знижки: 10 шт = 5%, 50 шт = 10%, 100 шт = 15%. Вони мають `product_id = null` і перекриваються товарними tier-ами. Інших демо-даних немає.

## Нотатки щодо міграцій

- Це fresh-install snapshot. Не редагуйте його після першого застосування в production.
- Кожна наступна зміна: `supabase/migrations/NNNN_description.sql`, append-only.
- Для локальної розробки: `supabase db reset`, потім застосуйте `schema.sql`.
- Для Supabase: перевірте, що `auth.users` існує до запуску. У Supabase він існує завжди.
- Якщо змінюєте enum, додавайте значення через `ALTER TYPE ... ADD VALUE`, не перестворюйте тип.
