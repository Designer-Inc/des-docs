# Шрифти «Дизайнер»

П'ять шрифтів із підтримкою кирилиці та латиниці. Усі файли статичні TTF, згенеровані з Google Fonts variable-шрифтів через `fonttools varLib.instancer` у вагах 400 і 700. Ліцензія кожного шрифту: SIL Open Font License 1.1, файли `OFL.txt` лежать поруч.

| ID | Family | Стилі | Файли |
| --- | --- | --- | --- |
| `inter` | Inter | 400, 700, italic | `inter/` |
| `montserrat` | Montserrat | 400, 700, italic | `montserrat/` |
| `pt_serif` | PT Serif | 400, 700, italic | `pt_serif/` |
| `bitter` | Bitter | 400, 700, italic | `bitter/` |
| `caveat` | Caveat | 400, 700 | `caveat/` |

## Використання

1. Завантажте файли в Supabase Storage `public-assets/fonts/<id>/...` або віддайте їх із Cloudflare Pages за тим самим шляхом.
2. `GET /config` має повернути `Font` з `files[]`, де кожен файл має `url`, `weight` і `style`. Маніфест: `fonts.json`.
3. Frontend підключає `@font-face` для кожної пари `weight`/`style`.
4. Print worker викликає `registerFont` для тих самих файлів. Не використовуйте інші файли або синтетичний italic, інакше перенос тексту й метрики розійдуться з прев'ю.
5. `Caveat` не має italic-файлу. Для нього `fontStyle=italic` заборонений або рендериться як normal; краще обмежити в UI.

## Важливо

- Не перейменовуйте family. CSS names: `Inter`, `Montserrat`, `PT Serif`, `Bitter`, `Caveat`.
- Не видаляйте `OFL.txt` при публікації.
- Якщо потрібна вага, якої немає (500, 600), або додайте статичний інстанс, або дозвольте браузеру синтезувати її. Для друку краще додати окремий файл.
