-- ÓRBITA OS v2 · Atendimento e suporte. Executar após migration anterior.
begin;
create table if not exists public.support_tickets (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 subject text not null,
 customer_id uuid references public.customers(id),
 priority text not null default 'LOW' check (priority in ('LOW','NORMAL','HIGH','URGENT')),
 status text not null default 'OPEN' check (status in ('OPEN','IN_PROGRESS','WAITING','CLOSED')),
 description text,
 created_at timestamptz not null default now()
);
create index if not exists idx_support_tickets_org on public.support_tickets(organization_id,created_at desc);
alter table public.support_tickets enable row level security;
create policy support_tickets_select on public.support_tickets for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy support_tickets_insert on public.support_tickets for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy support_tickets_update on public.support_tickets for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy support_tickets_delete on public.support_tickets for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger support_tickets_protect_org before update on public.support_tickets for each row execute function public.prevent_identity_change();
create trigger support_tickets_audit after insert or update or delete on public.support_tickets for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.support_tickets to authenticated;
create table if not exists public.service_requests (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 customer_id uuid references public.customers(id),
 preferred_on date,
 status text not null default 'NEW' check (status in ('NEW','ANALYZING','APPROVED','REJECTED')),
 description text,
 created_at timestamptz not null default now()
);
create index if not exists idx_service_requests_org on public.service_requests(organization_id,created_at desc);
alter table public.service_requests enable row level security;
create policy service_requests_select on public.service_requests for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy service_requests_insert on public.service_requests for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy service_requests_update on public.service_requests for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy service_requests_delete on public.service_requests for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger service_requests_protect_org before update on public.service_requests for each row execute function public.prevent_identity_change();
create trigger service_requests_audit after insert or update or delete on public.service_requests for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.service_requests to authenticated;
create or replace function public.support_tickets_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger support_tickets_customer_tenant_guard before insert or update on public.support_tickets for each row execute function public.support_tickets_customer_tenant_guard();
create or replace function public.service_requests_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger service_requests_customer_tenant_guard before insert or update on public.service_requests for each row execute function public.service_requests_customer_tenant_guard();
commit;
