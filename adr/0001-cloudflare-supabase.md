# ADR-0001: Cloudflare Workers, Supabase, React і Fabric.js

- Статус: accepted
- Дата: 2026-11-05

## Контекст

Команда має семестровий бюджет і не може платити за інфраструктуру. Потрібні авторизація, PostgreSQL, файлове сховище, REST API, SPA з 2D-конструктором і мінімум операційної роботи.

## Рішення

- Frontend: React, TypeScript, Vite, Fabric.js, Zustand, Tailwind, Shadcn/UI.
- API: Hono на Cloudflare Workers.
- Дані: Supabase PostgreSQL 15+, Supabase Auth, Supabase Storage.
- Великі print-файли: Cloudflare R2, якщо безкоштовного Supabase Storage не вистачає.
- CI: GitHub Actions, деплой frontend на Cloudflare Pages.

## Наслідки

- Немає власного сервера і контейнерів для API.
- Workers мають обмеження CPU і не мають node-canvas. Важкий рендер друку виноситься в GitHub Actions, Node-сумісний worker або headless browser.
- RLS і service role вимагають дисципліни: backend перевіряє права, RLS є другим рівнем.
- Supabase free може засинати, потрібен keepalive.
