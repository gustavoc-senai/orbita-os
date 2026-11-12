-- ÓRBITA OS v2 · Relacionamento e fidelização. Executar após migration anterior.
begin;
create table if not exists public.customer_segments (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 description text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create index if not exists idx_customer_segments_org on public.customer_segments(organization_id,created_at desc);
alter table public.customer_segments enable row level security;
create policy customer_segments_select on public.customer_segments for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy customer_segments_insert on public.customer_segments for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_segments_update on public.customer_segments for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_segments_delete on public.customer_segments for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger customer_segments_protect_org before update on public.customer_segments for each row execute function public.prevent_identity_change();
create trigger customer_segments_audit after insert or update or delete on public.customer_segments for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.customer_segments to authenticated;
create table if not exists public.loyalty_rewards (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 points_required numeric(14,2) not null default 0 check (points_required>=0),
 description text,
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create index if not exists idx_loyalty_rewards_org on public.loyalty_rewards(organization_id,created_at desc);
alter table public.loyalty_rewards enable row level security;
create policy loyalty_rewards_select on public.loyalty_rewards for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy loyalty_rewards_insert on public.loyalty_rewards for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy loyalty_rewards_update on public.loyalty_rewards for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy loyalty_rewards_delete on public.loyalty_rewards for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger loyalty_rewards_protect_org before update on public.loyalty_rewards for each row execute function public.prevent_identity_change();
create trigger loyalty_rewards_audit after insert or update or delete on public.loyalty_rewards for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.loyalty_rewards to authenticated;

commit;
