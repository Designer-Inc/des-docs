# ADR-0006: SvelteKit з гібридним рендерингом

- Статус: accepted
- Дата: 2026-11-05
- Замінює: frontend-частину ADR-0001

## Контекст

Потрібен SEO для публічного каталогу та карток товарів, але редактор дизайну, кошик, кабінет і адмінка не мають SEO-цінності. Повний SSR усього застосунку ускладнює Fabric.js і витрачає CPU на Cloudflare Workers. Frontend ще не написаний, тому зміна стеку зараз дешева.

## Рішення

- Frontend: SvelteKit 3, Svelte 5, TypeScript, Vite, Tailwind CSS, Fabric.js 6.
- Гібридний рендеринг:
  - `/`, `/catalog`, `/product/*` — prerender або SSR з кешуванням;
  - `/editor`, `/account`, `/admin`, `/cart`, `/checkout` — CSR;
  - `/api/*` — SvelteKit server proxy на Hono Worker.
- Деплой: Cloudflare Workers (`adapter-cloudflare`), один origin `designer.r0ma.top`.
- Браузер не ходить напряму на `api.*`; SvelteKit проксіює `/api/*`, тому CORS у production не потрібен.
- Refresh cookie: `HttpOnly; Secure; SameSite=Lax; Path=/`. Access token тримається в пам'яті.
- SEO: унікальні meta, canonical, JSON-LD, `sitemap.xml`, `robots.txt`.

## Наслідки

- Публічні сторінки віддаються з HTML і індексуються без виконання JS.
- Редактор і важкі клієнтські модулі не потрапляють у SSR-бандл.
- Cloudflare Workers має ~10 мс CPU на безкоштовному тарифі, тому каталог треба prerender-ити або кешувати, а не рендерити повністю на кожен запит.
- Fabric.js працює тільки в браузері; SSR для нього не потрібен.
- API, база даних і OpenAPI не змінюються.
