# Correção do cadastro no Supabase

O erro `function pg_catalog.coalesce(text, unknown) does not exist (42883)` vem da função `public.create_organization` instalada pela versão anterior da migration 018. `COALESCE` e `NULLIF` são expressões SQL; elas devem ser usadas sem o prefixo `pg_catalog`.

## Arquivos que você deve executar

1. Em banco existente com as migrations anteriores, abra `supabase/migrations/019_workspace_and_query_indexes.sql`, copie seu conteúdo completo e execute uma vez no **SQL Editor do Supabase**. Ele corrige o cadastro, preserva os dados e acrescenta índices para consultas existentes. As políticas RLS não são alteradas.
2. Execute `supabase/diagnostics/verificar_instalacao.sql` no mesmo editor. É somente leitura: confira `erro_42883_corrigido = true`, as tabelas presentes e RLS habilitado.
3. Volte à aplicação, entre na conta e crie a empresa em `/setup`. O SQL Editor não representa o login do navegador; executar `create_organization` diretamente nele sem uma sessão deve retornar erro de autenticação.

Em um banco novo, aplique `001` até `019` na ordem. Não reaplique todas as migrations sobre um banco já instalado.

## Sobre os dois scripts de teste

Os scripts que criavam `auth`, `storage`, `auth.users`, `auth.uid` e `auth.jwt` eram simuladores do ambiente Supabase para um PostgreSQL temporário no Docker. No Supabase, esses objetos já são gerenciados pela plataforma. Não devem ser recriados ou substituídos.

O roteiro com `\gset`, `\if`, `\quit` e `\echo` também era um teste para o programa `psql`, não para o SQL Editor. Os scripts foram movidos para `tests/fixtures/*.fixture`, com avisos explícitos. Eles só são executados pelo comando `node tests/validate-sql.cjs`, em um container descartável e sem ler credenciais da aplicação.

Se você executou o primeiro script e recebeu `schema "auth" already exists`, o primeiro comando falhou; isso não indica que seja necessário apagar o schema. Se uma execução anterior deixou uma transação abortada no editor, execute `ROLLBACK;` antes da correção.

Referência: https://www.postgresql.org/docs/current/functions-conditional.html
