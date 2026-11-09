create table public.login_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  ip text,
  device_hash text not null check (device_hash ~ '^[A-Za-z0-9_-]{8,64}$'),
  new_device boolean not null default false,
  flag text check (flag in ('shared_ip','many_devices')),
  created_at timestamptz not null default now()
);
create index on public.login_events(user_id, created_at desc);
create index on public.login_events(ip, created_at desc);
alter table public.login_events enable row level security;
create policy login_events_read on public.login_events for select using (user_id = auth.uid() or public.is_admin());
revoke insert, update, delete on public.login_events from anon, authenticated;
create trigger login_events_immutable before update or delete on public.login_events
  for each row execute function public.audit_immutable();

create or replace function public.record_login(p_device text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  hdr json;
  v_ip text;
  v_new boolean;
  v_first boolean;
  v_flag text;
begin
  if uid is null then raise exception 'login zaroori'; end if;
  if p_device is null or p_device !~ '^[A-Za-z0-9_-]{8,64}$' then raise exception 'bad device'; end if;
  begin
    hdr := current_setting('request.headers', true)::json;
    v_ip := trim(split_part(coalesce(hdr->>'cf-connecting-ip', hdr->>'x-forwarded-for', ''), ',', 1));
  exception when others then v_ip := null; end;
  if v_ip = '' then v_ip := null; end if;
  select not exists (select 1 from public.login_events where user_id = uid) into v_first;
  select not exists (select 1 from public.login_events where user_id = uid and device_hash = p_device) into v_new;
  if v_ip is not null and (select count(distinct user_id) from public.login_events where ip = v_ip and created_at > now() - interval '1 hour' and user_id <> uid) >= 5 then
    v_flag := 'shared_ip';
  elsif (select count(distinct device_hash) from public.login_events where user_id = uid and created_at > now() - interval '24 hours') >= 5 and v_new then
    v_flag := 'many_devices';
  end if;
  insert into public.login_events (user_id, ip, device_hash, new_device, flag) values (uid, v_ip, p_device, v_new, v_flag);
  if v_flag is not null then
    insert into public.audit_logs (actor_id, action, target_table, target_id, details)
    values (uid, 'login_flag_' || v_flag, 'login_events', uid::text, jsonb_build_object('ip', v_ip));
  end if;
  return jsonb_build_object('new_device', v_new and not v_first, 'flag', v_flag);
end $$;
revoke all on function public.record_login(text) from public, anon;
grant execute on function public.record_login(text) to authenticated;
