-- ÓRBITA OS v2 · Marketing e campanhas. Executar após migration anterior.
begin;
create table if not exists public.campaigns (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 channel text not null default 'EMAIL' check (channel in ('EMAIL','WHATSAPP','SOCIAL','OTHER')),
 budget numeric(14,2) not null default 0 check (budget>=0),
 starts_on date,
 ends_on date,
 status text not null default 'DRAFT' check (status in ('DRAFT','ACTIVE','PAUSED','FINISHED')),
 created_at timestamptz not null default now()
);
create index if not exists idx_campaigns_org on public.campaigns(organization_id,created_at desc);
alter table public.campaigns enable row level security;
create policy campaigns_select on public.campaigns for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy campaigns_insert on public.campaigns for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy campaigns_update on public.campaigns for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy campaigns_delete on public.campaigns for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger campaigns_protect_org before update on public.campaigns for each row execute function public.prevent_identity_change();
create trigger campaigns_audit after insert or update or delete on public.campaigns for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.campaigns to authenticated;
create table if not exists public.referral_partners (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 email text,
 phone text,
 commission_rate numeric(14,2) not null default 0 check (commission_rate>=0),
 status text not null default 'ACTIVE' check (status in ('ACTIVE','INACTIVE')),
 created_at timestamptz not null default now()
);
create index if not exists idx_referral_partners_org on public.referral_partners(organization_id,created_at desc);
alter table public.referral_partners enable row level security;
create policy referral_partners_select on public.referral_partners for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy referral_partners_insert on public.referral_partners for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy referral_partners_update on public.referral_partners for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy referral_partners_delete on public.referral_partners for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger referral_partners_protect_org before update on public.referral_partners for each row execute function public.prevent_identity_change();
create trigger referral_partners_audit after insert or update or delete on public.referral_partners for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.referral_partners to authenticated;

commit;
