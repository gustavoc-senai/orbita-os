-- ÓRBITA OS v2 · CRM e oportunidades. Executar após migration anterior.
begin;
create table if not exists public.leads (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 email text,
 phone text,
 source text,
 status text not null default 'NEW' check (status in ('NEW','CONTACTED','QUALIFIED','LOST','WON')),
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_leads_org on public.leads(organization_id,created_at desc);
alter table public.leads enable row level security;
create policy leads_select on public.leads for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy leads_insert on public.leads for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy leads_update on public.leads for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy leads_delete on public.leads for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger leads_protect_org before update on public.leads for each row execute function public.prevent_identity_change();
create trigger leads_audit after insert or update or delete on public.leads for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.leads to authenticated;
create table if not exists public.opportunities (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 customer_id uuid references public.customers(id),
 value numeric(14,2) not null default 0 check (value>=0),
 stage text not null default 'DISCOVERY' check (stage in ('DISCOVERY','PROPOSAL','NEGOTIATION','WON','LOST')),
 expected_close_on date,
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_opportunities_org on public.opportunities(organization_id,created_at desc);
alter table public.opportunities enable row level security;
create policy opportunities_select on public.opportunities for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy opportunities_insert on public.opportunities for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy opportunities_update on public.opportunities for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy opportunities_delete on public.opportunities for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger opportunities_protect_org before update on public.opportunities for each row execute function public.prevent_identity_change();
create trigger opportunities_audit after insert or update or delete on public.opportunities for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.opportunities to authenticated;
create or replace function public.opportunities_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger opportunities_customer_tenant_guard before insert or update on public.opportunities for each row execute function public.opportunities_customer_tenant_guard();
commit;
