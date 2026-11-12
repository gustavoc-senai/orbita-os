-- ÓRBITA OS v2 · Compras e suprimentos. Executar após migration anterior.
begin;
create table if not exists public.suppliers (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 tax_id text,
 email text,
 phone text,
 category text,
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_suppliers_org on public.suppliers(organization_id,created_at desc);
alter table public.suppliers enable row level security;
create policy suppliers_select on public.suppliers for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy suppliers_insert on public.suppliers for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy suppliers_update on public.suppliers for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy suppliers_delete on public.suppliers for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger suppliers_protect_org before update on public.suppliers for each row execute function public.prevent_identity_change();
create trigger suppliers_audit after insert or update or delete on public.suppliers for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.suppliers to authenticated;
create table if not exists public.purchase_orders (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 supplier_name text,
 amount numeric(14,2) not null default 0 check (amount>=0),
 status text not null default 'DRAFT' check (status in ('DRAFT','ORDERED','RECEIVED','CANCELED')),
 expected_on date,
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_purchase_orders_org on public.purchase_orders(organization_id,created_at desc);
alter table public.purchase_orders enable row level security;
create policy purchase_orders_select on public.purchase_orders for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy purchase_orders_insert on public.purchase_orders for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy purchase_orders_update on public.purchase_orders for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy purchase_orders_delete on public.purchase_orders for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger purchase_orders_protect_org before update on public.purchase_orders for each row execute function public.prevent_identity_change();
create trigger purchase_orders_audit after insert or update or delete on public.purchase_orders for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.purchase_orders to authenticated;

commit;
