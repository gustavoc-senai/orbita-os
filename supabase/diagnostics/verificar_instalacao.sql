-- SUPABASE SQL EDITOR: diagnóstico somente de leitura.
-- Execute após 019_workspace_and_query_indexes.sql.
-- Não cria usuários, não altera auth/storage e não cadastra empresas fictícias.
select
 to_regclass('public.organizations') is not null as tabela_empresas_existe,
 to_regclass('public.organization_members') is not null as tabela_membros_existe,
 to_regclass('public.calendar_events') is not null as tabela_agenda_existe,
 to_regprocedure('public.create_organization(text,text)') is not null as funcao_cadastro_existe;

select
 p.proname as funcao,
 p.prosecdef as executa_com_permissao_do_proprietario,
 p.proconfig as configuracao_search_path,
 has_function_privilege('authenticated',p.oid,'EXECUTE') as usuario_autenticado_pode_executar,
 not has_function_privilege('anon',p.oid,'EXECUTE') as acesso_anonimo_bloqueado,
 position('pg_catalog.coalesce' in pg_get_functiondef(p.oid))=0
  and position('pg_catalog.nullif' in pg_get_functiondef(p.oid))=0 as erro_42883_corrigido
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.oid=to_regprocedure('public.create_organization(text,text)');

select tablename,rowsecurity as rls_habilitado
from pg_tables where schemaname='public'
 and tablename in ('organizations','organization_members','customers','calendar_events','work_orders','customer_users')
order by tablename;

-- No SQL Editor, auth.uid() normalmente é NULL: isso é esperado.
-- O teste real de cadastro deve ser feito em /setup com uma conta conectada.

-- Recursos adicionais: todos devem existir após ATUALIZAR_SISTEMA.sql.
select to_regprocedure('public.create_team_invite(uuid,text,text)') is not null as gerar_convite_disponivel,
 to_regprocedure('public.accept_org_invitation(uuid)') is not null as aceitar_convite_disponivel,
 to_regclass('public.company_messages') is not null as chat_instalado,
 to_regprocedure('public.reserve_assistant_request(uuid)') is not null as limite_ia_instalado;
