-- ===============================================================
-- 0005: सहमति का अपरिवर्तनीय रिकॉर्ड (टाइमस्टैम्प के साथ) और डेटा-मिटाने का अनुरोध
-- DPDP: असली सहमति, वापसी उतनी ही आसान, 18+ घोषणा, मिटाने से 48 घंटे पहले सूचना
-- ⚖️ नोटिस का शब्द-पाठ और संस्करण जानकार से जँचवाएँ
-- ===============================================================
create table public.consents (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  purpose text not null check (purpose in ('privacy_notice','age_18plus','marketing','media_access','location')),
  granted boolean not null,
  notice_version text not null check (notice_version ~ '^[A-Za-z0-9._-]{1,20}$'),
  created_at timestamptz not null default now()
);
create index on public.consents(user_id, purpose, created_at desc);
alter table public.consents enable row level security;
create policy consents_read_own on public.consents for select using (user_id = auth.uid() or public.is_admin());
-- सीधा INSERT नहीं; सिर्फ़ फ़ंक्शन से (वापसी भी नई पंक्ति बनती है, पुरानी बदलती नहीं)
revoke insert, update, delete on public.consents from anon, authenticated;
create trigger consents_immutable before update or delete on public.consents
  for each row execute function public.audit_immutable();

create or replace function public.record_consent(p_purpose text, p_granted boolean, p_version text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'login zaroori'; end if;
  insert into consents(user_id, purpose, granted, notice_version) values (auth.uid(), p_purpose, p_granted, p_version);
end $$;
revoke all on function public.record_consent(text, boolean, text) from public, anon;
grant execute on function public.record_consent(text, boolean, text) to authenticated;

-- ज़रूरी सहमति (नोटिस + 18+) के बिना खाता "पूरा" नहीं माना जाएगा
create or replace function public.has_required_consent() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select granted from consents where user_id = auth.uid() and purpose = 'privacy_notice' order by id desc limit 1), false)
     and coalesce((select granted from consents where user_id = auth.uid() and purpose = 'age_18plus'    order by id desc limit 1), false)
$$;
grant execute on function public.has_required_consent() to authenticated;

create table public.deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null default (now() + interval '48 hours'),   -- 48 घंटे पहले सूचना
  status text not null default 'pending' check (status in ('pending','cancelled','done'))
);
create unique index deletion_one_pending on public.deletion_requests(user_id) where status = 'pending';
alter table public.deletion_requests enable row level security;
create policy deletion_read_own on public.deletion_requests for select using (user_id = auth.uid() or public.is_admin());
revoke insert, update, delete on public.deletion_requests from anon, authenticated;

create or replace function public.request_deletion() returns timestamptz
language plpgsql security definer set search_path = public as $$
declare t timestamptz;
begin
  if auth.uid() is null then raise exception 'login zaroori'; end if;
  insert into deletion_requests(user_id) values (auth.uid()) on conflict do nothing;
  select scheduled_for into t from deletion_requests where user_id = auth.uid() and status = 'pending';
  return t;
end $$;
create or replace function public.cancel_deletion() returns void
language sql security definer set search_path = public as $$
  update deletion_requests set status = 'cancelled' where user_id = auth.uid() and status = 'pending'
$$;
revoke all on function public.request_deletion(), public.cancel_deletion() from public, anon;
grant execute on function public.request_deletion(), public.cancel_deletion() to authenticated;
