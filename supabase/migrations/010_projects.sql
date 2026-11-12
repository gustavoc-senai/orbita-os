-- ÓRBITA OS v2 · Projetos e entregáveis. Executar após migration anterior.
begin;
create table if not exists public.projects (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 customer_id uuid references public.customers(id),
 budget numeric(14,2) not null default 0 check (budget>=0),
 start_on date,
 deadline_on date,
 status text not null default 'PLANNED' check (status in ('PLANNED','ACTIVE','ON_HOLD','FINISHED')),
 description text,
 created_at timestamptz not null default now()
);
create index if not exists idx_projects_org on public.projects(organization_id,created_at desc);
alter table public.projects enable row level security;
create policy projects_select on public.projects for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy projects_insert on public.projects for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy projects_update on public.projects for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy projects_delete on public.projects for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger projects_protect_org before update on public.projects for each row execute function public.prevent_identity_change();
create trigger projects_audit after insert or update or delete on public.projects for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.projects to authenticated;
create table if not exists public.project_milestones (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 due_on date,
 status text not null default 'PENDING' check (status in ('PENDING','IN_PROGRESS','DONE','BLOCKED')),
 owner_name text,
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_project_milestones_org on public.project_milestones(organization_id,created_at desc);
alter table public.project_milestones enable row level security;
create policy project_milestones_select on public.project_milestones for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy project_milestones_insert on public.project_milestones for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy project_milestones_update on public.project_milestones for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy project_milestones_delete on public.project_milestones for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger project_milestones_protect_org before update on public.project_milestones for each row execute function public.prevent_identity_change();
create trigger project_milestones_audit after insert or update or delete on public.project_milestones for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.project_milestones to authenticated;
create or replace function public.projects_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger projects_customer_tenant_guard before insert or update on public.projects for each row execute function public.projects_customer_tenant_guard();
commit;
