# ADR-0004: Геометрія canvas у пікселях

- Статус: accepted
- Дата: 2026-11-05

## Контекст

Canvas, mockup товару і друк використовують різні масштаби. Якщо frontend і backend по-різному зрозуміють `left`, `top`, `width`, `height`, макет з'їде або зміниться розмір. Окремо потрібно знати, де зона друку лежить на фото товару.

## Рішення

- Усі координати й розміри об'єктів на canvas задаються в пікселях canvas.
- `DesignCanvas.unit = "px"`.
- `mm = px / pxPerMm`.
- `printPx = mm * 300 / 25.4`.
- `mockupPx = mm * mockupPxPerMm`.
- `PrintArea.offsetXMm` і `offsetYMm` це зсув зони друку від верхнього лівого кута mockup.
- Усі варіанти одного товару мають використовувати mockup однакового розміру й `mockupPxPerMm`.
- `DesignCanvas.widthMm/heightMm` мусять дорівнювати `PrintArea`.
- `fontSize` і `padding` у пікселях canvas, `charSpacing` у 1/1000 em, `angle` у градусах.

## Наслідки

- Frontend і backend мають одну формулу масштабування.
- Потрібне калібрування `mockupPxPerMm` для кожного товару.
- Backend може перевіряти межі зони друку після scale/rotate/flip.
