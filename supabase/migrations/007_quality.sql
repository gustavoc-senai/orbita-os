-- ÓRBITA OS v2 · Qualidade e conformidade. Executar após migration anterior.
begin;
create table if not exists public.inspections (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 customer_id uuid references public.customers(id),
 scheduled_on date,
 status text not null default 'PENDING' check (status in ('PENDING','IN_PROGRESS','APPROVED','REJECTED')),
 findings text,
 created_at timestamptz not null default now()
);
create index if not exists idx_inspections_org on public.inspections(organization_id,created_at desc);
alter table public.inspections enable row level security;
create policy inspections_select on public.inspections for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy inspections_insert on public.inspections for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy inspections_update on public.inspections for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy inspections_delete on public.inspections for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger inspections_protect_org before update on public.inspections for each row execute function public.prevent_identity_change();
create trigger inspections_audit after insert or update or delete on public.inspections for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.inspections to authenticated;
create table if not exists public.nonconformities (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 severity text not null default 'LOW' check (severity in ('LOW','MEDIUM','HIGH','CRITICAL')),
 status text not null default 'OPEN' check (status in ('OPEN','INVESTIGATING','RESOLVED')),
 assigned_to uuid references auth.users(id),
 resolution text,
 created_at timestamptz not null default now()
);
create index if not exists idx_nonconformities_org on public.nonconformities(organization_id,created_at desc);
alter table public.nonconformities enable row level security;
create policy nonconformities_select on public.nonconformities for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy nonconformities_insert on public.nonconformities for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy nonconformities_update on public.nonconformities for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy nonconformities_delete on public.nonconformities for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger nonconformities_protect_org before update on public.nonconformities for each row execute function public.prevent_identity_change();
create trigger nonconformities_audit after insert or update or delete on public.nonconformities for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.nonconformities to authenticated;
create or replace function public.inspections_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger inspections_customer_tenant_guard before insert or update on public.inspections for each row execute function public.inspections_customer_tenant_guard();
create or replace function public.nonconformities_member_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.assigned_to is not null and not exists (select 1 from public.organization_members where organization_id=new.organization_id and user_id=new.assigned_to and status='ACTIVE') then
   raise exception 'Profissional não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger nonconformities_member_tenant_guard before insert or update on public.nonconformities for each row execute function public.nonconformities_member_tenant_guard();
commit;
