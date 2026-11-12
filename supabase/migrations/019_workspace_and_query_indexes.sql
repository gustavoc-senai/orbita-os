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
