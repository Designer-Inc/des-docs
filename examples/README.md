# Приклади payload-ів

Три приклади для frontend, Postman і майбутніх MSW-фікстур:

| Файл | Для чого |
| --- | --- |
| `design-canvas.json` | Повний Fabric.js canvas із 2 textbox, 1 image і 1 shape. Показує `unit: px`, `pxPerMm`, `angle`, `zIndex` |
| `order-create.json` | Тіло `POST /orders`: товар, дизайн, доставка, оплата, disclaimer |
| `product-aggregate.json` | Тіло `POST /admin/products`: товар, варіанти, зона друку з `mockupPxPerMm`, знижки |

## Важливо

- `variantId` у `order-create.json` відповідає seed-варіанту `TS-BLK-M` (`44444444-4444-4444-4444-444444444444`). Для інших товарів беріть ID з `GET /products/{id}`.
- `designId` у `order-create.json` відповідає seed-дизайну `Minimal Black`.
- `disclaimerVersion` має дорівнювати `GET /config.designDisclaimerVersion`.
- `image.fileId` у `design-canvas.json` це плейсхолдер. Реальний файл має бути завантажений через `POST /uploads`.
- Для Postman Mock Server цих прикладів достатньо для read-only відповідей. Для stateful-сценаріїв (замовлення → оплата → webhook) потрібен локальний Hono stub або MSW.
