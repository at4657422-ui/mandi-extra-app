-- ===============================================================
-- 0004: एडमिन ख़ुद वीडियो/इमेज/आवाज़/जानकारी/बैनर जोड़-बदल सके (कोड बदले बिना)
-- पढ़ना: सबके लिए (सिर्फ़ प्रकाशित); लिखना: सिर्फ़ एडमिन (2FA के साथ); हर बदलाव audit log में
-- ===============================================================

create or replace function public.can_manage_content() returns boolean
language sql stable security definer set search_path = public as $$
  select public.has_role('admin_super') or public.has_role('admin_ops')
$$;

create table public.site_media (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('video','image','audio')),
  title text not null check (length(title) between 1 and 200),
  storage_path text not null check (storage_path ~ '^[A-Za-z0-9_./-]{1,255}$' and storage_path !~ '\.\.'),
  placement text not null check (placement ~ '^[a-z0-9_:.-]{1,80}$'),   -- जैसे home_banner, category:vehicles, guide:commission
  lang text not null default 'hi' check (lang in ('hi','en','mr','gu','pa','bn','ta','te','kn','ml','or','as','ur')),
  sort_order int not null default 0,
  is_published boolean not null default false,
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);
create index on public.site_media(placement, lang, sort_order) where is_published;

create table public.site_content (
  id uuid primary key default gen_random_uuid(),
  key text not null check (key ~ '^[a-z0-9_:.-]{1,80}$'),
  lang text not null default 'hi' check (lang in ('hi','en','mr','gu','pa','bn','ta','te','kn','ml','or','as','ur')),
  title text check (length(title) <= 200),
  body text not null check (length(body) <= 20000),       -- सादा पाठ: ऐप textContent से दिखाएगा, HTML नहीं
  is_published boolean not null default false,
  updated_by uuid default auth.uid() references public.profiles(id),
  updated_at timestamptz not null default now(),
  unique (key, lang)
);

create table public.banners (
  id uuid primary key default gen_random_uuid(),
  placement text not null check (placement ~ '^[a-z0-9_:.-]{1,80}$'),
  image_path text not null check (image_path ~ '^[A-Za-z0-9_./-]{1,255}$' and image_path !~ '\.\.'),
  link_url text check (link_url is null or link_url ~ '^(https://[A-Za-z0-9._~:/?#@!$&''()*+,;=%-]{1,255}|/[A-Za-z0-9._~/?#=&%-]{0,255})$'),
  is_sponsored boolean not null default false,            -- "विज्ञापन" का निशान अनिवार्य दिखेगा
  starts_at timestamptz, ends_at timestamptz,
  is_active boolean not null default false,
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);

alter table public.site_media enable row level security;
alter table public.site_content enable row level security;
alter table public.banners enable row level security;

create policy media_read on public.site_media for select using (is_published or public.can_manage_content());
create policy media_write on public.site_media for all using (public.can_manage_content()) with check (public.can_manage_content());
create policy content_read on public.site_content for select using (is_published or public.can_manage_content());
create policy content_write on public.site_content for all using (public.can_manage_content()) with check (public.can_manage_content());
create policy banners_read on public.banners for select using (
  (is_active and (starts_at is null or starts_at <= now()) and (ends_at is null or ends_at > now()))
  or public.can_manage_content());
create policy banners_write on public.banners for all using (public.can_manage_content()) with check (public.can_manage_content());

create trigger audit_site_media after insert or update or delete on public.site_media for each row execute function public.write_audit();
create trigger audit_site_content after insert or update or delete on public.site_content for each row execute function public.write_audit();
create trigger audit_banners after insert or update or delete on public.banners for each row execute function public.write_audit();
