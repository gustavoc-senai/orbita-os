-- ÓRBITA OS v2 · Logística e deslocamentos. Executar após migration anterior.
begin;
create table if not exists public.vehicles (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 plate text,
 model text,
 year numeric(14,2) not null default 0 check (year>=0),
 status text not null default 'ACTIVE' check (status in ('ACTIVE','MAINTENANCE','INACTIVE')),
 created_at timestamptz not null default now()
);
create index if not exists idx_vehicles_org on public.vehicles(organization_id,created_at desc);
alter table public.vehicles enable row level security;
create policy vehicles_select on public.vehicles for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy vehicles_insert on public.vehicles for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy vehicles_update on public.vehicles for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy vehicles_delete on public.vehicles for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger vehicles_protect_org before update on public.vehicles for each row execute function public.prevent_identity_change();
create trigger vehicles_audit after insert or update or delete on public.vehicles for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.vehicles to authenticated;
create table if not exists public.route_stops (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 customer_id uuid references public.customers(id),
 assigned_to uuid references auth.users(id),
 address text,
 scheduled_at timestamptz,
 status text not null default 'PLANNED' check (status in ('PLANNED','ON_THE_WAY','ARRIVED','FINISHED')),
 created_at timestamptz not null default now()
);
create index if not exists idx_route_stops_org on public.route_stops(organization_id,created_at desc);
alter table public.route_stops enable row level security;
create policy route_stops_select on public.route_stops for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy route_stops_insert on public.route_stops for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy route_stops_update on public.route_stops for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy route_stops_delete on public.route_stops for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger route_stops_protect_org before update on public.route_stops for each row execute function public.prevent_identity_change();
create trigger route_stops_audit after insert or update or delete on public.route_stops for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.route_stops to authenticated;
create or replace function public.route_stops_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger route_stops_customer_tenant_guard before insert or update on public.route_stops for each row execute function public.route_stops_customer_tenant_guard();
create or replace function public.route_stops_member_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.assigned_to is not null and not exists (select 1 from public.organization_members where organization_id=new.organization_id and user_id=new.assigned_to and status='ACTIVE') then
   raise exception 'Profissional não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger route_stops_member_tenant_guard before insert or update on public.route_stops for each row execute function public.route_stops_member_tenant_guard();
commit;
