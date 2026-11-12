-- ÓRBITA OS v2 · Pessoas e treinamento. Executar após migration anterior.
begin;
create table if not exists public.team_shifts (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 assigned_to uuid references auth.users(id),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_team_shifts_org on public.team_shifts(organization_id,created_at desc);
alter table public.team_shifts enable row level security;
create policy team_shifts_select on public.team_shifts for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy team_shifts_insert on public.team_shifts for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy team_shifts_update on public.team_shifts for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy team_shifts_delete on public.team_shifts for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger team_shifts_protect_org before update on public.team_shifts for each row execute function public.prevent_identity_change();
create trigger team_shifts_audit after insert or update or delete on public.team_shifts for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.team_shifts to authenticated;
create table if not exists public.training_records (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 assigned_to uuid references auth.users(id),
 completed_on date,
 expires_on date,
 status text not null default 'PLANNED' check (status in ('PLANNED','IN_PROGRESS','COMPLETED','EXPIRED')),
 created_at timestamptz not null default now()
);
create index if not exists idx_training_records_org on public.training_records(organization_id,created_at desc);
alter table public.training_records enable row level security;
create policy training_records_select on public.training_records for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy training_records_insert on public.training_records for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy training_records_update on public.training_records for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy training_records_delete on public.training_records for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger training_records_protect_org before update on public.training_records for each row execute function public.prevent_identity_change();
create trigger training_records_audit after insert or update or delete on public.training_records for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.training_records to authenticated;
create or replace function public.team_shifts_member_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.assigned_to is not null and not exists (select 1 from public.organization_members where organization_id=new.organization_id and user_id=new.assigned_to and status='ACTIVE') then
   raise exception 'Profissional não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger team_shifts_member_tenant_guard before insert or update on public.team_shifts for each row execute function public.team_shifts_member_tenant_guard();
create or replace function public.training_records_member_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.assigned_to is not null and not exists (select 1 from public.organization_members where organization_id=new.organization_id and user_id=new.assigned_to and status='ACTIVE') then
   raise exception 'Profissional não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger training_records_member_tenant_guard before insert or update on public.training_records for each row execute function public.training_records_member_tenant_guard();
commit;
