-- ÓRBITA OS v2 · Financeiro avançado. Executar após migration anterior.
begin;
create table if not exists public.cost_centers (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 code text,
 description text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create index if not exists idx_cost_centers_org on public.cost_centers(organization_id,created_at desc);
alter table public.cost_centers enable row level security;
create policy cost_centers_select on public.cost_centers for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']));
create policy cost_centers_insert on public.cost_centers for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']));
create policy cost_centers_update on public.cost_centers for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']));
create policy cost_centers_delete on public.cost_centers for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger cost_centers_protect_org before update on public.cost_centers for each row execute function public.prevent_identity_change();
create trigger cost_centers_audit after insert or update or delete on public.cost_centers for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.cost_centers to authenticated;
create table if not exists public.financial_goals (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 target_amount numeric(14,2) not null check (target_amount>=0),
 period_start date,
 period_end date,
 status text not null default 'ACTIVE' check (status in ('ACTIVE','COMPLETED','CANCELED')),
 created_at timestamptz not null default now()
);
create index if not exists idx_financial_goals_org on public.financial_goals(organization_id,created_at desc);
alter table public.financial_goals enable row level security;
create policy financial_goals_select on public.financial_goals for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']));
create policy financial_goals_insert on public.financial_goals for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']));
create policy financial_goals_update on public.financial_goals for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']));
create policy financial_goals_delete on public.financial_goals for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger financial_goals_protect_org before update on public.financial_goals for each row execute function public.prevent_identity_change();
create trigger financial_goals_audit after insert or update or delete on public.financial_goals for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.financial_goals to authenticated;

commit;
