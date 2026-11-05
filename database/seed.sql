-- =============================================================================
-- «Дизайнер»: демо-дані для локальної розробки та staging
--
-- Запускати ПІСЛЯ database/schema.sql:
--   psql "$DATABASE_URL" -f database/schema.sql
--   psql "$DATABASE_URL" -f database/seed.sql
--
-- Демо-пароль для всіх користувачів: DemoPass123!
-- Seed використовує попередньо згенерований bcrypt-хеш цього пароля.
-- Якщо ваша версія auth.users не приймає прямий INSERT, створіть ці email
-- через Supabase Dashboard або Admin API, зберігши ті самі UUID.
--
-- Seed ідемпотентний для більшості рядків: повторний запуск не дублює
-- користувачів, товари, дизайни, версії та демо-замовлення.
-- Демо-дизайни не мають preview_file_id: frontend має показати placeholder
-- або відрендерити canvas у редакторі. Це не помилка seed.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Демо-користувачі
-- -----------------------------------------------------------------------------

do $$
declare
  v_has_password boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'auth'
      and table_name = 'users'
      and column_name = 'encrypted_password'
  ) into v_has_password;

  if v_has_password then
    insert into auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    )
    values
      (
        '11111111-1111-1111-1111-111111111111',
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated',
        'customer@demo.dyzainer.ua',
        '$2b$10$nTkKuS85UeVqpEamIOufZOM5sEu3PweatEkiWqg7yLFDo12arK8yK',
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Олена Покупець"}'::jsonb,
        now(), now()
      ),
      (
        '22222222-2222-2222-2222-222222222222',
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated',
        'author@demo.dyzainer.ua',
        '$2b$10$nTkKuS85UeVqpEamIOufZOM5sEu3PweatEkiWqg7yLFDo12arK8yK',
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Максим Автор"}'::jsonb,
        now(), now()
      ),
      (
        '33333333-3333-3333-3333-333333333333',
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated',
        'moderator@demo.dyzainer.ua',
        '$2b$10$nTkKuS85UeVqpEamIOufZOM5sEu3PweatEkiWqg7yLFDo12arK8yK',
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Ірина Модератор"}'::jsonb,
        now(), now()
      ),
      (
        '44444444-4444-4444-4444-444444444444',
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated',
        'admin@demo.dyzainer.ua',
        '$2b$10$nTkKuS85UeVqpEamIOufZOM5sEu3PweatEkiWqg7yLFDo12arK8yK',
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Олексій Адміністратор"}'::jsonb,
        now(), now()
      ),
      (
        '55555555-5555-5555-5555-555555555555',
        '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated',
        'b2b@demo.dyzainer.ua',
        '$2b$10$nTkKuS85UeVqpEamIOufZOM5sEu3PweatEkiWqg7yLFDo12arK8yK',
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Андрій Бізнес"}'::jsonb,
        now(), now()
      )
    on conflict (id) do nothing;
  else
    insert into auth.users (id, email, raw_user_meta_data)
    values
      ('11111111-1111-1111-1111-111111111111', 'customer@demo.dyzainer.ua', '{"full_name":"Олена Покупець"}'::jsonb),
      ('22222222-2222-2222-2222-222222222222', 'author@demo.dyzainer.ua', '{"full_name":"Максим Автор"}'::jsonb),
      ('33333333-3333-3333-3333-333333333333', 'moderator@demo.dyzainer.ua', '{"full_name":"Ірина Модератор"}'::jsonb),
      ('44444444-4444-4444-4444-444444444444', 'admin@demo.dyzainer.ua', '{"full_name":"Олексій Адміністратор"}'::jsonb),
      ('55555555-5555-5555-5555-555555555555', 'b2b@demo.dyzainer.ua', '{"full_name":"Андрій Бізнес"}'::jsonb)
    on conflict (id) do nothing;
  end if;
end $$;

-- Hosted GoTrue читає token-колонки як text. Прямий INSERT у auth.users
-- залишає їх NULL, і login/admin API падають з "Database error querying schema".
-- Локальна schema-stub не має цих колонок, тому update умовний.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'auth'
      and table_name = 'users'
      and column_name = 'confirmation_token'
  ) then
    update auth.users
    set confirmation_token = coalesce(confirmation_token, ''),
        recovery_token = coalesce(recovery_token, ''),
        email_change_token_new = coalesce(email_change_token_new, ''),
        email_change = coalesce(email_change, '')
    where id in (
      '11111111-1111-1111-1111-111111111111',
      '22222222-2222-2222-2222-222222222222',
      '33333333-3333-3333-3333-333333333333',
      '44444444-4444-4444-4444-444444444444',
      '55555555-5555-5555-5555-555555555555'
    );
  end if;
end $$;

-- Email-identity для Supabase Auth. У нових версіях GoTrue login за email
-- може вимагати рядок у auth.identities, а не лише auth.users.
do $$
begin
  if to_regclass('auth.identities') is not null then
    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    )
    values
      (gen_random_uuid(), '11111111-1111-1111-1111-111111111111',
       '{"sub":"11111111-1111-1111-1111-111111111111","email":"customer@demo.dyzainer.ua","email_verified":true,"phone_verified":false}'::jsonb,
       'email', '11111111-1111-1111-1111-111111111111', now(), now(), now()),
      (gen_random_uuid(), '22222222-2222-2222-2222-222222222222',
       '{"sub":"22222222-2222-2222-2222-222222222222","email":"author@demo.dyzainer.ua","email_verified":true,"phone_verified":false}'::jsonb,
       'email', '22222222-2222-2222-2222-222222222222', now(), now(), now()),
      (gen_random_uuid(), '33333333-3333-3333-3333-333333333333',
       '{"sub":"33333333-3333-3333-3333-333333333333","email":"moderator@demo.dyzainer.ua","email_verified":true,"phone_verified":false}'::jsonb,
       'email', '33333333-3333-3333-3333-333333333333', now(), now(), now()),
      (gen_random_uuid(), '44444444-4444-4444-4444-444444444444',
       '{"sub":"44444444-4444-4444-4444-444444444444","email":"admin@demo.dyzainer.ua","email_verified":true,"phone_verified":false}'::jsonb,
       'email', '44444444-4444-4444-4444-444444444444', now(), now(), now()),
      (gen_random_uuid(), '55555555-5555-5555-5555-555555555555',
       '{"sub":"55555555-5555-5555-5555-555555555555","email":"b2b@demo.dyzainer.ua","email_verified":true,"phone_verified":false}'::jsonb,
       'email', '55555555-5555-5555-5555-555555555555', now(), now(), now())
    on conflict do nothing;
  end if;
end $$;

-- Страховка, якщо auth-тригер не створив профіль.
insert into public.users (id, email, full_name, role, status)
select id, email, coalesce(raw_user_meta_data->>'full_name', ''), 'customer', 'active'
from auth.users
where id in (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555'
)
on conflict do nothing;

update public.users set role = 'moderator', status = 'active' where id = '33333333-3333-3333-3333-333333333333';
update public.users set role = 'admin', status = 'active' where id = '44444444-4444-4444-4444-444444444444';
update public.users set role = 'customer', status = 'active' where id in (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '55555555-5555-5555-5555-555555555555'
);

insert into public.company_profiles (
  user_id, company_name, legal_name, tax_id, iban, bank_name,
  legal_address, contact_name, contact_phone, contact_email, is_verified
)
values (
  '55555555-5555-5555-5555-555555555555',
  'Demo Studio', 'ТОВ «Демо Студія»', '12345678',
  'UA123456789012345678901234567', 'Demo Bank',
  'Київ, вул. Демо, 1', 'Андрій Бізнес', '+380501112233',
  'b2b@demo.dyzainer.ua', true
)
on conflict (user_id) do nothing;

-- -----------------------------------------------------------------------------
-- 2. Категорії та товари
-- -----------------------------------------------------------------------------

insert into public.categories (id, name, slug, description, position)
values
  ('c0000000-0000-0000-0000-000000000001', 'Одяг', 'apparel', 'Футболки, худі, світшоти', 1),
  ('c0000000-0000-0000-0000-000000000002', 'Посуд', 'drinkware', 'Чашки та інший посуд', 2),
  ('c0000000-0000-0000-0000-000000000003', 'Дім', 'home', 'Постери та декор', 3),
  ('c0000000-0000-0000-0000-000000000004', 'Аксесуари', 'accessories', 'Сумки та інші аксесуари', 4)
on conflict (slug) do nothing;

insert into public.products (
  id, category_id, name, slug, description, base_price_minor,
  currency, production_method, fabric_type
)
values
  (
    'd0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'Classic T-shirt', 'classic-tshirt',
    'Базова футболка з бавовни для кастомного друку.',
    55000, 'UAH', 'dtg', 'cotton'
  ),
  (
    'd0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    'Classic Hoodie', 'classic-hoodie',
    'Худі з щільного флісу для холодного сезону.',
    95000, 'UAH', 'dtg', 'cotton_fleece'
  ),
  (
    'd0000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000002',
    'Classic Mug', 'classic-mug',
    'Керамічна чашка 330 мл для сублімаційного друку.',
    35000, 'UAH', 'sublimation', 'ceramic'
  ),
  (
    'd0000000-0000-0000-0000-000000000004',
    'c0000000-0000-0000-0000-000000000003',
    'Art Poster', 'art-poster',
    'Постер на щільному папері, A3 або A2.',
    30000, 'UAH', 'sublimation', 'paper'
  ),
  (
    'd0000000-0000-0000-0000-000000000005',
    'c0000000-0000-0000-0000-000000000004',
    'Eco Bag', 'eco-bag',
    'Бавовняна екосумка для щоденного використання.',
    40000, 'UAH', 'dtf', 'canvas'
  )
on conflict (slug) do nothing;

-- -----------------------------------------------------------------------------
-- 3. Варіанти товарів
-- -----------------------------------------------------------------------------

-- Фіксований ID для прикладу order-create.json і Postman.
insert into public.product_variants (
  id, product_id, sku, color_name, color_hex, size, price_delta_minor, stock_quantity
)
values (
  '44444444-4444-4444-4444-444444444444',
  'd0000000-0000-0000-0000-000000000001',
  'TS-BLK-M', 'Black', '#111111', 'M', 0, 25
)
on conflict (sku) do nothing;

insert into public.product_variants (
  product_id, sku, color_name, color_hex, size, price_delta_minor, stock_quantity
)
values
  ('d0000000-0000-0000-0000-000000000001', 'TS-BLK-S',  'Black', '#111111', 'S',  0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-BLK-M',  'Black', '#111111', 'M',  0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-BLK-L',  'Black', '#111111', 'L',  0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-BLK-XL', 'Black', '#111111', 'XL', 0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-WHT-S',  'White', '#ffffff', 'S',  0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-WHT-M',  'White', '#ffffff', 'M',  0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-WHT-L',  'White', '#ffffff', 'L',  0, 25),
  ('d0000000-0000-0000-0000-000000000001', 'TS-WHT-XL', 'White', '#ffffff', 'XL', 0, 25),
  ('d0000000-0000-0000-0000-000000000002', 'HD-BLK-M',  'Black', '#111111', 'M',  0, 20),
  ('d0000000-0000-0000-0000-000000000002', 'HD-BLK-L',  'Black', '#111111', 'L',  0, 20),
  ('d0000000-0000-0000-0000-000000000002', 'HD-BLK-XL', 'Black', '#111111', 'XL', 0, 20),
  ('d0000000-0000-0000-0000-000000000002', 'HD-GRY-M',  'Grey',  '#8a8a8a', 'M',  0, 20),
  ('d0000000-0000-0000-0000-000000000002', 'HD-GRY-L',  'Grey',  '#8a8a8a', 'L',  0, 20),
  ('d0000000-0000-0000-0000-000000000002', 'HD-GRY-XL', 'Grey',  '#8a8a8a', 'XL', 0, 20),
  ('d0000000-0000-0000-0000-000000000003', 'MUG-WHT-330', 'White', '#ffffff', '330 ml', 0, 30),
  ('d0000000-0000-0000-0000-000000000003', 'MUG-BLK-330', 'Black', '#111111', '330 ml', 0, 30),
  ('d0000000-0000-0000-0000-000000000004', 'POSTER-WHT-A3', 'White', '#ffffff', 'A3', 0, 15),
  ('d0000000-0000-0000-0000-000000000004', 'POSTER-WHT-A2', 'White', '#ffffff', 'A2', 5000, 15),
  ('d0000000-0000-0000-0000-000000000005', 'BAG-NAT-OS', 'Natural', '#d9c7a3', 'One size', 0, 20),
  ('d0000000-0000-0000-0000-000000000005', 'BAG-BLK-OS', 'Black', '#111111', 'One size', 0, 20)
on conflict (sku) do nothing;

-- -----------------------------------------------------------------------------
-- 4. Зони друку та калібрування mockup
-- -----------------------------------------------------------------------------

insert into public.print_areas (
  id, product_id, name, width_mm, height_mm,
  offset_x_mm, offset_y_mm, mockup_px_per_mm, min_dpi
)
values
  ('e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'front', 300, 400, 100, 120, 2.500, 150),
  ('e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'front', 320, 420, 110, 130, 2.400, 150),
  ('e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000003', 'wrap',  200,  80,  90, 180, 3.000, 150),
  ('e0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000004', 'full',  420, 594,   0,   0, 2.000, 150),
  ('e0000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000005', 'front', 300, 350, 100, 150, 2.500, 150)
on conflict (product_id, name) do nothing;

-- -----------------------------------------------------------------------------
-- 5. Демо-дизайни
-- -----------------------------------------------------------------------------

-- 5.1. Minimal Black, T-shirt, опублікований
insert into public.designs (
  id, author_id, base_product_id, print_area_id, title, description, tags,
  canvas, status, rights_confirmed_at, author_bonus_percent
)
values (
  'f0000000-0000-0000-0000-000000000001',
  '22222222-2222-2222-2222-222222222222',
  'd0000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'Minimal Black',
  'Мінімалістичний білий напис на чорній футболці.',
  array['minimal', 'black', 'typography'],
  $canvas${
    "version":"fabric@6","unit":"px",
    "printAreaId":"e0000000-0000-0000-0000-000000000001",
    "widthMm":300,"heightMm":400,"pxPerMm":3.7795,
    "objects":[
      {"type":"textbox","id":"txt-less","text":"LESS","fontFamily":"inter","fontSize":150,"fontWeight":700,"fontStyle":"normal","fill":"#ffffff","textAlign":"center","lineHeight":1.10,"charSpacing":0,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":300,"top":420,"width":534,"height":200,"scaleX":1,"scaleY":1,"angle":0,"zIndex":1},
      {"type":"textbox","id":"txt-is-more","text":"IS MORE","fontFamily":"inter","fontSize":150,"fontWeight":700,"fontStyle":"normal","fill":"#ffffff","textAlign":"center","lineHeight":1.10,"charSpacing":0,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":300,"top":660,"width":534,"height":200,"scaleX":1,"scaleY":1,"angle":0,"zIndex":2},
      {"type":"shape","id":"line-accent","shape":"rect","fill":"#ffffff","width":434,"height":6,"left":350,"top":920,"scaleX":1,"scaleY":1,"angle":0,"zIndex":3}
    ]
  }$canvas$::jsonb,
  'draft', now(), 10
)
on conflict (id) do nothing;

-- 5.2. Kyiv 2026, Hoodie, опублікований
insert into public.designs (
  id, author_id, base_product_id, print_area_id, title, description, tags,
  canvas, status, rights_confirmed_at, author_bonus_percent
)
values (
  'f0000000-0000-0000-0000-000000000002',
  '22222222-2222-2222-2222-222222222222',
  'd0000000-0000-0000-0000-000000000002',
  'e0000000-0000-0000-0000-000000000002',
  'Kyiv 2026',
  'Великий кириличний напис для худі.',
  array['kyiv', 'cyrillic', 'street'],
  $canvas${
    "version":"fabric@6","unit":"px",
    "printAreaId":"e0000000-0000-0000-0000-000000000002",
    "widthMm":320,"heightMm":420,"pxPerMm":3.7795,
    "objects":[
      {"type":"textbox","id":"txt-kyiv","text":"КИЇВ","fontFamily":"montserrat","fontSize":260,"fontWeight":700,"fontStyle":"normal","fill":"#ffffff","textAlign":"center","lineHeight":1.05,"charSpacing":20,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":200,"top":330,"width":810,"height":320,"scaleX":1,"scaleY":1,"angle":0,"zIndex":1},
      {"type":"textbox","id":"txt-year","text":"2026","fontFamily":"pt_serif","fontSize":140,"fontWeight":400,"fontStyle":"normal","fill":"#ffffff","textAlign":"center","lineHeight":1.10,"charSpacing":40,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":200,"top":700,"width":810,"height":180,"scaleX":1,"scaleY":1,"angle":0,"zIndex":2},
      {"type":"shape","id":"line-accent","shape":"rect","fill":"#ffffff","width":500,"height":6,"left":355,"top":930,"scaleX":1,"scaleY":1,"angle":0,"zIndex":3}
    ]
  }$canvas$::jsonb,
  'draft', now(), 10
)
on conflict (id) do nothing;

-- 5.3. Good Morning, Mug, опублікований
insert into public.designs (
  id, author_id, base_product_id, print_area_id, title, description, tags,
  canvas, status, rights_confirmed_at, author_bonus_percent
)
values (
  'f0000000-0000-0000-0000-000000000003',
  '22222222-2222-2222-2222-222222222222',
  'd0000000-0000-0000-0000-000000000003',
  'e0000000-0000-0000-0000-000000000003',
  'Good Morning',
  'Ранковий напис для чашки.',
  array['mug', 'morning', 'handwriting'],
  $canvas${
    "version":"fabric@6","unit":"px",
    "printAreaId":"e0000000-0000-0000-0000-000000000003",
    "widthMm":200,"heightMm":80,"pxPerMm":3.7795,
    "objects":[
      {"type":"textbox","id":"txt-good-morning","text":"good morning","fontFamily":"caveat","fontSize":90,"fontWeight":700,"fontStyle":"normal","fill":"#111111","textAlign":"center","lineHeight":1.00,"charSpacing":10,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":40,"top":80,"width":676,"height":140,"scaleX":1,"scaleY":1,"angle":0,"zIndex":1},
      {"type":"shape","id":"sun","shape":"circle","fill":"#f2b705","width":80,"height":80,"left":600,"top":20,"scaleX":1,"scaleY":1,"angle":0,"zIndex":2}
    ]
  }$canvas$::jsonb,
  'draft', now(), 10
)
on conflict (id) do nothing;

-- 5.4. Bitter Poster, Poster, на модерації
insert into public.designs (
  id, author_id, base_product_id, print_area_id, title, description, tags,
  canvas, status, rights_confirmed_at, author_bonus_percent
)
values (
  'f0000000-0000-0000-0000-000000000004',
  '22222222-2222-2222-2222-222222222222',
  'd0000000-0000-0000-0000-000000000004',
  'e0000000-0000-0000-0000-000000000004',
  'Bitter Poster',
  'Постер із типографічною композицією.',
  array['poster', 'bitter', 'typography'],
  $canvas${
    "version":"fabric@6","unit":"px",
    "printAreaId":"e0000000-0000-0000-0000-000000000004",
    "widthMm":420,"heightMm":594,"pxPerMm":3.7795,
    "objects":[
      {"type":"textbox","id":"txt-design","text":"DESIGN","fontFamily":"bitter","fontSize":180,"fontWeight":700,"fontStyle":"normal","fill":"#111111","textAlign":"left","lineHeight":1.05,"charSpacing":0,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":100,"top":300,"width":1387,"height":220,"scaleX":1,"scaleY":1,"angle":0,"zIndex":1},
      {"type":"textbox","id":"txt-language","text":"IS A LANGUAGE","fontFamily":"bitter","fontSize":120,"fontWeight":700,"fontStyle":"normal","fill":"#111111","textAlign":"left","lineHeight":1.10,"charSpacing":0,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":100,"top":560,"width":1387,"height":180,"scaleX":1,"scaleY":1,"angle":0,"zIndex":2},
      {"type":"shape","id":"line-accent","shape":"rect","fill":"#111111","width":800,"height":8,"left":100,"top":800,"scaleX":1,"scaleY":1,"angle":0,"zIndex":3}
    ]
  }$canvas$::jsonb,
  'pending_moderation', now(), 10
)
on conflict (id) do nothing;

-- 5.5. Приватна чернетка покупця
insert into public.designs (
  id, author_id, base_product_id, print_area_id, title, description, tags,
  canvas, status, author_bonus_percent
)
values (
  'f0000000-0000-0000-0000-000000000005',
  '11111111-1111-1111-1111-111111111111',
  'd0000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'Мій подарунок',
  'Чернетка покупця для тестування кабінету.',
  array['draft', 'gift'],
  $canvas${
    "version":"fabric@6","unit":"px",
    "printAreaId":"e0000000-0000-0000-0000-000000000001",
    "widthMm":300,"heightMm":400,"pxPerMm":3.7795,
    "objects":[
      {"type":"textbox","id":"txt-gift","text":"МІЙ ПОДАРУНОК","fontFamily":"montserrat","fontSize":100,"fontWeight":700,"fontStyle":"normal","fill":"#ffffff","textAlign":"center","lineHeight":1.10,"charSpacing":0,"padding":0,"splitByGrapheme":true,"autoWrap":true,"left":300,"top":650,"width":534,"height":160,"scaleX":1,"scaleY":1,"angle":0,"zIndex":1}
    ]
  }$canvas$::jsonb,
  'draft', 10
)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- 6. Версії опублікованих дизайнів
-- -----------------------------------------------------------------------------

insert into public.design_versions (
  id, design_id, version_number, source, status, canvas,
  base_product_id, print_area_id, rights_confirmed_at,
  author_bonus_percent, created_by, published_at
)
values
  (
    'a1000000-0000-0000-0000-000000000001',
    'f0000000-0000-0000-0000-000000000001',
    1, 'author', 'published',
    (select canvas from public.designs where id = 'f0000000-0000-0000-0000-000000000001'),
    'd0000000-0000-0000-0000-000000000001',
    'e0000000-0000-0000-0000-000000000001',
    now(), 10, '22222222-2222-2222-2222-222222222222', now()
  ),
  (
    'a1000000-0000-0000-0000-000000000002',
    'f0000000-0000-0000-0000-000000000002',
    1, 'author', 'published',
    (select canvas from public.designs where id = 'f0000000-0000-0000-0000-000000000002'),
    'd0000000-0000-0000-0000-000000000002',
    'e0000000-0000-0000-0000-000000000002',
    now(), 10, '22222222-2222-2222-2222-222222222222', now()
  ),
  (
    'a1000000-0000-0000-0000-000000000003',
    'f0000000-0000-0000-0000-000000000003',
    1, 'author', 'published',
    (select canvas from public.designs where id = 'f0000000-0000-0000-0000-000000000003'),
    'd0000000-0000-0000-0000-000000000003',
    'e0000000-0000-0000-0000-000000000003',
    now(), 10, '22222222-2222-2222-2222-222222222222', now()
  ),
  (
    'a1000000-0000-0000-0000-000000000004',
    'f0000000-0000-0000-0000-000000000004',
    1, 'author', 'pending_moderation',
    (select canvas from public.designs where id = 'f0000000-0000-0000-0000-000000000004'),
    'd0000000-0000-0000-0000-000000000004',
    'e0000000-0000-0000-0000-000000000004',
    now(), 10, '22222222-2222-2222-2222-222222222222', null
  )
on conflict (design_id, version_number) do nothing;

-- Після вставки published-версій trigger sync_design_current_version
-- виставляє designs.status='published' і current_version_id.

-- -----------------------------------------------------------------------------
-- 7. Демо-замовлення
-- -----------------------------------------------------------------------------

insert into public.orders (
  id, user_id, status, payment_status, payment_method,
  customer_name, customer_email, customer_phone,
  delivery_service, delivery_city_id, delivery_city_name,
  delivery_warehouse_id, delivery_warehouse_name,
  delivery_recipient_name, delivery_recipient_phone,
  delivery_cost_minor, paid_at, created_at
)
values (
  'b1000000-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111',
  'in_production', 'success', 'card',
  'Олена Покупець', 'customer@demo.dyzainer.ua', '+380501112233',
  'nova_poshta', 'city-kyiv', 'Київ',
  'wh-1', 'Відділення №1',
  'Олена Покупець', '+380501112233',
  8000, now(), now()
)
on conflict (id) do nothing;

insert into public.order_items (
  id, order_id, position, product_id, variant_id,
  design_id, design_version_id, product_name, variant_name,
  unit_price_minor, quantity, discount_percent, is_sample, author_bonus_minor
)
select
  'b2000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001',
  1,
  'd0000000-0000-0000-0000-000000000001',
  v.id,
  'f0000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'Classic T-shirt', 'Black / M',
  55000, 1, 0, false, 5500
from public.product_variants v
where v.sku = 'TS-BLK-M'
on conflict (order_id, position) do nothing;

insert into public.payments (
  id, order_id, provider, method, status, amount_minor, currency,
  provider_transaction_id, paid_at
)
values (
  'b3000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001',
  'liqpay', 'card', 'success', 63000, 'UAH',
  'demo-liqpay-1', now()
)
on conflict do nothing;

insert into public.author_bonuses (
  id, order_item_id, author_id, design_id, amount_minor, percent, status
)
values (
  'b4000000-0000-0000-0000-000000000001',
  'b2000000-0000-0000-0000-000000000001',
  '22222222-2222-2222-2222-222222222222',
  'f0000000-0000-0000-0000-000000000001',
  5500, 10, 'accrued'
)
on conflict (order_item_id) do nothing;

insert into public.order_status_history (order_id, from_status, to_status, changed_by, note)
select
  'b1000000-0000-0000-0000-000000000001',
  'pending_payment', 'paid', null, 'demo seed: payment success'
where not exists (
  select 1 from public.order_status_history
  where order_id = 'b1000000-0000-0000-0000-000000000001'
    and to_status = 'paid'
);

insert into public.order_status_history (order_id, from_status, to_status, changed_by, note)
select
  'b1000000-0000-0000-0000-000000000001',
  'paid', 'in_production', null, 'demo seed: approved for print'
where not exists (
  select 1 from public.order_status_history
  where order_id = 'b1000000-0000-0000-0000-000000000001'
    and to_status = 'in_production'
);

-- =============================================================================
-- КІНЕЦЬ SEED
-- =============================================================================
