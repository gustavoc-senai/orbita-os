-- ÓRBITA OS v2 · Pós-venda e satisfação. Executar após migration anterior.
begin;
create table if not exists public.customer_feedback (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 customer_id uuid references public.customers(id),
 rating numeric(14,2) not null check (rating>=0),
 comments text,
 status text not null default 'NEW' check (status in ('NEW','REVIEWED','RESOLVED')),
 created_at timestamptz not null default now()
);
create index if not exists idx_customer_feedback_org on public.customer_feedback(organization_id,created_at desc);
alter table public.customer_feedback enable row level security;
create policy customer_feedback_select on public.customer_feedback for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy customer_feedback_insert on public.customer_feedback for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_feedback_update on public.customer_feedback for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_feedback_delete on public.customer_feedback for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger customer_feedback_protect_org before update on public.customer_feedback for each row execute function public.prevent_identity_change();
create trigger customer_feedback_audit after insert or update or delete on public.customer_feedback for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.customer_feedback to authenticated;
create table if not exists public.follow_ups (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,
 customer_id uuid references public.customers(id),
 next_contact_on date,
 channel text not null default 'PHONE' check (channel in ('PHONE','EMAIL','WHATSAPP','MEETING')),
 status text not null default 'OPEN' check (status in ('OPEN','DONE','CANCELED')),
 notes text,
 created_at timestamptz not null default now()
);
create index if not exists idx_follow_ups_org on public.follow_ups(organization_id,created_at desc);
alter table public.follow_ups enable row level security;
create policy follow_ups_select on public.follow_ups for select to authenticated using (public.has_org_role(organization_id, array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy follow_ups_insert on public.follow_ups for insert to authenticated with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy follow_ups_update on public.follow_ups for update to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check (public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy follow_ups_delete on public.follow_ups for delete to authenticated using (public.has_org_role(organization_id,array['OWNER','ADMIN']));
create trigger follow_ups_protect_org before update on public.follow_ups for each row execute function public.prevent_identity_change();
create trigger follow_ups_audit after insert or update or delete on public.follow_ups for each row execute function public.audit_operational_change();
grant select,insert,update,delete on public.follow_ups to authenticated;
create or replace function public.customer_feedback_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger customer_feedback_customer_tenant_guard before insert or update on public.customer_feedback for each row execute function public.customer_feedback_customer_tenant_guard();
create or replace function public.follow_ups_customer_tenant_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if new.customer_id is not null and not exists (select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then
   raise exception 'Cliente não pertence a esta empresa';
 end if;
 return new;
end; $$;
create trigger follow_ups_customer_tenant_guard before insert or update on public.follow_ups for each row execute function public.follow_ups_customer_tenant_guard();
commit;
