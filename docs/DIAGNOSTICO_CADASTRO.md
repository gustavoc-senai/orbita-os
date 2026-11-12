# Diagnóstico do erro em /setup

A mensagem genérica "Não foi possível criar o workspace" escondia o erro retornado pelo Supabase. Agora a tela exibe mensagem, código e, quando enviados, detalhes.

1. Confirme em `.env` os valores públicos `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`.
2. Em um projeto Supabase novo execute, **em ordem**, os SQLs `001` a `016`. Se já executou `001` a `015`, execute apenas `016_workspace_recovery.sql`.
3. Faça logout e login e tente o cadastro novamente. O e-mail deve ter sido confirmado, se a confirmação estiver habilitada.
4. Se ainda falhar, copie a **mensagem exata** apresentada sob o formulário; pode ser incompatibilidade de schema, migrations incompletas, privilégios ou autenticação.
5. Nunca execute migrations num banco de produção sem backup. O arquivo 016 não altera ou apaga organizações existentes.

Se `create_organization` não existir: execute os SQLs faltantes. Se ocorrer `permission denied`: verifique execução no SQL Editor e usuário autenticado. Se ocorrer violação de chave ou de check: examine a mensagem exata antes de aplicar qualquer correção manual.

Não é possível confirmar a origem do erro apresentado na captura sem acesso ao log ou banco de dados Supabase do usuário.
