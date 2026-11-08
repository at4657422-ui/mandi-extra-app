-- मंडी एक्स्ट्रा: चरण 1, मुख्य डेटाबेस (Supabase / PostgreSQL)
-- इसे Supabase Dashboard -> SQL Editor में पेस्ट करके Run दबाइए।
-- सारी तालिकाओं पर Row Level Security (RLS) चालू है। नियम स्पष्ट न हों तो पहुँच बंद रहती है।

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------
-- 1. भूमिकाएँ और प्रोफ़ाइल
-- ---------------------------------------------------------------
create type public.app_role as enum (
  'buyer','seller','farmer','service_provider','transport_provider',
  'store_owner','creator','delivery_partner',
  'admin_super','admin_ops','admin_finance','admin_moderator','admin_support','admin_readonly'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  language text not null default 'hi' check (language in ('hi','en')),
  district text,
  state text,   -- हर यूज़र अपना राज्य चुनेगा (पूरे भारत के लिए)
  is_blocked boolean not null default false,
  blocked_reason text,
  created_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

-- सहायक फ़ंक्शन (security definer: RLS में खुद पर लूप न बने)
create or replace function public.has_role(r public.app_role) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles
                 where user_id = auth.uid() and role = r and status = 'approved');
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles
                 where user_id = auth.uid() and status = 'approved'
                   and role in ('admin_super','admin_ops','admin_finance','admin_moderator','admin_support','admin_readonly'));
$$;

create or replace function public.is_blocked_user() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_blocked from public.profiles where id = auth.uid()), false);
$$;

-- नया यूज़र बनते ही प्रोफ़ाइल और 'buyer' भूमिका अपने आप बने
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name) values (new.id, new.raw_user_meta_data->>'full_name');
  insert into public.user_roles (user_id, role, status) values (new.id, 'buyer', 'approved');
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------
-- 2. एडमिन सेटिंग (कमीशन आदि कोड में नहीं, यहाँ रहेगा)
-- ---------------------------------------------------------------
create table public.app_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

insert into public.app_settings (key, value) values
  ('platform_fee_percent', '2.0'),
  ('platform_fee_max_percent', '2.0'),   -- सख़्त सीमा: इससे ऊपर कोई नहीं बढ़ा सकता
  ('creator_commission_percent', '0.5'),
  ('creator_approval_delay_minutes', '30'),
  ('upi_id_for_commission', 'null'::jsonb); -- एडमिन पैनल से ख़ुद भरें, कोड में न डालें

-- ---------------------------------------------------------------
-- 3. कैटेगरी (एडमिन बदल सकता है, कोड में तय नहीं)
-- ---------------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id),
  slug text unique not null,
  name_hi text not null,
  name_en text not null,
  color_hex text not null default '#0F766E',
  icon text,
  requires_approval boolean not null default false,  -- गाड़ी, ज़मीन, पशु आदि के लिए true
  is_active boolean not null default true,
  sort_order int not null default 0
);

insert into public.categories (slug, name_hi, name_en, color_hex, requires_approval, sort_order) values
  ('construction','निर्माण सामग्री','Construction','#B45309', false, 1),
  ('agriculture','खेती और मंडी','Agriculture','#15803D', false, 2),
  ('food','खाद्य और किराना','Food & Grocery','#C2410C', false, 3),
  ('electronics','इलेक्ट्रॉनिक्स','Electronics','#1D4ED8', false, 4),
  ('furniture','फ़र्नीचर और घर','Furniture & Home','#7C3AED', false, 5),
  ('fashion','कपड़े और फ़ैशन','Fashion','#BE185D', false, 6),
  ('vehicles','वाहन (पुराने/नए)','Vehicles','#0E7490', true, 7),
  ('livestock','पशुधन','Livestock','#92400E', true, 8),
  ('land','ज़मीन और खेत','Land & Property','#4D7C0F', true, 9),
  ('services','सेवाएँ','Services','#0F766E', false, 10);

-- ---------------------------------------------------------------
-- 4. विक्रेता, स्टोर, प्रोडक्ट
-- ---------------------------------------------------------------
create sequence public.seller_code_seq start 1000;

create table public.seller_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique not null references public.profiles(id) on delete cascade,
  seller_code text unique not null default ('MX' || nextval('public.seller_code_seq')),
  business_name text not null,
  contact_phone text,           -- ख़रीदार को बातचीत के लिए दिखेगा (विक्रेता की सहमति से)
  address_line text,            -- निजी: सार्वजनिक नहीं
  district text,
  state text,   -- हर यूज़र अपना राज्य चुनेगा (पूरे भारत के लिए)
  verification_status text not null default 'basic'
    check (verification_status in ('basic','submitted','verified','rejected')),
  is_suspended boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.seller_profiles(id) on delete cascade,
  slug text unique not null check (slug ~ '^[a-z0-9-]{3,40}$'),
  name text not null,
  description text,
  rank_score numeric not null default 0,     -- रैंकिंग (नंबर 1, 2...) एडमिन/नियम से
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.seller_profiles(id) on delete cascade,
  store_id uuid references public.stores(id) on delete set null,
  category_id uuid not null references public.categories(id),
  title text not null check (char_length(title) between 3 and 150),
  description text,
  price_paise bigint not null check (price_paise >= 0),   -- पैसे में, दशमलव की गड़बड़ी से बचने के लिए
  unit text not null default 'piece',
  stock numeric not null default 0 check (stock >= 0),
  district text,
  status text not null default 'pending'
    check (status in ('draft','pending','active','rejected','paused','sold_out','archived')),
  created_at timestamptz not null default now()
);
create index products_cat_status_idx on public.products (category_id, status);
create index products_seller_idx on public.products (seller_id);

-- ---------------------------------------------------------------
-- 5. ऑर्डर और पेमेंट (UTR से)
-- ---------------------------------------------------------------
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.seller_profiles(id),
  product_id uuid not null references public.products(id),
  quantity numeric not null check (quantity > 0),
  unit_price_paise bigint not null,
  commission_percent numeric not null,      -- ऑर्डर के समय की दर, बाद में बदलाव से असर नहीं
  commission_paise bigint not null,
  status text not null default 'placed'
    check (status in ('placed','commission_pending','confirmed','dispatched','completed','cancelled','disputed')),
  idempotency_key text unique,              -- दोहराए गए क्लिक से डुप्लीकेट ऑर्डर नहीं
  created_at timestamptz not null default now(),
  -- कमीशन कभी तय सीमा से ऊपर न जाए (डेटाबेस स्तर की सुरक्षा)
  constraint commission_cap check (commission_percent <= 2.0)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  amount_paise bigint not null check (amount_paise > 0),
  utr text not null check (utr ~ '^[0-9]{12}$'),
  status text not null default 'submitted' check (status in ('submitted','verified','rejected')),
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (utr)                              -- एक UTR दो बार नहीं चल सकता
);

-- ---------------------------------------------------------------
-- 6. क्रिएटर और रेफ़रल
-- ---------------------------------------------------------------
create table public.creator_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  handle text unique not null check (handle ~ '^[a-z0-9_]{3,30}$'),
  instagram_handle text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  agreed_to_rules_at timestamptz,
  applied_at timestamptz not null default now()
);

create table public.referral_clicks (
  id bigint generated always as identity primary key,
  creator_id uuid not null references public.creator_profiles(user_id),
  product_id uuid references public.products(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- 7. सुरक्षा: ऑडिट लॉग और रेट लिमिट
-- ---------------------------------------------------------------
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  target_table text,
  target_id text,
  details jsonb,
  created_at timestamptz not null default now()
);

create table public.rate_limits (
  key text not null,                 -- जैसे 'login:<ip>' या 'otp:<ईमेल>'
  window_start timestamptz not null,
  hits int not null default 1,
  primary key (key, window_start)
);

-- ---------------------------------------------------------------
-- 8. Row Level Security
-- ---------------------------------------------------------------
alter table public.profiles          enable row level security;
alter table public.user_roles        enable row level security;
alter table public.app_settings      enable row level security;
alter table public.categories        enable row level security;
alter table public.seller_profiles   enable row level security;
alter table public.stores            enable row level security;
alter table public.products          enable row level security;
alter table public.orders            enable row level security;
alter table public.payments          enable row level security;
alter table public.creator_profiles  enable row level security;
alter table public.referral_clicks   enable row level security;
alter table public.audit_logs        enable row level security;
alter table public.rate_limits       enable row level security;

-- profiles: अपनी प्रोफ़ाइल देखो/बदलो; एडमिन सब देखे। is_blocked खुद नहीं बदल सकते (नीचे trigger)।
create policy profiles_self_read   on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy profiles_self_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy profiles_admin_update on public.profiles for update using (public.has_role('admin_super') or public.has_role('admin_ops'));

create or replace function public.protect_profile_flags() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() and (new.is_blocked is distinct from old.is_blocked
                                or new.blocked_reason is distinct from old.blocked_reason) then
    raise exception 'is field ko badalne ki anumati nahi hai';
  end if;
  return new;
end $$;
create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_profile_flags();

-- user_roles: अपनी भूमिकाएँ देखो; आवेदन सिर्फ़ 'pending' में कर सकते हो; मंज़ूरी सिर्फ़ एडमिन।
create policy roles_self_read on public.user_roles for select using (user_id = auth.uid() or public.is_admin());
create policy roles_apply on public.user_roles for insert
  with check (user_id = auth.uid() and status = 'pending'
              and role not in ('admin_super','admin_ops','admin_finance','admin_moderator','admin_support','admin_readonly'));
create policy roles_admin_manage on public.user_roles for update using (public.has_role('admin_super') or public.has_role('admin_ops'));

-- app_settings: सबको पढ़ने की छूट सिर्फ़ गैर-संवेदनशील कुंजियों की; बदलाव सिर्फ़ super admin।
create policy settings_public_read on public.app_settings for select
  using (key in ('platform_fee_percent','creator_commission_percent') or public.is_admin());
create policy settings_super_write on public.app_settings for all
  using (public.has_role('admin_super')) with check (public.has_role('admin_super'));

-- categories: सब पढ़ें, एडमिन बदले
create policy categories_read on public.categories for select using (is_active or public.is_admin());
create policy categories_admin on public.categories for all
  using (public.is_admin() and not public.has_role('admin_readonly'))
  with check (public.is_admin() and not public.has_role('admin_readonly'));

-- seller_profiles: अपना पूरा, बाकी के लिए view (नीचे) जिसमें पता नहीं है
create policy sellers_self on public.seller_profiles for all
  using (user_id = auth.uid() and not public.is_blocked_user())
  with check (user_id = auth.uid() and not public.is_blocked_user());
create policy sellers_admin_read on public.seller_profiles for select using (public.is_admin());

create view public.seller_public as
  select id, seller_code, business_name, district, state, verification_status
  from public.seller_profiles where not is_suspended;
grant select on public.seller_public to anon, authenticated;

-- stores / products: सब सिर्फ़ प्रकाशित/सक्रिय देखें; मालिक अपना सँभाले
create policy stores_public_read on public.stores for select using (is_published);
create policy stores_owner on public.stores for all
  using (exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid()))
  with check (exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid()));
create policy products_public_read on public.products for select using (status = 'active');
create policy products_owner_read on public.products for select
  using (exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid()));
create policy products_owner_write on public.products for insert
  with check (status in ('draft','pending')   -- विक्रेता खुद 'active' नहीं कर सकता
              and exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid() and not s.is_suspended));
create policy products_owner_update on public.products for update
  using (exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid()))
  with check (status in ('draft','pending','paused','archived')
              and exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid()));
create policy products_admin on public.products for update
  using (public.is_admin() and not public.has_role('admin_readonly'));

-- orders: ख़रीदार या संबंधित विक्रेता या एडमिन देखे। बनाना सर्वर फ़ंक्शन से होगा (सीधे नहीं)।
create policy orders_read on public.orders for select using (
  buyer_id = auth.uid()
  or exists (select 1 from public.seller_profiles s where s.id = seller_id and s.user_id = auth.uid())
  or public.is_admin());

-- payments: ख़रीदार अपना UTR जमा करे और देखे; सत्यापन सिर्फ़ finance/super admin
create policy payments_read on public.payments for select using (
  exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid())
  or public.is_admin());
create policy payments_submit on public.payments for insert with check (
  status = 'submitted' and exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid()));
create policy payments_verify on public.payments for update
  using (public.has_role('admin_finance') or public.has_role('admin_super'));

-- creator
create policy creators_self on public.creator_profiles for select using (user_id = auth.uid() or public.is_admin());
create policy creators_apply on public.creator_profiles for insert with check (user_id = auth.uid() and status = 'pending');
create policy creators_admin on public.creator_profiles for update using (public.is_admin() and not public.has_role('admin_readonly'));
create policy clicks_creator_read on public.referral_clicks for select using (creator_id = auth.uid() or public.is_admin());

-- audit_logs: सिर्फ़ एडमिन पढ़े; लिखना सिर्फ़ सर्वर (service role) से; कोई delete/update नहीं।
create policy audit_admin_read on public.audit_logs for select using (public.is_admin());

-- rate_limits: कोई नीति नहीं => सिर्फ़ सर्वर (service role) पहुँच सकता है।
