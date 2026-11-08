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
