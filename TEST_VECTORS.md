# Тестові вектори

Ці таблиці потрібні, щоб backend, frontend і QA рахували однаково. Гроші в копійках, кути в градусах, геометрія canvas у пікселях.

## 1. Знижки та суми

Базова ціна 50 000 копійок (500 ₴), глобальні знижки: 10+ = 5%, 50+ = 10%, 100+ = 15%.

| Кількість | Знижка | Проміжна сума | Знижка, коп. | До сплати, коп. |
| --- | --- | --- | --- | --- |
| 1 | 0% | 50 000 | 0 | 50 000 |
| 9 | 0% | 450 000 | 0 | 450 000 |
| 10 | 5% | 500 000 | 25 000 | 475 000 |
| 49 | 5% | 2 450 000 | 122 500 | 2 327 500 |
| 50 | 10% | 2 500 000 | 250 000 | 2 250 000 |
| 99 | 10% | 4 950 000 | 495 000 | 4 455 000 |
| 100 | 15% | 5 000 000 | 750 000 | 4 250 000 |
| 500 | 15% | 25 000 000 | 3 750 000 | 21 250 000 |

Замовлення: subtotal 500 000, discount 25 000, delivery 8 000, total 483 000.

## 2. Округлення

| Проміжна сума | Відсоток | Точне значення | Очікування |
| --- | --- | --- | --- |
| 33 333 | 5% | 1 666.65 | 1 667 |
| 100 | 2.5% | 2.5 | 3 |
| 1 | 50% | 0.5 | 1 |
| 3 | 33.33% | 0.9999 | 1 |
| 2 | 25% | 0.5 | 1 |
| 1 | 49% | 0.49 | 0 |

Правило: half-up до цілого числа копійок. Floating point не використовується.

## 3. DPI

Формула: `DPI = imageWidthPx / (printedWidthMm / 25.4)`.

| Ширина зображення, px | Ширина друку, мм | DPI | Поведінка |
| --- | --- | --- | --- |
| 1000 | 100 | 254.0 | OK |
| 1000 | 169.3 | 150.0 | OK |
| 1200 | 200 | 152.4 | OK |
| 2000 | 300 | 169.3 | OK |
| 1000 | 200 | 127.0 | Warning |
| 1000 | 300 | 84.7 | Warning |
| 851 | 300 | 72.1 | Warning |
| 850 | 300 | 72.0 | Warning на межі |
| 849 | 300 | 71.9 | Block |
| 500 | 300 | 42.3 | Block |

Пороги: `< 72` block, `72...149` warning, `>= 150` OK.

## 4. Геометрія canvas

| Вхід | Формула | Результат |
| --- | --- | --- |
| 300 мм, `pxPerMm=3.7795` | 300 × 3.7795 | 1133.85 px |
| 400 мм, `pxPerMm=3.7795` | 400 × 3.7795 | 1511.8 px |
| 100 px, `pxPerMm=3.7795` | 100 / 3.7795 | 26.46 мм |
| 26.46 мм, 300 DPI | 26.46 × 300 / 25.4 | 312.5 print px |
| 50 мм, `mockupPxPerMm=2.5` | 50 × 2.5 | 125 px mockup |
| 534 px, `pxPerMm=3.7795` | 534 / 3.7795 | 141.29 мм |
| 141.29 мм, 300 DPI | 141.29 × 300 / 25.4 | 1668.8 print px |
| `angle=370` | normalize | 10° |
| `angle=-10` | normalize | 350° |

## 5. Персоналізація

| Кількість товару | Імен у списку | Очікування |
| --- | --- | --- |
| 5 | 4 | 422 `PERSONALIZATION_MISMATCH` |
| 5 | 5 | OK |
| 5 | 0 | 422 |
| 5 | 501 | 422 |
| 50 | 50 | OK |

Перевірка найдовшого імені:

- `fits=true`, якщо найдовше ім'я вміщується в textbox при поточному шрифті.
- `recommendedFontSizePt` не менше 8.
- Якщо навіть 8 pt не вміщується, `fits=false`, ім'я в `overflowNames`.

## 6. Статуси

Дизайн:

| З | До | Дозволено |
| --- | --- | --- |
| draft | pending_moderation | Так |
| pending_moderation | published | Так, moderator/admin |
| pending_moderation | rejected | Так, moderator/admin |
| rejected | pending_moderation | Так, автор |
| published | hidden | Так, moderator/admin |
| hidden | published | Так, moderator/admin |
| published | draft | Ні |
| pending_moderation | draft | Ні |

Замовлення:

| З | До | Дозволено |
| --- | --- | --- |
| pending_payment | paid | Так, payment webhook |
| pending_payment | cancelled | Так, покупець |
| paid | on_moderation | Так, custom design |
| paid | in_production | Так, усі дизайни published |
| on_moderation | in_production | Так, moderator/admin |
| on_moderation | refunded | Так, moderator reject |
| in_production | ready_to_ship | Так, admin |
| ready_to_ship | shipped | Так, admin |
| shipped | delivered | Так, carrier/admin |
| paid/on_moderation/in_production | refunded | Так, admin |
| ready_to_ship | cancelled | Ні |

Оплата:

| З | До | Дозволено |
| --- | --- | --- |
| pending | success | Так, webhook |
| pending | failed | Так, webhook |
| failed | pending | Так, retry |
| success | refunded | Так, admin |

Друк:

| З | До | Дозволено |
| --- | --- | --- |
| queued | processing | Так, worker |
| processing | ready | Так |
| processing | failed | Так |
| failed | queued | Так, retry |

## 7. Версійність

| Сценарій | Очікування |
| --- | --- |
| Опублікований дизайн замовлено | `designVersionId = current_version_id` |
| Приватна чернетка власника замовлена | Створюється `order_snapshot`, замовлення `on_moderation` |
| Чужа чернетка замовлена | 404 |
| `pending_moderation` замовлено | 409 `DESIGN_NOT_ORDERABLE` |
| `hidden`/`archived` замовлено | 409 `DESIGN_NOT_ORDERABLE` |
| Зміна canvas опублікованого дизайну | DB error |
| Зміна canvas опублікованої версії | DB error |
| Зміна `design_version_id` у замовленні | DB error |
| Видалення файлу, залученого у версію | 409 |
| Старе замовлення після fork | Старий `designVersionId` не змінюється |

## 8. Авторизація

| Сценарій | Очікування |
| --- | --- |
| Немає токена | 401 |
| Прострочений токен | 401 |
| Заблокований користувач | 403 |
| Customer на `/admin/*` | 403 |
| Moderator на `/admin/users` | 403 |
| Admin на `/admin/users` | 200 |
| Чуже замовлення | 404 |
| Чужий дизайн | 404 |
| Чужий файл | 404 |
| Staff на чуже замовлення | 200 |

## 9. Idempotency

| Сценарій | Очікування |
| --- | --- |
| Той самий `Idempotency-Key` і тіло | Той самий response |
| Той самий ключ, інше тіло | 409 |
| Ключ старший 24 год | Новий response |
| Два однакові payment webhook | Один `payment_events`, один платіж |
| Два однакові `POST /orders` | Одне замовлення |

## 10. Пагінація

| Запит | Очікування |
| --- | --- |
| `page=1&limit=24` | 24 або менше, `page=1` |
| `page=0` | 400 |
| `limit=101` | 400 |
| `limit=100` | OK |
| Порожній результат | `total=0`, `hasMore=false` |
| Остання сторінка | `hasMore=false` |

## 11. Upload

| Файл | Очікування |
| --- | --- |
| PNG 5 МБ, 1000×1000 | OK |
| PNG 21 МБ | 413 |
| SVG 2 МБ | OK |
| AI 49 МБ | OK |
| AI 51 МБ | 413 |
| CSV 4 МБ | OK |
| CSV 6 МБ | 413 |
| `.exe`, перейменований у `.png` | 415 |
| SVG із зовнішнім `<script>` | 422 |
| Зображення 999×1000 | 422 |
