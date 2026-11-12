-- EXECUTAR NO SQL EDITOR DO SUPABASE, sobre um banco com as migrations 001 a 018.
-- Atualiza cadastro, convites e prepara chat/IA. Preserva dados existentes.
-- Não execute arquivos de tests/fixtures no Supabase.


-- ARQUIVO: 019_workspace_and_query_indexes.sql
-- Correção incremental para bancos que já executaram a migration 018.
begin;
-- ÓRBITA OS v2.2 · Hotfix de cadastro para bancos existentes
-- Executar APENAS em banco que ja tenha a migration 001 aplicada.
-- Nao remove tabelas, dados ou permissoes.
-- Usa gen_random_uuid() nativo do PostgreSQL para o slug,
-- evitando dependencias de search_path e pgcrypto.gen_random_bytes().

create or replace function public.create_organization(
  p_name text,
  p_industry text default 'GENERAL'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_uid uuid;
  v_name text;
  v_industry text;
begin
  v_uid := (select auth.uid());
  if v_uid is null then
    raise exception 'Sessao invalida: faca login novamente.' using errcode = '28000';
  end if;

  v_name := pg_catalog.btrim(coalesce(p_name, ''));
  if pg_catalog.length(v_name) < 2 or pg_catalog.length(v_name) > 120 then
    raise exception 'Nome da empresa deve ter de 2 a 120 caracteres.' using errcode = '22023';
  end if;

  v_industry := coalesce(nullif(pg_catalog.btrim(p_industry), ''), 'GENERAL');
  if v_industry not in ('GENERAL','MAINTENANCE','FIELD_SERVICE','CLEANING',
                        'CONSTRUCTION','TECHNOLOGY','CONSULTING','OTHER') then
    raise exception 'Segmento empresarial invalido.' using errcode = '22023';
  end if;

  insert into public.organizations (name, industry, slug)
  values (v_name, v_industry, pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''))
  returning id into v_org;

  insert into public.organization_members (organization_id, user_id, role, status)
  values (v_org, v_uid, 'OWNER', 'ACTIVE');

  return v_org;
end;
$$;

revoke all on function public.create_organization(text, text) from public, anon;
grant execute on function public.create_organization(text, text) to authenticated;

comment on function public.create_organization(text, text) is
'Cria empresa e concede OWNER ao usuario autenticado; nao depende de gen_random_bytes';

-- Índices para filtros por empresa, listagens e relacionamentos frequentes.
create index if not exists idx_members_org_status on public.organization_members(organization_id,status,created_at);
create index if not exists idx_customer_users_customer on public.customer_users(customer_id,organization_id);
create index if not exists idx_notifications_unread on public.notifications(organization_id,user_id,created_at desc) where read_at is null;
create index if not exists idx_expenses_org_date on public.expenses(organization_id,incurred_on desc);
create index if not exists idx_orders_org_assignee on public.work_orders(organization_id,assigned_to,created_at desc);
create index if not exists idx_assets_org_customer on public.assets(organization_id,customer_id);
create index if not exists idx_payments_invoice on public.payments(invoice_id);
create index if not exists idx_quote_items_quote on public.quote_items(quote_id);
create index if not exists idx_tasks_order on public.work_order_tasks(work_order_id);
create index if not exists idx_notes_order on public.work_order_notes(work_order_id,created_at desc);
notify pgrst, 'reload schema';
commit;


-- ARQUIVO: 020_repair_team_invitations.sql
-- Reparação das funções de convite. Executar após 019 no SQL Editor.
begin;
-- ÓRBITA OS 1.3 — Convites profissionais, bloqueio e gestão segura de membros
-- Execute DEPOIS de 001 e 002, uma vez no SQL Editor do Supabase.

-- Convites somente por RPC: cliente não escolhe manualmente tokens ou altera campos protegidos.
drop policy if exists invitation_create on public.organization_invitations;
drop policy if exists invitation_update on public.organization_invitations;
drop policy if exists invitation_delete on public.organization_invitations;

create or replace function public.create_team_invite(p_org uuid,p_email text,p_role text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_email text;v_token uuid;begin
 if not public.has_org_role(p_org,array['OWNER','ADMIN']) then raise exception 'Sem permissão para enviar convites';end if;
 v_email=lower(trim(coalesce(p_email,'')));
 if length(v_email)>254 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'E-mail inválido';end if;
 if p_role is null or p_role not in ('ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE') then raise exception 'Perfil inválido';end if;
 if exists(select 1 from public.organization_members m join public.profiles p on p.id=m.user_id where m.organization_id=p_org and lower(p.email)=v_email and m.status='ACTIVE') then
  raise exception 'Este profissional já faz parte da equipe';
 end if;
 insert into public.organization_invitations(organization_id,email,role,token,expires_at,accepted_at)
 values(p_org,v_email,p_role,pg_catalog.gen_random_uuid(),now()+interval '7 days',null)
 on conflict(organization_id,email) do update set role=excluded.role,token=excluded.token,
 expires_at=excluded.expires_at,accepted_at=null,created_at=now()
 returning token into v_token;
 return v_token;
end;$$;
revoke all on function public.create_team_invite(uuid,text,text) from public;
grant execute on function public.create_team_invite(uuid,text,text) to authenticated;

create or replace function public.cancel_team_invite(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_org uuid;begin
 select organization_id into v_org from public.organization_invitations where id=p_id;
 if v_org is null or not public.has_org_role(v_org,array['OWNER','ADMIN']) then raise exception 'Convite não encontrado ou acesso negado';end if;
 delete from public.organization_invitations where id=p_id and accepted_at is null;
end;$$;
revoke all on function public.cancel_team_invite(uuid) from public;
grant execute on function public.cancel_team_invite(uuid) to authenticated;

create or replace function public.set_team_member(p_org uuid,p_user uuid,p_role text,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_old public.organization_members%rowtype;begin
 if not public.has_org_role(p_org,array['OWNER']) then raise exception 'Somente o proprietário pode gerenciar perfis e suspensões';end if;
 if p_role is null or p_role not in ('OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE')
 or p_status is null or p_status not in ('ACTIVE','SUSPENDED') then raise exception 'Dados inválidos';end if;
 select * into v_old from public.organization_members where organization_id=p_org and user_id=p_user for update;
 if not found then raise exception 'Membro não encontrado';end if;
 if v_old.role='OWNER' and (p_role<>'OWNER' or p_status<>'ACTIVE') then
  raise exception 'Proprietários não podem ser suspensos ou rebaixados por esta operação';
 end if;
 if v_old.role<>'OWNER' and p_role='OWNER' then raise exception 'Transferência de propriedade requer fluxo específico';end if;
 update public.organization_members set role=p_role,status=p_status where organization_id=p_org and user_id=p_user;
end;$$;
revoke all on function public.set_team_member(uuid,uuid,text,text) from public;
grant execute on function public.set_team_member(uuid,uuid,text,text) to authenticated;

-- Revalida o token, o endereço autenticado e a situação da associação.
create or replace function public.accept_org_invitation(p_token uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_inv public.organization_invitations%rowtype;v_email text;v_existing public.organization_members%rowtype;begin
 if auth.uid() is null then raise exception 'Entre na sua conta para aceitar o convite';end if;
 select lower(email) into v_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if v_email is null then raise exception 'Confirme seu endereço de e-mail antes de aceitar';end if;
 select * into v_inv from public.organization_invitations where token=p_token and accepted_at is null and expires_at>now() for update;
 if not found or lower(v_inv.email)<>v_email then raise exception 'Convite expirado, cancelado ou de outro e-mail';end if;
 select * into v_existing from public.organization_members where organization_id=v_inv.organization_id and user_id=auth.uid() for update;
 if found then
  if v_existing.role='OWNER' then raise exception 'Não é possível alterar o proprietário por convite';end if;
  if v_existing.status='SUSPENDED' then raise exception 'Acesso suspenso; contate o proprietário';end if;
  -- Um convite não eleva permissões de membros já existentes.
 else
  insert into public.organization_members(organization_id,user_id,role,status)
  values(v_inv.organization_id,auth.uid(),v_inv.role,'ACTIVE');
 end if;
 update public.organization_invitations set accepted_at=now() where id=v_inv.id;
 return v_inv.organization_id;
end;$$;
revoke all on function public.accept_org_invitation(uuid) from public;
grant execute on function public.accept_org_invitation(uuid) to authenticated;

-- As permissões RLS continuam sendo aplicadas a toda consulta operacional.

notify pgrst, 'reload schema';
commit;


-- ARQUIVO: 021_company_chat.sql
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


-- ARQUIVO: 022_assistant_usage.sql
-- Limite de uso da IA por usuário e empresa, controlado no servidor.
begin;
create table if not exists public.assistant_usage (
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 window_start timestamptz not null,
 requests integer not null check(requests between 1 and 30),
 primary key(organization_id,user_id,window_start)
);
alter table public.assistant_usage enable row level security;
revoke all on public.assistant_usage from anon,authenticated;
create or replace function public.reserve_assistant_request(p_org uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare v_allowed boolean;
begin
 if auth.uid() is null or not public.has_org_role(p_org,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']) then
  raise exception 'Acesso à IA exige vínculo ativo com a empresa' using errcode='42501';
 end if;
 insert into public.assistant_usage(organization_id,user_id,window_start,requests)
 values(p_org,auth.uid(),date_trunc('hour',now()),1)
 on conflict(organization_id,user_id,window_start) do update
 set requests=public.assistant_usage.requests+1 where public.assistant_usage.requests<30
 returning true into v_allowed;
 return coalesce(v_allowed,false);
end$$;
revoke all on function public.reserve_assistant_request(uuid) from public,anon;
grant execute on function public.reserve_assistant_request(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
