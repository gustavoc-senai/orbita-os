-- Limite de uso da IA por usuário e empresa, controlado no servidor.
begin;
create table if not exists public.assistant_usage (
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 window_start timestamptz not null,
 requests integer not null check(requests between 1 and 30),
 primary key(organization_id,user_id,window_start)
);
alter table public.assistant_usage enable row level security;
revoke all on public.assistant_usage from anon,authenticated;
create or replace function public.reserve_assistant_request(p_org uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare v_allowed boolean;
begin
 if auth.uid() is null or not public.has_org_role(p_org,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']) then
  raise exception 'Acesso à IA exige vínculo ativo com a empresa' using errcode='42501';
 end if;
 insert into public.assistant_usage(organization_id,user_id,window_start,requests)
 values(p_org,auth.uid(),date_trunc('hour',now()),1)
 on conflict(organization_id,user_id,window_start) do update
 set requests=public.assistant_usage.requests+1 where public.assistant_usage.requests<30
 returning true into v_allowed;
 return coalesce(v_allowed,false);
end$$;
revoke all on function public.reserve_assistant_request(uuid) from public,anon;
grant execute on function public.reserve_assistant_request(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
