-- ÓRBITA OS · 016: recuperação e validação do cadastro de empresas
-- Aplicar APÓS 001_initial.sql a 015_customer_accounts.sql. Não apaga dados.
-- Execute como proprietário do projeto via Supabase SQL Editor.
create extension if not exists pgcrypto;
create or replace function public.create_organization(p_name text,p_industry text default 'GENERAL')
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_org uuid; v_uid uuid; v_name text; v_industry text;
begin
 v_uid := (select auth.uid());
 if v_uid is null then raise exception 'Sessão inválida. Saia e entre novamente.' using errcode='28000'; end if;
 v_name := btrim(coalesce(p_name,''));
 if length(v_name)<2 or length(v_name)>120 then raise exception 'O nome da empresa deve ter de 2 a 120 caracteres.' using errcode='22023'; end if;
 v_industry := coalesce(nullif(btrim(p_industry),''),'GENERAL');
 if v_industry not in ('GENERAL','MAINTENANCE','FIELD_SERVICE','CLEANING','CONSTRUCTION','TECHNOLOGY','CONSULTING','OTHER') then raise exception 'Segmento empresarial inválido.' using errcode='22023';end if;
 insert into public.organizations(name,industry,slug)
 values (v_name,v_industry,replace(pg_catalog.gen_random_uuid()::text, '-', ''))
 returning id into v_org;
 insert into public.organization_members(organization_id,user_id,role,status)
 values(v_org,v_uid,'OWNER','ACTIVE');
 return v_org;
end;$$;
revoke all on function public.create_organization(text,text) from public, anon;
grant execute on function public.create_organization(text,text) to authenticated;
comment on function public.create_organization(text,text) is 'Cria empresa e concede OWNER à conta autenticada na mesma transação.';
-- diagnóstico seguro: não expõe os dados de outras empresas
create or replace function public.workspace_diagnostics()
returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 return jsonb_build_object(
  'authenticated', (select auth.uid()) is not null,
  'profiles_table', to_regclass('public.profiles') is not null,
  'organizations_table', to_regclass('public.organizations') is not null,
  'organization_members_table', to_regclass('public.organization_members') is not null,
  'workspace_function', to_regprocedure('public.create_organization(text,text)') is not null
 );
end;$$;
revoke all on function public.workspace_diagnostics() from public, anon;
grant execute on function public.workspace_diagnostics() to authenticated;
