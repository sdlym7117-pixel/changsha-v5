-- 在 Supabase SQL Editor 执行一次。数据按 auth.uid() 逐用户隔离。
create table if not exists public.trip_documents (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.trip_documents enable row level security;
revoke all on public.trip_documents from anon;
grant select, insert, update on public.trip_documents to authenticated;
drop policy if exists trip_own_select on public.trip_documents;
create policy trip_own_select on public.trip_documents for select to authenticated using (auth.uid() = user_id);
-- 写入仅通过数据库函数（原子版本校验），防止并发覆盖
revoke insert, update on public.trip_documents from authenticated;
create or replace function public.save_trip(expected_revision bigint, new_payload jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare current_rev bigint; new_rev bigint;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if jsonb_typeof(new_payload) <> 'object' then raise exception 'invalid payload'; end if;
  if octet_length(new_payload::text) > 2000000 then raise exception 'payload too large'; end if;
  select revision into current_rev from public.trip_documents where user_id = auth.uid() for update;
  if not found then
    if expected_revision <> -1 then raise exception 'revision conflict'; end if;
    insert into public.trip_documents(user_id,payload,revision) values(auth.uid(),new_payload,1);
    return 1;
  end if;
  if current_rev <> expected_revision then raise exception 'revision conflict'; end if;
  update public.trip_documents set payload=new_payload,revision=revision+1,updated_at=now() where user_id=auth.uid() returning revision into new_rev;
  return new_rev;
end $$;
revoke all on function public.save_trip(bigint,jsonb) from public, anon;
grant execute on function public.save_trip(bigint,jsonb) to authenticated;
