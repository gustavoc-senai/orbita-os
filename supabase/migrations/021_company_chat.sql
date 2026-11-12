-- Chat geral e mensagens diretas, isolados por empresa e participantes.
begin;
create table if not exists public.company_messages (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid references public.profiles(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default now(),
 check(recipient_id is null or recipient_id<>sender_id)
);
create index if not exists idx_company_messages_general on public.company_messages(organization_id,created_at desc) where recipient_id is null;
create index if not exists idx_company_messages_recipient on public.company_messages(organization_id,recipient_id,created_at desc);
create index if not exists idx_company_messages_sender on public.company_messages(organization_id,sender_id,created_at desc);
alter table public.company_messages enable row level security;
drop policy if exists company_messages_read on public.company_messages;
create policy company_messages_read on public.company_messages for select to authenticated
 using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']) and (recipient_id is null or sender_id=(select auth.uid()) or recipient_id=(select auth.uid())));
drop policy if exists company_messages_send on public.company_messages;
create policy company_messages_send on public.company_messages for insert to authenticated
 with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']) and sender_id=(select auth.uid())
  and (recipient_id is null or exists(select 1 from public.organization_members m where m.organization_id=company_messages.organization_id and m.user_id=company_messages.recipient_id and m.status='ACTIVE' and m.role in ('OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE'))));
grant select,insert on public.company_messages to authenticated;
revoke all on public.company_messages from anon;
-- Clientes autenticados no portal não recebem acesso: é exigida associação ativa à empresa.
-- Atualização e exclusão não são concedidas; autoria e histórico são imutáveis.
do $$begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='company_messages') then
  alter publication supabase_realtime add table public.company_messages;
 end if;
end$$;
notify pgrst, 'reload schema';
commit;
