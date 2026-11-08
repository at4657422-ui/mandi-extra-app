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
