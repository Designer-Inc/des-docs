# ADR-0002: Незмінні версії дизайну

- Статус: accepted
- Дата: 2026-11-05

## Контекст

Макет може змінитися між замовленням і друком. Якщо друк читає `designs.canvas`, клієнт отримає не той макет. Опублікований дизайн також не має редагуватися, інакше попередні замовлення стають невідтворюваними.

## Рішення

- `design_versions` зберігає незмінний знімок canvas, товару, зони друку, прав і відсотка винагороди.
- `designs.current_version_id` вказує на опубліковану версію.
- `order_items.design_version_id` фіксує версію, з якої друкується позиція.
- `design_versions.source` розрізняє `author` і `order_snapshot`.
- Після `pending_moderation` версія незмінна. Після `pending_moderation` дизайн незмінний.
- `order_items` після створення не змінюється.
- Print worker читає тільки `design_versions` через `order_items.design_version_id`.

## Наслідки

- Старі замовлення не залежать від нових змін дизайну.
- Опублікований макет не редагується. Для зміни створюється новий дизайн через fork.
- Потрібні тригери `prevent_design_content_change`, `prevent_design_version_content_change`, `protect_order_item_snapshot`.
- Потрібен `files.locked_at`, щоб не видалити artwork, на який посилається версія.
