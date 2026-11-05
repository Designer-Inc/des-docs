-- =============================================================================
-- «Дизайнер»: повна схема PostgreSQL 15+ для Supabase
-- Версія: 1.0 (05.11.2026)
--
-- Це fresh-install snapshot. Застосовуйте один раз на чисту БД:
--   supabase db reset
--   psql "$DATABASE_URL" -f schema.sql
--
-- Подальші зміни оформлюйте як append-only міграції
-- supabase/migrations/NNNN_description.sql.
--
-- Конвенції:
--   - ID: UUID v4 (gen_random_uuid), крім людських номерів замовлень і рахунків.
--   - Гроші: integer у копійках, поля *Minor. API віддає ті самі цілі.
--   - Час: timestamptz, UTC. API віддає ISO 8601.
--   - JSON: camelCase в API, snake_case у БД. Конвертація на межі API.
--   - Файли: тільки через public.files, інші таблиці посилаються на file_id.
--   - Версії: design_versions це незмінний знімок. Order_items посилається
--     на design_version_id. Published design/version content immutable.
--     Print worker читає design_versions, не designs.canvas.
--
-- Supabase Storage buckets (створити в dashboard або storage API):
--   public-assets   public read, для прев'ю та фото товарів
--   private-files   private, для artwork, vector, brand assets
--   print-files     private, для print-ready
--   invoices        private, для PDF рахунків
-- Backend використовує service role і видає signed URL клієнту.
--
-- RLS: увімкнено на всіх таблицях. Backend працює через service role,
-- тому додатково перевіряє роль і власність у Hono. RLS захищає прямий
-- доступ з anon/authenticated key.
--
-- Stock (binding for the real backend):
--   decrement atomically in one statement:
--     UPDATE product_variants
--     SET stock_quantity = stock_quantity - :qty
--     WHERE id = :variant_id AND stock_quantity >= :qty;
--   0 affected rows => 409 OUT_OF_STOCK. Never read-then-write.
--   POST /orders reserves stock inside the same transaction as orders,
--   order_items, payments and author_bonuses. Failed or expired payment
--   restores stock once and sets orders.stock_released_at.
--
-- Payment amount (binding for the real backend):
--   payments.amount_minor must equal orders.total_minor. A provider callback
--   with a different amount is rejected, logged in payment_events, and never
--   moves the order to paid.
-- =============================================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- Локальний shim для перевірки схеми без Supabase. У Supabase auth вже існує,
-- тому цей блок нічого не змінює.
do $$
begin
  if not exists (select 1 from information_schema.schemata where schema_name = 'auth') then
    create schema auth;
    create table auth.users (
      id uuid primary key,
      email text,
      phone text,
      raw_user_meta_data jsonb not null default '{}'::jsonb
    );
    execute 'create function auth.uid() returns uuid language sql stable as $fn$ select null::uuid $fn$';
  end if;
end $$;

-- =============================================================================
-- ENUMS
-- =============================================================================

create type public.user_role as enum ('customer', 'moderator', 'admin', 'super_admin');
create type public.user_status as enum ('active', 'blocked', 'deleted');

create type public.file_kind as enum (
  'artwork', 'vector', 'brand_asset', 'personalization_list',
  'print_file', 'product_image', 'preview', 'invoice'
);
create type public.file_status as enum ('pending', 'ready', 'failed', 'deleted');
create type public.file_visibility as enum ('public', 'private');

create type public.design_status as enum (
  'draft', 'pending_moderation', 'published', 'rejected', 'hidden', 'archived'
);
create type public.design_version_status as enum (
  'draft', 'pending_moderation', 'published', 'rejected', 'archived'
);
create type public.design_version_source as enum ('author', 'order_snapshot');
create type public.design_file_role as enum ('artwork', 'preview', 'print_ready', 'vector');

create type public.product_production_method as enum ('dtg', 'dtf', 'sublimation');

create type public.order_status as enum (
  'pending_payment', 'paid', 'on_moderation', 'in_production',
  'ready_to_ship', 'shipped', 'delivered', 'cancelled', 'refunded'
);
create type public.payment_status as enum ('pending', 'success', 'failed', 'refunded');
create type public.payment_method as enum ('card', 'bank_transfer');
create type public.payment_provider as enum ('liqpay', 'wayforpay', 'bank_transfer');

create type public.invoice_status as enum ('issued', 'paid', 'void', 'overdue');

create type public.print_job_status as enum ('queued', 'processing', 'ready', 'failed');
create type public.print_file_kind as enum ('direct', 'mirrored');
create type public.print_file_status as enum ('pending', 'ready', 'failed');

create type public.shipment_status as enum ('created', 'in_transit', 'delivered', 'returned', 'cancelled');

create type public.moderation_target as enum ('design', 'order');
create type public.moderation_action as enum ('approved', 'rejected', 'hidden', 'restored');

create type public.report_reason as enum ('copyright', 'offensive', 'illegal', 'spam', 'other');
create type public.report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
create type public.report_action as enum ('none', 'design_hidden');

create type public.notification_type as enum (
  'order_status', 'payment', 'moderation', 'report', 'invoice', 'system'
);

create type public.bonus_status as enum ('accrued', 'paid', 'void');

create type public.consent_type as enum (
  'terms', 'privacy', 'design_rights', 'order_disclaimer'
);
create type public.consent_context as enum (
  'registration', 'design_publish', 'checkout', 'account_deletion'
);

create type public.personalization_status as enum ('parsed', 'invalid');

-- =============================================================================
-- КОРИСТУВАЧІ ТА КОМПАНІЇ
-- =============================================================================

create table public.users (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text not null unique,
  full_name       text not null default '',
  phone           text,
  role            public.user_role not null default 'customer',
  status          public.user_status not null default 'active',
  locale          text not null default 'uk' check (locale in ('uk', 'en')),
  avatar_file_id  uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create table public.company_profiles (
  user_id        uuid primary key references public.users(id) on delete cascade,
  company_name   text not null,
  legal_name     text not null,
  tax_id         text not null,
  iban           text not null,
  bank_name      text not null,
  legal_address  text not null,
  contact_name   text not null,
  contact_phone  text not null,
  contact_email  text not null,
  is_verified    boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (char_length(tax_id) between 8 and 12),
  check (char_length(iban) between 15 and 34)
);

-- =============================================================================
-- ФАЙЛИ
-- =============================================================================

create table public.files (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid references public.users(id) on delete set null,
  kind             public.file_kind not null,
  status           public.file_status not null default 'pending',
  visibility       public.file_visibility not null default 'private',
  bucket           text not null default 'private-files',
  storage_path     text not null,
  original_name    text not null,
  mime_type        text not null,
  size_bytes       bigint not null check (size_bytes > 0),
  width_px         integer check (width_px is null or width_px > 0),
  height_px        integer check (height_px is null or height_px > 0),
  dpi              integer check (dpi is null or dpi > 0),
  checksum_sha256  text,
  metadata         jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  ready_at         timestamptz,
  locked_at        timestamptz,
  deleted_at       timestamptz,
  unique (bucket, storage_path)
);

alter table public.users
  add constraint users_avatar_file_fk
  foreign key (avatar_file_id) references public.files(id) on delete set null;

-- =============================================================================
-- КАТАЛОГ
-- =============================================================================

create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique,
  description text,
  position    integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.products (
  id                 uuid primary key default gen_random_uuid(),
  category_id        uuid not null references public.categories(id) on delete restrict,
  name               text not null,
  slug               text not null unique,
  description        text,
  base_price_minor   integer not null check (base_price_minor >= 0),
  currency           char(3) not null default 'UAH' check (currency ~ '^[A-Z]{3}$'),
  production_method  public.product_production_method not null default 'dtg',
  fabric_type        text,
  is_active          boolean not null default true,
  is_customizable    boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.product_variants (
  id                 uuid primary key default gen_random_uuid(),
  product_id         uuid not null references public.products(id) on delete cascade,
  sku                text not null unique,
  color_name         text not null,
  color_hex          text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  size               text not null,
  price_delta_minor  integer not null default 0,
  stock_quantity     integer not null default 0 check (stock_quantity >= 0),
  mockup_file_id     uuid references public.files(id) on delete set null,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (product_id, color_name, size),
  unique (id, product_id)
);

create table public.print_areas (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references public.products(id) on delete cascade,
  name          text not null,
  width_mm      numeric(7,2) not null check (width_mm > 0),
  height_mm     numeric(7,2) not null check (height_mm > 0),
  offset_x_mm       numeric(7,2) not null default 0,
  offset_y_mm       numeric(7,2) not null default 0,
  mockup_px_per_mm  numeric(7,3) not null default 3.7795
                    check (mockup_px_per_mm > 0),
  min_dpi           integer not null default 150 check (min_dpi >= 72),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (product_id, name),
  unique (id, product_id)
);

create table public.product_images (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.products(id) on delete cascade,
  file_id     uuid not null references public.files(id) on delete restrict,
  position    integer not null default 0,
  alt         text,
  created_at  timestamptz not null default now(),
  unique (product_id, position),
  unique (product_id, file_id)
);

create table public.discount_tiers (
  id                uuid primary key default gen_random_uuid(),
  product_id        uuid references public.products(id) on delete cascade,
  min_quantity      integer not null check (min_quantity >= 1),
  discount_percent  numeric(5,2) not null check (discount_percent between 0 and 100),
  is_active         boolean not null default true,
  created_at        timestamptz not null default now()
);

create unique index discount_tiers_scope_uq
  on public.discount_tiers (
    coalesce(product_id, '00000000-0000-0000-0000-000000000000'::uuid),
    min_quantity
  );

-- =============================================================================
-- ДИЗАЙНИ
-- =============================================================================

create table public.designs (
  id                        uuid primary key default gen_random_uuid(),
  author_id                 uuid not null references public.users(id) on delete restrict,
  base_product_id           uuid not null references public.products(id) on delete restrict,
  print_area_id             uuid not null,
  forked_from_id            uuid references public.designs(id) on delete set null,
  current_version_id        uuid,
  title                     text,
  description               text,
  tags                      text[] not null default '{}',
  -- Fabric.js JSON: до 20 об'єктів image/textbox/shape, angle -360..360, 5 font ids.
  canvas                    jsonb not null default '{}'::jsonb,
  status                    public.design_status not null default 'draft',
  rejection_reason          text,
  hidden_reason             text,
  rights_confirmed_at       timestamptz,
  rights_document_version   text,
  author_bonus_percent      numeric(5,2) not null default 10
                            check (author_bonus_percent between 0 and 30),
  view_count                bigint not null default 0 check (view_count >= 0),
  order_count               bigint not null default 0 check (order_count >= 0),
  copies_count              bigint not null default 0 check (copies_count >= 0),
  published_at              timestamptz,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  deleted_at                timestamptz,
  foreign key (print_area_id, base_product_id)
    references public.print_areas(id, product_id),
  check (description is null or char_length(description) <= 300),
  check (cardinality(tags) <= 10),
  check (status in ('draft', 'archived')
         or (title is not null and char_length(title) between 3 and 60)),
  check (status in ('draft', 'archived') or rights_confirmed_at is not null),
  check (status in ('draft', 'archived') or canvas <> '{}'::jsonb),
  check (status <> 'published' or current_version_id is not null)
);

create table public.design_versions (
  id                        uuid primary key default gen_random_uuid(),
  design_id                 uuid not null references public.designs(id) on delete restrict,
  version_number            integer not null check (version_number > 0),
  source                    public.design_version_source not null,
  status                    public.design_version_status not null default 'draft',
  canvas                    jsonb not null,
  base_product_id           uuid not null references public.products(id) on delete restrict,
  print_area_id             uuid not null,
  preview_file_id           uuid references public.files(id) on delete set null,
  rights_confirmed_at       timestamptz,
  rights_document_version   text,
  author_bonus_percent      numeric(5,2) not null default 10
                            check (author_bonus_percent between 0 and 30),
  rejection_reason          text,
  created_by                uuid references public.users(id) on delete set null,
  created_at                timestamptz not null default now(),
  published_at              timestamptz,
  archived_at               timestamptz,
  unique (design_id, version_number),
  foreign key (print_area_id, base_product_id)
    references public.print_areas(id, product_id),
  check (canvas->'objects' is not null
         and jsonb_typeof(canvas->'objects') = 'array'
         and jsonb_array_length(canvas->'objects') > 0),
  check (status <> 'published' or published_at is not null)
);

alter table public.designs
  add constraint designs_current_version_fk
  foreign key (current_version_id) references public.design_versions(id)
  on delete set null;

create table public.design_files (
  design_id   uuid not null references public.designs(id) on delete cascade,
  file_id     uuid not null references public.files(id) on delete restrict,
  role        public.design_file_role not null,
  created_at  timestamptz not null default now(),
  primary key (design_id, file_id, role)
);

-- =============================================================================
-- ПЕРСОНАЛІЗАЦІЯ ТИРАЖУ
-- =============================================================================

create table public.personalization_lists (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  file_id     uuid not null references public.files(id) on delete restrict,
  names       text[] not null,
  row_count   integer not null check (row_count > 0),
  status      public.personalization_status not null default 'parsed',
  errors      jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  check (row_count = cardinality(names)),
  check (cardinality(names) <= 500)
);

-- =============================================================================
-- ЗАМОВЛЕННЯ
-- =============================================================================

create table public.orders (
  id                        uuid primary key default gen_random_uuid(),
  order_number              text not null unique,
  user_id                   uuid not null references public.users(id) on delete restrict,
  status                    public.order_status not null default 'pending_payment',
  payment_status            public.payment_status not null default 'pending',
  payment_method            public.payment_method not null,
  customer_name             text not null,
  customer_email            text not null,
  customer_phone            text not null,
  customer_note             text,
  delivery_service          text not null default 'nova_poshta'
                            check (delivery_service = 'nova_poshta'),
  delivery_city_id          text not null,
  delivery_city_name        text not null,
  delivery_warehouse_id     text not null,
  delivery_warehouse_name   text not null,
  delivery_recipient_name   text not null,
  delivery_recipient_phone  text not null,
  delivery_cost_minor       integer not null default 0 check (delivery_cost_minor >= 0),
  subtotal_minor            integer not null default 0 check (subtotal_minor >= 0),
  discount_minor            integer not null default 0 check (discount_minor >= 0),
  total_minor               integer generated always as
                            (subtotal_minor - discount_minor + delivery_cost_minor) stored,
  currency                  char(3) not null default 'UAH' check (currency ~ '^[A-Z]{3}$'),
  cancellation_reason       text,
  cancelled_at              timestamptz,
  paid_at                   timestamptz,
  refunded_at               timestamptz,
  stock_released_at         timestamptz,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  check (total_minor >= 0)
);

create table public.order_items (
  id                             uuid primary key default gen_random_uuid(),
  order_id                       uuid not null references public.orders(id) on delete cascade,
  position                       integer not null check (position > 0),
  product_id                     uuid not null references public.products(id) on delete restrict,
  variant_id                     uuid not null,
  design_id                      uuid references public.designs(id) on delete set null,
  design_version_id              uuid references public.design_versions(id) on delete restrict,
  product_name                   text not null,
  variant_name                   text not null,
  unit_price_minor               integer not null check (unit_price_minor >= 0),
  quantity                       integer not null check (quantity > 0 and quantity <= 500),
  discount_percent               numeric(5,2) not null default 0
                                 check (discount_percent between 0 and 100),
  is_sample                      boolean not null default false,
  personalization_list_id        uuid references public.personalization_lists(id) on delete set null,
  personalization_text_element_id text,
  author_bonus_minor             integer not null default 0 check (author_bonus_minor >= 0),
  line_subtotal_minor            integer generated always as
                                 (unit_price_minor * quantity) stored,
  line_discount_minor            integer generated always as
                                 (((unit_price_minor * quantity) * discount_percent / 100)::integer) stored,
  line_total_minor               integer generated always as
                                 ((unit_price_minor * quantity)
                                  - (((unit_price_minor * quantity) * discount_percent / 100)::integer)) stored,
  created_at                     timestamptz not null default now(),
  unique (order_id, position),
  foreign key (variant_id, product_id)
    references public.product_variants(id, product_id),
  check (not is_sample or (quantity = 1 and discount_percent = 0)),
  check (design_id is null or design_version_id is not null)
);

create table public.payments (
  id                       uuid primary key default gen_random_uuid(),
  order_id                 uuid not null references public.orders(id) on delete cascade,
  provider                 public.payment_provider not null,
  method                   public.payment_method not null,
  status                   public.payment_status not null default 'pending',
  amount_minor             integer not null check (amount_minor > 0),
  currency                 char(3) not null default 'UAH' check (currency ~ '^[A-Z]{3}$'),
  provider_transaction_id  text,
  provider_payment_url     text,
  failure_reason           text,
  paid_at                  timestamptz,
  refunded_at              timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create unique index payments_provider_tx_uq
  on public.payments (provider, provider_transaction_id)
  where provider_transaction_id is not null;

create table public.payment_events (
  id            uuid primary key default gen_random_uuid(),
  payment_id    uuid references public.payments(id) on delete set null,
  provider      public.payment_provider not null,
  event_id      text not null,
  payload       jsonb not null,
  status        text not null default 'received'
                check (status in ('received', 'processed', 'failed')),
  error         text,
  received_at   timestamptz not null default now(),
  processed_at  timestamptz,
  unique (provider, event_id)
);

create table public.invoices (
  id                uuid primary key default gen_random_uuid(),
  order_id          uuid not null unique references public.orders(id) on delete cascade,
  number            text not null unique,
  status            public.invoice_status not null default 'issued',
  total_minor       integer not null check (total_minor >= 0),
  currency          char(3) not null default 'UAH' check (currency ~ '^[A-Z]{3}$'),
  issued_at         timestamptz not null default now(),
  due_at            timestamptz not null,
  paid_at           timestamptz,
  pdf_file_id       uuid references public.files(id) on delete set null,
  company_snapshot  jsonb not null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table public.print_jobs (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders(id) on delete cascade,
  status        public.print_job_status not null default 'queued',
  attempts      integer not null default 0 check (attempts >= 0),
  last_error    text,
  queued_at     timestamptz not null default now(),
  started_at    timestamptz,
  completed_at  timestamptz,
  created_at    timestamptz not null default now()
);

create unique index print_jobs_active_uq
  on public.print_jobs (order_id)
  where status in ('queued', 'processing');

create table public.print_files (
  id                     uuid primary key default gen_random_uuid(),
  order_item_id          uuid not null references public.order_items(id) on delete cascade,
  print_job_id           uuid references public.print_jobs(id) on delete set null,
  kind                   public.print_file_kind not null,
  personalization_index  integer not null default 0 check (personalization_index >= 0),
  personalized_name      text,
  file_id                uuid references public.files(id) on delete set null,
  status                 public.print_file_status not null default 'pending',
  error                  text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  unique (order_item_id, kind, personalization_index)
);

create table public.shipments (
  id               uuid primary key default gen_random_uuid(),
  order_id         uuid not null unique references public.orders(id) on delete cascade,
  provider         text not null default 'nova_poshta'
                   check (provider = 'nova_poshta'),
  tracking_number  text not null,
  status           public.shipment_status not null default 'created',
  shipped_at       timestamptz,
  delivered_at     timestamptz,
  raw              jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (provider, tracking_number)
);

create table public.order_status_history (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders(id) on delete cascade,
  from_status  public.order_status,
  to_status    public.order_status not null,
  changed_by   uuid references public.users(id) on delete set null,
  note         text,
  created_at   timestamptz not null default now()
);

create table public.author_bonuses (
  id             uuid primary key default gen_random_uuid(),
  order_item_id  uuid not null unique references public.order_items(id) on delete restrict,
  author_id      uuid not null references public.users(id) on delete restrict,
  design_id      uuid not null references public.designs(id) on delete restrict,
  amount_minor   integer not null check (amount_minor >= 0),
  percent        numeric(5,2) not null check (percent between 0 and 30),
  status         public.bonus_status not null default 'accrued',
  created_at     timestamptz not null default now(),
  paid_at        timestamptz
);

-- =============================================================================
-- МОДЕРАЦІЯ, СПОВІЩЕННЯ, АУДИТ
-- =============================================================================

create table public.moderation_logs (
  id            uuid primary key default gen_random_uuid(),
  target_type        public.moderation_target not null,
  design_id          uuid references public.designs(id) on delete restrict,
  design_version_id  uuid references public.design_versions(id) on delete restrict,
  order_id           uuid references public.orders(id) on delete restrict,
  moderator_id  uuid not null references public.users(id) on delete restrict,
  action        public.moderation_action not null,
  reason        text,
  notes         text,
  created_at    timestamptz not null default now(),
  check (
    (target_type = 'design'
      and design_id is not null
      and design_version_id is not null
      and order_id is null)
    or
    (target_type = 'order'
      and order_id is not null
      and design_id is null
      and design_version_id is null)
  )
);

create table public.design_reports (
  id                 uuid primary key default gen_random_uuid(),
  design_id          uuid not null references public.designs(id) on delete cascade,
  reporter_id        uuid not null references public.users(id) on delete cascade,
  reason             public.report_reason not null,
  details            text,
  status             public.report_status not null default 'open',
  resolved_by        uuid references public.users(id) on delete set null,
  resolution_action  public.report_action not null default 'none',
  resolution_note    text,
  created_at         timestamptz not null default now(),
  resolved_at        timestamptz,
  check (details is null or char_length(details) <= 1000)
);

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  type        public.notification_type not null,
  title       text not null,
  body        text not null,
  data        jsonb not null default '{}'::jsonb,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create table public.legal_acceptances (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete restrict,
  consent_type      public.consent_type not null,
  document_version  text not null,
  context_type      public.consent_context not null,
  context_id        uuid,
  accepted_at       timestamptz not null default now(),
  ip_hash           text
);

create table public.audit_logs (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid references public.users(id) on delete set null,
  action       text not null,
  entity_type  text not null,
  entity_id    uuid,
  before       jsonb,
  after        jsonb,
  ip_hash      text,
  user_agent   text,
  created_at   timestamptz not null default now()
);

create table public.idempotency_keys (
  key              text primary key,
  user_id          uuid references public.users(id) on delete cascade,
  endpoint         text not null,
  request_hash     text not null,
  response_status  integer,
  response_body    jsonb,
  created_at       timestamptz not null default now(),
  expires_at       timestamptz not null
);

-- =============================================================================
-- ІНДЕКСИ
-- =============================================================================

create index users_role_status_idx on public.users (role, status);
create index files_owner_kind_idx on public.files (owner_id, kind);
create index files_status_idx on public.files (status);
create index company_profiles_tax_idx on public.company_profiles (tax_id);

create index products_category_idx on public.products (category_id);
create index products_active_idx on public.products (is_active);
create index products_name_trgm_idx on public.products using gin (name gin_trgm_ops);
create index products_description_trgm_idx on public.products using gin (description gin_trgm_ops);

create index product_variants_product_idx on public.product_variants (product_id, is_active);
create index print_areas_product_idx on public.print_areas (product_id);
create index product_images_product_idx on public.product_images (product_id);
create index discount_tiers_product_idx on public.discount_tiers (product_id);

create index designs_author_status_idx on public.designs (author_id, status);
create index designs_status_published_idx on public.designs (status, published_at desc);
create index designs_product_idx on public.designs (base_product_id);
create index designs_tags_idx on public.designs using gin (tags);
create index designs_title_trgm_idx on public.designs using gin (title gin_trgm_ops);
create index designs_description_trgm_idx on public.designs using gin (description gin_trgm_ops);
create index designs_forked_from_idx on public.designs (forked_from_id);
create index designs_current_version_idx on public.designs (current_version_id);
create index design_versions_design_idx on public.design_versions (design_id, version_number desc);
create index design_versions_status_idx on public.design_versions (status);
create index design_versions_source_idx on public.design_versions (source);
create index design_files_file_idx on public.design_files (file_id);

create index personalization_lists_user_idx on public.personalization_lists (user_id);

create index orders_user_created_idx on public.orders (user_id, created_at desc);
create index orders_status_idx on public.orders (status);
create index orders_payment_status_idx on public.orders (payment_status);
create index orders_created_idx on public.orders (created_at desc);
create index order_items_order_idx on public.order_items (order_id);
create index order_items_design_idx on public.order_items (design_id);
create index order_items_design_version_idx on public.order_items (design_version_id);
create index order_items_product_idx on public.order_items (product_id);

create index payments_order_idx on public.payments (order_id);
create index payments_status_idx on public.payments (status);
create index payment_events_payment_idx on public.payment_events (payment_id);

create index invoices_status_idx on public.invoices (status);
create index print_jobs_order_idx on public.print_jobs (order_id);
create index print_jobs_status_idx on public.print_jobs (status);
create index print_files_order_item_idx on public.print_files (order_item_id);
create index print_files_status_idx on public.print_files (status);
create index shipments_order_idx on public.shipments (order_id);
create index shipments_tracking_idx on public.shipments (tracking_number);

create index order_status_history_order_idx on public.order_status_history (order_id, created_at);
create index author_bonuses_author_idx on public.author_bonuses (author_id, status);
create index author_bonuses_design_idx on public.author_bonuses (design_id);

create index moderation_logs_design_idx on public.moderation_logs (design_id);
create index moderation_logs_design_version_idx on public.moderation_logs (design_version_id);
create index moderation_logs_order_idx on public.moderation_logs (order_id);
create index moderation_logs_moderator_idx on public.moderation_logs (moderator_id);
create index design_reports_status_idx on public.design_reports (status);
create index design_reports_design_idx on public.design_reports (design_id);

create index notifications_user_read_idx on public.notifications (user_id, read_at);
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index legal_acceptances_user_idx on public.legal_acceptances (user_id, consent_type);
create index audit_logs_created_idx on public.audit_logs (created_at desc);
create index audit_logs_actor_idx on public.audit_logs (actor_id);
create index audit_logs_entity_idx on public.audit_logs (entity_type, entity_id);
create index idempotency_keys_expires_idx on public.idempotency_keys (expires_at);

-- Глобальна шкала знижок за замовчуванням. Product-specific tiers
-- перекривають її для конкретного товару.
insert into public.discount_tiers (product_id, min_quantity, discount_percent)
select null, v.min_quantity, v.discount_percent
from (values (10, 5.00), (50, 10.00), (100, 15.00))
  as v(min_quantity, discount_percent)
where not exists (
  select 1
  from public.discount_tiers dt
  where dt.product_id is null
    and dt.min_quantity = v.min_quantity
);

-- =============================================================================
-- ДОПОМІЖНІ ФУНКЦІЇ
-- =============================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.users
  where id = auth.uid() and status = 'active';
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and status = 'active'
      and role in ('moderator', 'admin', 'super_admin')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and status = 'active'
      and role in ('admin', 'super_admin')
  );
$$;

create or replace function public.can_view_design(p_design_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.designs d
    where d.id = p_design_id
      and d.deleted_at is null
      and (
        d.status = 'published'
        or d.author_id = auth.uid()
        or public.is_staff()
      )
  );
$$;

create or replace function public.can_view_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.orders o
    where o.id = p_order_id
      and (o.user_id = auth.uid() or public.is_staff())
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, phone, locale)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.phone,
    coalesce(new.raw_user_meta_data->>'locale', 'uk')
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

create or replace function public.prevent_user_privilege_escalation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.role is distinct from old.role
       or new.status is distinct from old.status
       or new.email is distinct from old.email
       or new.created_at is distinct from old.created_at then
      raise exception 'Only an administrator can change role, status, email or created_at';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_last_admin_removal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.role in ('admin', 'super_admin')
     and (new.role not in ('admin', 'super_admin') or new.status <> 'active') then
    if not exists (
      select 1
      from public.users
      where id <> old.id
        and status = 'active'
        and role in ('admin', 'super_admin')
    ) then
      raise exception 'Cannot remove the last active administrator';
    end if;
  end if;
  return new;
end;
$$;

create sequence if not exists public.order_number_seq;
create sequence if not exists public.invoice_number_seq;

create or replace function public.generate_order_number()
returns trigger
language plpgsql
as $$
begin
  if new.order_number is null or new.order_number = '' then
    new.order_number := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-'
      || lpad(nextval('public.order_number_seq')::text, 5, '0');
  end if;
  return new;
end;
$$;

create or replace function public.generate_invoice_number()
returns trigger
language plpgsql
as $$
begin
  if new.number is null or new.number = '' then
    new.number := 'INV-' || to_char(now(), 'YYYY') || '-'
      || lpad(nextval('public.invoice_number_seq')::text, 6, '0');
  end if;
  return new;
end;
$$;

create or replace function public.log_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    insert into public.order_status_history (order_id, from_status, to_status, changed_by)
    values (new.id, old.status, new.status, auth.uid());
  end if;
  return new;
end;
$$;

create or replace function public.recalculate_order_totals(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.orders o
  set subtotal_minor = coalesce((
        select sum(oi.line_subtotal_minor)
        from public.order_items oi
        where oi.order_id = p_order_id
      ), 0),
      discount_minor = coalesce((
        select sum(oi.line_discount_minor)
        from public.order_items oi
        where oi.order_id = p_order_id
      ), 0),
      updated_at = now()
  where o.id = p_order_id;
end;
$$;

create or replace function public.trg_order_items_totals()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_order_totals(coalesce(new.order_id, old.order_id));
  return null;
end;
$$;

create or replace function public.trg_order_delivery_recalc()
returns trigger
language plpgsql
as $$
begin
  perform public.recalculate_order_totals(new.id);
  return null;
end;
$$;

create or replace function public.sync_payment_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'success' and old.status is distinct from 'success' then
    update public.orders
    set payment_status = 'success',
        status = case when status = 'pending_payment' then 'paid'::public.order_status else status end,
        paid_at = coalesce(paid_at, now())
    where id = new.order_id
      and status = 'pending_payment';
  elsif new.status = 'refunded' and old.status is distinct from 'refunded' then
    update public.orders
    set payment_status = 'refunded',
        status = 'refunded',
        refunded_at = now()
    where id = new.order_id
      and status in ('paid', 'on_moderation', 'in_production', 'ready_to_ship', 'shipped', 'delivered');
  end if;
  return new;
end;
$$;

create or replace function public.validate_personalization_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if new.personalization_list_id is not null then
    select row_count into v_count
    from public.personalization_lists
    where id = new.personalization_list_id;

    if v_count is null or v_count <> new.quantity then
      raise exception
        'Personalization names count (%) must equal quantity (%)',
        v_count, new.quantity;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.protect_design_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Прямий доступ з anon/authenticated не може змінювати винагороду,
  -- лічильники або дату публікації. Це робить backend через service_role.
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.author_bonus_percent := 10;
      new.view_count := 0;
      new.order_count := 0;
      new.copies_count := 0;
      new.published_at := null;
    else
      new.author_bonus_percent := old.author_bonus_percent;
      new.view_count := old.view_count;
      new.order_count := old.order_count;
      new.copies_count := old.copies_count;
      new.published_at := old.published_at;
      new.created_at := old.created_at;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_design_publish_fields()
returns trigger
language plpgsql
as $$
begin
  if new.status in ('pending_moderation', 'published') then
    if new.title is null or char_length(new.title) not between 3 and 60 then
      raise exception 'Design title must be 3 to 60 characters before publishing';
    end if;
    if new.canvas = '{}'::jsonb
       or jsonb_typeof(new.canvas->'objects') is distinct from 'array'
       or jsonb_array_length(new.canvas->'objects') = 0 then
      raise exception 'Design canvas must contain at least one object before publishing';
    end if;
    if new.rights_confirmed_at is null then
      raise exception 'Design rights must be confirmed before publishing';
    end if;
  end if;
  if new.status = 'published' and new.published_at is null then
    new.published_at = now();
  end if;
  return new;
end;
$$;

create or replace function public.validate_order_item_design_version()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_design_id uuid;
  v_product_id uuid;
  v_status public.design_version_status;
begin
  if new.design_version_id is not null then
    select design_id, base_product_id, status
      into v_design_id, v_product_id, v_status
    from public.design_versions
    where id = new.design_version_id;

    if v_design_id is null then
      raise exception 'Design version not found';
    end if;
    if new.design_id is distinct from v_design_id then
      raise exception 'Design version does not belong to the selected design';
    end if;
    if new.product_id is distinct from v_product_id then
      raise exception 'Design version does not belong to the selected product';
    end if;
    if v_status not in ('published', 'pending_moderation') then
      raise exception 'Design version is not orderable in status %', v_status;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.enforce_design_version_fields()
returns trigger
language plpgsql
as $$
begin
  if new.source = 'author'
     and new.status in ('pending_moderation', 'published')
     and new.rights_confirmed_at is null then
    raise exception 'Author design version requires confirmed rights before moderation';
  end if;
  if new.status = 'published' and new.published_at is null then
    new.published_at = now();
  end if;
  return new;
end;
$$;

create or replace function public.sync_design_current_version()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.source = 'author' and new.status = 'published' then
    update public.designs
    set current_version_id = new.id,
        status = 'published',
        published_at = coalesce(published_at, now()),
        rejection_reason = null,
        hidden_reason = null,
        updated_at = now()
    where id = new.design_id;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_design_version_content_change()
returns trigger
language plpgsql
as $$
begin
  if old.status in ('pending_moderation', 'published', 'archived') then
    if new.canvas is distinct from old.canvas
       or new.base_product_id is distinct from old.base_product_id
       or new.print_area_id is distinct from old.print_area_id
       or new.preview_file_id is distinct from old.preview_file_id
       or new.rights_confirmed_at is distinct from old.rights_confirmed_at
       or new.author_bonus_percent is distinct from old.author_bonus_percent
       or new.source is distinct from old.source
       or new.version_number is distinct from old.version_number
       or new.design_id is distinct from old.design_id
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Design version content is immutable after moderation starts';
    end if;
    if old.status = 'published'
       and new.status in ('draft', 'pending_moderation', 'rejected') then
      raise exception 'Published design version cannot return to editing';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.prevent_design_content_change()
returns trigger
language plpgsql
as $$
begin
  if old.status in ('pending_moderation', 'published', 'hidden', 'archived') then
    if new.canvas is distinct from old.canvas
       or new.base_product_id is distinct from old.base_product_id
       or new.print_area_id is distinct from old.print_area_id
       or new.forked_from_id is distinct from old.forked_from_id
       or new.author_bonus_percent is distinct from old.author_bonus_percent then
      raise exception 'Design content is immutable after moderation starts';
    end if;
  end if;
  if old.status = 'published'
     and new.status in ('draft', 'pending_moderation', 'rejected') then
    raise exception 'Published design cannot return to editing';
  end if;
  return new;
end;
$$;

create or replace function public.protect_order_item_snapshot()
returns trigger
language plpgsql
as $$
begin
  if new.order_id is distinct from old.order_id
     or new.position is distinct from old.position
     or new.product_id is distinct from old.product_id
     or new.variant_id is distinct from old.variant_id
     or new.design_id is distinct from old.design_id
     or new.design_version_id is distinct from old.design_version_id
     or new.product_name is distinct from old.product_name
     or new.variant_name is distinct from old.variant_name
     or new.unit_price_minor is distinct from old.unit_price_minor
     or new.quantity is distinct from old.quantity
     or new.discount_percent is distinct from old.discount_percent
     or new.is_sample is distinct from old.is_sample
     or new.personalization_list_id is distinct from old.personalization_list_id
     or new.personalization_text_element_id is distinct from old.personalization_text_element_id
     or new.author_bonus_minor is distinct from old.author_bonus_minor
     or new.created_at is distinct from old.created_at then
    raise exception 'Order item snapshot is immutable';
  end if;
  return new;
end;
$$;

-- =============================================================================
-- ТРИГЕРИ
-- =============================================================================

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger on_auth_user_updated
  after update of email on auth.users
  for each row execute function public.handle_new_user();

create trigger users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger users_prevent_escalation
  before update on public.users
  for each row execute function public.prevent_user_privilege_escalation();

create trigger users_prevent_last_admin
  before update of role, status on public.users
  for each row execute function public.prevent_last_admin_removal();

create trigger company_profiles_updated_at
  before update on public.company_profiles
  for each row execute function public.set_updated_at();

create trigger categories_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

create trigger products_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

create trigger product_variants_updated_at
  before update on public.product_variants
  for each row execute function public.set_updated_at();

create trigger print_areas_updated_at
  before update on public.print_areas
  for each row execute function public.set_updated_at();

create trigger designs_updated_at
  before update on public.designs
  for each row execute function public.set_updated_at();

create trigger designs_protect_fields
  before insert or update on public.designs
  for each row execute function public.protect_design_fields();

create trigger designs_publish_fields
  before insert or update on public.designs
  for each row execute function public.enforce_design_publish_fields();

create trigger designs_prevent_content
  before update on public.designs
  for each row execute function public.prevent_design_content_change();

create trigger design_versions_enforce_fields
  before insert or update on public.design_versions
  for each row execute function public.enforce_design_version_fields();

create trigger design_versions_prevent_content
  before update on public.design_versions
  for each row execute function public.prevent_design_version_content_change();

create trigger design_versions_sync_design
  after insert or update of status on public.design_versions
  for each row execute function public.sync_design_current_version();

create trigger orders_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

create trigger orders_generate_number
  before insert on public.orders
  for each row execute function public.generate_order_number();

create trigger orders_status_history
  after update of status on public.orders
  for each row execute function public.log_order_status_change();

create trigger order_items_totals
  after insert or update or delete on public.order_items
  for each row execute function public.trg_order_items_totals();

create trigger orders_delivery_recalc
  after update of delivery_cost_minor on public.orders
  for each row execute function public.trg_order_delivery_recalc();

create trigger order_items_personalization_count
  before insert or update on public.order_items
  for each row execute function public.validate_personalization_count();

create trigger order_items_validate_design_version
  before insert or update on public.order_items
  for each row execute function public.validate_order_item_design_version();

create trigger order_items_protect_snapshot
  before update on public.order_items
  for each row execute function public.protect_order_item_snapshot();

create trigger payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

create trigger payments_status_sync
  after update of status on public.payments
  for each row execute function public.sync_payment_status();

create trigger invoices_updated_at
  before update on public.invoices
  for each row execute function public.set_updated_at();

create trigger invoices_generate_number
  before insert on public.invoices
  for each row execute function public.generate_invoice_number();

create trigger print_files_updated_at
  before update on public.print_files
  for each row execute function public.set_updated_at();

create trigger shipments_updated_at
  before update on public.shipments
  for each row execute function public.set_updated_at();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

alter table public.users enable row level security;
alter table public.company_profiles enable row level security;
alter table public.files enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.print_areas enable row level security;
alter table public.product_images enable row level security;
alter table public.discount_tiers enable row level security;
alter table public.designs enable row level security;
alter table public.design_versions enable row level security;
alter table public.design_files enable row level security;
alter table public.personalization_lists enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.invoices enable row level security;
alter table public.print_jobs enable row level security;
alter table public.print_files enable row level security;
alter table public.shipments enable row level security;
alter table public.order_status_history enable row level security;
alter table public.author_bonuses enable row level security;
alter table public.moderation_logs enable row level security;
alter table public.design_reports enable row level security;
alter table public.notifications enable row level security;
alter table public.legal_acceptances enable row level security;
alter table public.audit_logs enable row level security;
alter table public.idempotency_keys enable row level security;

-- users
create policy users_select on public.users
  for select using (id = auth.uid() or public.is_staff());

create policy users_update_self on public.users
  for update using (id = auth.uid())
  with check (id = auth.uid());

create policy users_admin_all on public.users
  for all using (public.is_admin())
  with check (public.is_admin());

-- company profiles
create policy company_profiles_select on public.company_profiles
  for select using (user_id = auth.uid() or public.is_staff());

create policy company_profiles_upsert on public.company_profiles
  for insert with check (user_id = auth.uid());

create policy company_profiles_update on public.company_profiles
  for update using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

create policy company_profiles_delete on public.company_profiles
  for delete using (user_id = auth.uid() or public.is_admin());

-- files: read-only for clients. Rows are created and updated by backend service_role
-- after signed upload validation.
create policy files_select on public.files
  for select using (
    owner_id = auth.uid()
    or visibility = 'public'
    or public.is_staff()
  );

-- catalog
create policy categories_select on public.categories
  for select using (is_active or public.is_staff());

create policy categories_admin_all on public.categories
  for all using (public.is_admin())
  with check (public.is_admin());

create policy products_select on public.products
  for select using (is_active or public.is_staff());

create policy products_admin_all on public.products
  for all using (public.is_admin())
  with check (public.is_admin());

create policy product_variants_select on public.product_variants
  for select using (
    (
      is_active
      and exists (
        select 1 from public.products p
        where p.id = product_id and p.is_active
      )
    )
    or public.is_staff()
  );

create policy product_variants_admin_all on public.product_variants
  for all using (public.is_admin())
  with check (public.is_admin());

create policy print_areas_select on public.print_areas
  for select using (
    exists (
      select 1 from public.products p
      where p.id = product_id and p.is_active
    )
    or public.is_staff()
  );

create policy print_areas_admin_all on public.print_areas
  for all using (public.is_admin())
  with check (public.is_admin());

create policy product_images_select on public.product_images
  for select using (
    exists (
      select 1 from public.products p
      where p.id = product_id and p.is_active
    )
    or public.is_staff()
  );

create policy product_images_admin_all on public.product_images
  for all using (public.is_admin())
  with check (public.is_admin());

create policy discount_tiers_select on public.discount_tiers
  for select using (
    (
      is_active
      and (
        product_id is null
        or exists (
          select 1 from public.products p
          where p.id = product_id and p.is_active
        )
      )
    )
    or public.is_staff()
  );

create policy discount_tiers_admin_all on public.discount_tiers
  for all using (public.is_admin())
  with check (public.is_admin());

-- designs
create policy designs_select on public.designs
  for select using (
    deleted_at is null
    and (
      status = 'published'
      or author_id = auth.uid()
      or public.is_staff()
    )
  );

create policy designs_insert on public.designs
  for insert with check (author_id = auth.uid() and status = 'draft');

create policy designs_update_owner on public.designs
  for update using (
    author_id = auth.uid()
    and status in ('draft', 'rejected')
  )
  with check (
    author_id = auth.uid()
    and status in ('draft', 'pending_moderation', 'archived')
  );

create policy designs_staff_update on public.designs
  for update using (public.is_staff())
  with check (public.is_staff());

create policy designs_delete on public.designs
  for delete using (
    (author_id = auth.uid() and status in ('draft', 'rejected'))
    or public.is_admin()
  );

-- design_versions: read-only for clients. Public sees published versions only;
-- owner and staff see all versions.
create policy design_versions_select on public.design_versions
  for select using (
    exists (
      select 1
      from public.designs d
      where d.id = public.design_versions.design_id
        and d.deleted_at is null
        and (
          d.author_id = auth.uid()
          or public.is_staff()
          or (
            d.status = 'published'
            and public.design_versions.status = 'published'
          )
        )
    )
  );

-- design_files: read-only for clients. The backend attaches validated files.
create policy design_files_select on public.design_files
  for select using (public.can_view_design(design_id));

-- personalization
create policy personalization_lists_select on public.personalization_lists
  for select using (user_id = auth.uid() or public.is_staff());

create policy personalization_lists_insert on public.personalization_lists
  for insert with check (user_id = auth.uid());

create policy personalization_lists_update on public.personalization_lists
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy personalization_lists_delete on public.personalization_lists
  for delete using (user_id = auth.uid() or public.is_admin());

-- orders: clients read their own; all writes go through the backend transaction.
create policy orders_select on public.orders
  for select using (user_id = auth.uid() or public.is_staff());

create policy orders_admin_update on public.orders
  for update using (public.is_admin())
  with check (public.is_admin());

create policy order_items_select on public.order_items
  for select using (public.can_view_order(order_id));

create policy payments_select on public.payments
  for select using (public.can_view_order(order_id));

create policy invoices_select on public.invoices
  for select using (public.can_view_order(order_id));

create policy shipments_select on public.shipments
  for select using (public.can_view_order(order_id));

create policy order_status_history_select on public.order_status_history
  for select using (public.can_view_order(order_id));

create policy author_bonuses_select on public.author_bonuses
  for select using (author_id = auth.uid() or public.is_staff());

-- moderation
create policy moderation_logs_select on public.moderation_logs
  for select using (public.is_staff());

create policy design_reports_select on public.design_reports
  for select using (reporter_id = auth.uid() or public.is_staff());

create policy design_reports_insert on public.design_reports
  for insert with check (reporter_id = auth.uid());

create policy design_reports_staff_update on public.design_reports
  for update using (public.is_staff())
  with check (public.is_staff());

-- notifications
create policy notifications_select on public.notifications
  for select using (user_id = auth.uid());

create policy notifications_update on public.notifications
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy notifications_delete on public.notifications
  for delete using (user_id = auth.uid() or public.is_admin());

-- legal
create policy legal_acceptances_select on public.legal_acceptances
  for select using (user_id = auth.uid() or public.is_admin());

create policy legal_acceptances_insert on public.legal_acceptances
  for insert with check (user_id = auth.uid());

-- audit
create policy audit_logs_select on public.audit_logs
  for select using (public.is_admin());

-- print jobs and files
create policy print_jobs_select on public.print_jobs
  for select using (public.is_staff());

create policy print_files_select on public.print_files
  for select using (public.is_staff());

-- payment_events and idempotency_keys intentionally have no policies:
-- only service_role can read or write them.

-- =============================================================================
-- ПРИВІЛЕГІЇ
-- =============================================================================

-- У Supabase ці ролі вже існують. Блок потрібен для локального Postgres.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;

grant select on
  public.categories,
  public.products,
  public.product_variants,
  public.print_areas,
  public.product_images,
  public.discount_tiers,
  public.designs,
  public.design_versions,
  public.design_files,
  public.files
to anon, authenticated;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

revoke all on function public.recalculate_order_totals(uuid) from public;
grant execute on function public.recalculate_order_totals(uuid) to authenticated, service_role;

-- =============================================================================
-- КІНЕЦЬ СХЕМИ
-- =============================================================================
