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
-- मंडी एक्स्ट्रा: चरण 1 (भाग 2), सुरक्षा कसना
-- पहले 0001_core_schema.sql चलाइए, फिर इसे।
--
-- इसमें:
--  1. एडमिन के काम तभी चलेंगे जब यूज़र ने 2FA (aal2) पूरा किया हो
--  2. हर संवेदनशील बदलाव का अपने-आप ऑडिट लॉग (मिटाया या बदला नहीं जा सकता)
--  3. रेट लिमिट का फ़ंक्शन (सिर्फ़ सर्वर इस्तेमाल कर सकता है)
--  4. UTR सत्यापन में सत्यापनकर्ता का नाम अपने-आप दर्ज

-- ---------------------------------------------------------------
-- 1. एडमिन = भूमिका + 2FA
-- ---------------------------------------------------------------
create or replace function public.is_aal2() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2';
$$;

create or replace function public.has_role(r public.app_role) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = r and status = 'approved'
  )
  and (r::text not like 'admin\_%' or public.is_aal2());   -- एडमिन भूमिकाओं के लिए 2FA अनिवार्य
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and status = 'approved'
      and role in ('admin_super','admin_ops','admin_finance','admin_moderator','admin_support','admin_readonly')
  ) and public.is_aal2();
$$;

-- ---------------------------------------------------------------
-- 2. ऑडिट लॉग: अपने-आप, और मिटाने/बदलने से सुरक्षित
-- ---------------------------------------------------------------
create or replace function public.write_audit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs (actor_id, action, target_table, target_id, details)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    coalesce((to_jsonb(new) ->> 'id'), (to_jsonb(new) ->> 'key'), (to_jsonb(new) ->> 'user_id')),
    jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new))
  );
  return new;
end $$;

create trigger audit_app_settings after insert or update on public.app_settings
  for each row execute function public.write_audit();
create trigger audit_user_roles after insert or update on public.user_roles
  for each row execute function public.write_audit();
create trigger audit_payments after update on public.payments
  for each row execute function public.write_audit();
create trigger audit_products_status after update of status on public.products
  for each row when (old.status is distinct from new.status)
  execute function public.write_audit();
create trigger audit_profiles_block after update of is_blocked on public.profiles
  for each row when (old.is_blocked is distinct from new.is_blocked)
  execute function public.write_audit();

create or replace function public.audit_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'audit log badla ya mitaya nahi ja sakta';
end $$;

create trigger audit_logs_no_change before update or delete on public.audit_logs
  for each row execute function public.audit_immutable();

-- ---------------------------------------------------------------
-- 3. रेट लिमिट: जैसे 1 मिनट में 4 बार लॉगिन
--    उपयोग (सिर्फ़ सर्वर से): select public.check_rate_limit('login:'||ip, 4, 60);
--    true = अनुमति है, false = बहुत ज़्यादा कोशिशें
-- ---------------------------------------------------------------
create or replace function public.check_rate_limit(p_key text, p_max int, p_window_seconds int)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  w timestamptz := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  total int;
begin
  insert into public.rate_limits (key, window_start, hits) values (p_key, w, 1)
  on conflict (key, window_start) do update set hits = public.rate_limits.hits + 1
  returning hits into total;

  delete from public.rate_limits where window_start < now() - interval '1 day';  -- पुराना कचरा साफ़
  return total <= p_max;
end $$;

revoke all on function public.check_rate_limit(text, int, int) from public, anon, authenticated;
grant execute on function public.check_rate_limit(text, int, int) to service_role;

-- ---------------------------------------------------------------
-- 4. UTR सत्यापन: कौन और कब, सर्वर तय करे (क्लाइंट नहीं)
-- ---------------------------------------------------------------
create or replace function public.stamp_payment_verification() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('verified','rejected') and old.status = 'submitted' then
    new.verified_by := auth.uid();
    new.verified_at := now();
  elsif new.status is distinct from old.status then
    raise exception 'payment ka status is tarah nahi badal sakta';
  end if;
  -- रकम और UTR बाद में बदले नहीं जा सकते
  if new.amount_paise is distinct from old.amount_paise or new.utr is distinct from old.utr then
    raise exception 'amount ya UTR badla nahi ja sakta';
  end if;
  return new;
end $$;

create trigger payments_stamp before update on public.payments
  for each row execute function public.stamp_payment_verification();
-- ===============================================================
-- 0003: एक-पेमेंट कमीशन सिस्टम (सहमत नियम)
--   * ख़रीदार एक ही बार, एक ही UTR से पूरा कमीशन (कुल %) प्लेटफ़ॉर्म को देता है
--   * विक्रेता का आधा हिस्सा ख़रीदार "उसकी ओर से" एडवांस देता है और
--     विक्रेता को सीधे भेजी जाने वाली रक़म में से उतना घटा देता है
--   * प्लेटफ़ॉर्म सामान की मुख्य रक़म कभी नहीं छूता (न वॉलेट, न एस्क्रो)
--   * दर ऑर्डर बनते समय जम जाती है; क्लाइंट से आई रक़म कभी नहीं मानी जाती
-- ⚖️ जानकारों से जँचवाना: एडवांस/समायोजन का GST और कर-व्यवहार
-- ===============================================================

-- ---- 1. दरें (एडमिन बदल सकता है, पर 2% से ऊपर नहीं) ----------
insert into public.app_settings(key, value) values
  ('fee_percent_standard', '2.0'),
  ('fee_percent_worker',   '1.0'),   -- कारीगर/मिस्त्री: कुल 1% (मान्यता, पुष्टि बाक़ी)
  ('fee_percent_company',  '2.0'),   -- कंपनी: कुल 2% (अभी के लिए)
  ('fee_percent_brand',    '2.0'),
  ('unpaid_order_expiry_hours', '48')
on conflict (key) do nothing;

alter table public.seller_profiles
  add column fee_profile text not null default 'standard'
  check (fee_profile in ('standard','worker','company','brand'));

-- विक्रेता अपनी fee_profile ख़ुद नहीं बदल सकता (कम दर लेने की चाल रोकने के लिए)
create or replace function public.protect_fee_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.fee_profile is distinct from old.fee_profile and not public.is_admin() then
    raise exception 'fee_profile sirf admin badal sakta hai';
  end if;
  return new;
end $$;
create trigger seller_fee_profile_guard before update on public.seller_profiles
  for each row execute function public.protect_fee_profile();

-- ---- 2. ऑर्डर में नए कॉलम --------------------------------------
alter table public.orders
  add column deal_value_paise bigint,
  add column buyer_commission_paise bigint,    -- ख़रीदार का अपना आधा
  add column seller_commission_paise bigint,   -- विक्रेता का आधा (ख़रीदार एडवांस देता है)
  add column seller_payout_paise bigint,       -- ख़रीदार विक्रेता को सीधे इतना भेजेगा
  add column creator_id uuid references public.creator_profiles(user_id),
  add column creator_share_paise bigint not null default 0,  -- सिर्फ़ रिकॉर्ड; कुल कमीशन में से
  add column expires_at timestamptz,
  add column cancelled_reason text;

-- पुराने स्टेटस की जगह पूरा रास्ता
alter table public.orders drop constraint orders_status_check;
alter table public.orders add constraint orders_status_check check (status in
  ('placed','commission_submitted','confirmed','dispatched','delivered_by_seller','completed',
   'cancelled','expired','disputed','refunded'));
alter table public.orders alter column commission_percent drop not null;
alter table public.orders alter column commission_paise drop not null;

-- ---- 3. रक़म तय करने वाला एकमात्र फ़ंक्शन --------------------
create or replace function public.compute_commission(p_value bigint, p_percent numeric)
returns table(total bigint, seller_half bigint, buyer_half bigint)
language sql immutable as $$
  select t, t / 2, t - t / 2
  from (select ceil(p_value * p_percent / 100)::bigint as t) x
$$;

create or replace function public.orders_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_profile text; v_pct numeric; v_cap numeric; v_creator_pct numeric;
  c record;
begin
  select fee_profile into v_profile from seller_profiles where id = new.seller_id;
  select value::numeric into v_pct from app_settings where key = 'fee_percent_' || coalesce(v_profile,'standard');
  select value::numeric into v_cap from app_settings where key = 'platform_fee_max_percent';
  v_pct := least(coalesce(v_pct, 2.0), coalesce(v_cap, 2.0), 2.0);

  new.deal_value_paise := round(new.quantity * new.unit_price_paise)::bigint;
  if new.deal_value_paise <= 0 then raise exception 'deal value sahi nahi'; end if;
  new.commission_percent := v_pct;
  select * into c from compute_commission(new.deal_value_paise, v_pct);
  new.commission_paise        := c.total;
  new.buyer_commission_paise  := c.buyer_half;
  new.seller_commission_paise := c.seller_half;
  new.seller_payout_paise     := new.deal_value_paise - c.seller_half;

  -- क्रिएटर का हिस्सा कुल कमीशन के अंदर से (कभी उससे ज़्यादा नहीं)
  if new.creator_id is not null then
    select value::numeric into v_creator_pct from app_settings where key = 'creator_commission_percent';
    new.creator_share_paise := least(c.total, floor(new.deal_value_paise * coalesce(v_creator_pct,0.5) / 100)::bigint);
  end if;

  new.status := 'placed';
  new.expires_at := now() + make_interval(hours =>
    coalesce((select value::int from app_settings where key = 'unpaid_order_expiry_hours'), 48));
  return new;
end $$;
create trigger orders_compute before insert on public.orders
  for each row execute function public.orders_before_insert();

-- रकम के कॉलम बाद में कोई नहीं बदल सकता
create or replace function public.orders_freeze_money() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.deal_value_paise is distinct from old.deal_value_paise
     or new.commission_paise is distinct from old.commission_paise
     or new.commission_percent is distinct from old.commission_percent
     or new.buyer_commission_paise is distinct from old.buyer_commission_paise
     or new.seller_commission_paise is distinct from old.seller_commission_paise
     or new.seller_payout_paise is distinct from old.seller_payout_paise
     or new.creator_share_paise is distinct from old.creator_share_paise
     or new.buyer_id is distinct from old.buyer_id
     or new.seller_id is distinct from old.seller_id then
    raise exception 'order ki raqam/parties badli nahi ja sakti';
  end if;
  return new;
end $$;
create trigger orders_freeze before update on public.orders
  for each row execute function public.orders_freeze_money();

-- ---- 4. ऑर्डर बनाने का सुरक्षित रास्ता (सीधा INSERT बंद) ---------
create or replace function public.create_order(
  p_product_id uuid, p_quantity numeric, p_idempotency_key text, p_creator_id uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_p record; v_id uuid;
begin
  if auth.uid() is null then raise exception 'login zaroori'; end if;
  if public.is_blocked_user() then raise exception 'account blocked'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) < 8 then raise exception 'idempotency key zaroori'; end if;

  select id into v_id from orders where idempotency_key = p_idempotency_key and buyer_id = auth.uid();
  if found then return v_id; end if;           -- दोहराया क्लिक: वही ऑर्डर लौटाओ

  select p.id, p.seller_id, p.price_paise, p.status, s.user_id as seller_user, s.is_suspended
    into v_p from products p join seller_profiles s on s.id = p.seller_id where p.id = p_product_id;
  if not found or v_p.status <> 'active' or v_p.is_suspended then raise exception 'product uplabdh nahi'; end if;
  if v_p.seller_user = auth.uid() then raise exception 'apna hi product nahi khareed sakte'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'matra galat'; end if;
  if p_creator_id is not null and not exists
     (select 1 from creator_profiles where user_id = p_creator_id and status = 'approved') then
    p_creator_id := null;
  end if;

  insert into orders(buyer_id, seller_id, product_id, quantity, unit_price_paise, idempotency_key, creator_id)
  values (auth.uid(), v_p.seller_id, v_p.id, p_quantity, v_p.price_paise, p_idempotency_key, p_creator_id)
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_order(uuid, numeric, text, uuid) from public, anon;
grant execute on function public.create_order(uuid, numeric, text, uuid) to authenticated;

-- ---- 5. पेमेंट (UTR) के नियम ------------------------------------
-- रक़म हमेशा ऑर्डर के कुल कमीशन के बराबर; क्लाइंट की भेजी रक़म ओवरराइड होती है
create or replace function public.payments_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare o record;
begin
  select * into o from orders where id = new.order_id;
  if not found then raise exception 'order nahi mila'; end if;
  if o.buyer_id is distinct from auth.uid() and auth.uid() is not null then
    raise exception 'sirf khareedar UTR jama kar sakta hai';
  end if;
  if o.status <> 'placed' then raise exception 'is order par ab payment nahi ho sakti'; end if;
  if o.expires_at < now() then raise exception 'order ki samay-seema khatam'; end if;
  new.amount_paise := o.commission_paise;
  new.status := 'submitted';
  return new;
end $$;
create trigger payments_compute before insert on public.payments
  for each row execute function public.payments_before_insert();

-- एक ऑर्डर पर एक समय में एक ही सक्रिय पेमेंट
create unique index payments_one_active_per_order on public.payments(order_id)
  where status in ('submitted','verified');

-- ऑर्डर का स्टेटस पेमेंट के साथ अपने-आप चले
create or replace function public.payments_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update orders set status = 'commission_submitted' where id = new.order_id and status = 'placed';
  elsif new.status = 'verified' and old.status = 'submitted' then
    update orders set status = 'confirmed' where id = new.order_id;
  elsif new.status = 'rejected' and old.status = 'submitted' then
    update orders set status = 'placed' where id = new.order_id;
  end if;
  return null;
end $$;
create trigger payments_status_sync after insert or update on public.payments
  for each row execute function public.payments_after_change();

-- ---- 6. डिलीवरी की दोनों-तरफ़ पुष्टि -----------------------------
-- विक्रेता: confirmed -> dispatched -> delivered_by_seller; ख़रीदार: -> completed
create or replace function public.advance_order(p_order uuid, p_to text)
returns void language plpgsql security definer set search_path = public as $$
declare o record; v_seller_user uuid;
begin
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'order nahi mila'; end if;
  select user_id into v_seller_user from seller_profiles where id = o.seller_id;

  if p_to = 'dispatched' and auth.uid() = v_seller_user and o.status = 'confirmed' then
    update orders set status = 'dispatched' where id = p_order;
  elsif p_to = 'delivered_by_seller' and auth.uid() = v_seller_user and o.status = 'dispatched' then
    update orders set status = 'delivered_by_seller' where id = p_order;
  elsif p_to = 'completed' and auth.uid() = o.buyer_id and o.status in ('dispatched','delivered_by_seller') then
    update orders set status = 'completed' where id = p_order;      -- सिर्फ़ ख़रीदार की "हाँ"
  elsif p_to = 'disputed' and auth.uid() in (o.buyer_id, v_seller_user)
        and o.status in ('confirmed','dispatched','delivered_by_seller') then
    update orders set status = 'disputed' where id = p_order;
  elsif p_to = 'cancelled' and auth.uid() = o.buyer_id and o.status = 'placed' then
    update orders set status = 'cancelled', cancelled_reason = 'buyer' where id = p_order;
  else
    raise exception 'yeh badlav is samay allowed nahi';
  end if;
end $$;
revoke all on function public.advance_order(uuid, text) from public, anon;
grant execute on function public.advance_order(uuid, text) to authenticated;

-- समय-सीमा: बिना पेमेंट के ऑर्डर अपने-आप समाप्त (cron/service_role से चलेगा)
create or replace function public.expire_unpaid_orders() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update orders set status = 'expired', cancelled_reason = 'unpaid_timeout'
   where status = 'placed' and expires_at < now();
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.expire_unpaid_orders() from public, anon, authenticated;
grant execute on function public.expire_unpaid_orders() to service_role;

-- ---- 7. रिफ़ंड का रिकॉर्ड (हाथ से, अलग UTR) ---------------------
create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  amount_paise bigint not null check (amount_paise > 0),
  refund_utr text not null check (refund_utr ~ '^[0-9]{12}$') unique,
  reason text not null,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.refunds enable row level security;
create policy refunds_read on public.refunds for select using (
  exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid())
  or public.is_admin());
create policy refunds_write on public.refunds for insert
  with check (public.has_role('admin_finance') or public.has_role('admin_super'));
create trigger refunds_immutable before update or delete on public.refunds
  for each row execute function public.audit_immutable();   -- 0002 का फ़ंक्शन: रिकॉर्ड बदलता/मिटता नहीं

-- क्लाइंट सीधे orders में लिख न सके
revoke insert, update, delete on public.orders from anon, authenticated;
