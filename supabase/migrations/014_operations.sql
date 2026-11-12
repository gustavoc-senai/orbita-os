-- ÓRBITA OS v2 · Processos e procedimentos. Executar após migration anterior.
begin;
create table if not exists public.procedures (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 category text,
 version text,
 status text not null default 'DRAFT' check (status in ('DRAFT','PUBLISHED','ARCHIVED')),
 instructions text,
 created_at timestamptz not null default now()
);
create index if not exists idx_procedures_org on public.procedures(organization_id,created_at desc);
alter table public.procedures enable row level security;
create policy procedures_select on public.procedures for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy procedures_insert on public.procedures for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy procedures_update on public.procedures for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy procedures_delete on public.procedures for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger procedures_protect_org before update on public.procedures for each row execute function public.prevent_identity_change();
create trigger procedures_audit after insert or update or delete on public.procedures for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.procedures to authenticated;
create table if not exists public.risk_register (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 probability text not null default 'LOW' check (probability in ('LOW','MEDIUM','HIGH')),
 impact text not null default 'LOW' check (impact in ('LOW','MEDIUM','HIGH')),
 status text not null default 'OPEN' check (status in ('OPEN','MITIGATING','CLOSED')),
 mitigation text,
 created_at timestamptz not null default now()
);
create index if not exists idx_risk_register_org on public.risk_register(organization_id,created_at desc);
alter table public.risk_register enable row level security;
create policy risk_register_select on public.risk_register for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy risk_register_insert on public.risk_register for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy risk_register_update on public.risk_register for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy risk_register_delete on public.risk_register for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger risk_register_protect_org before update on public.risk_register for each row execute function public.prevent_identity_change();
create trigger risk_register_audit after insert or update or delete on public.risk_register for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.risk_register to authenticated;

commit;
