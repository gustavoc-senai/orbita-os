# Ativar convites, chat e IA

## 1. Atualizar o banco real

No **SQL Editor do Supabase**, execute o conteúdo completo de `supabase/ATUALIZAR_SISTEMA.sql`. O arquivo reúne as migrations 019, 020, 021 e 022, para um banco que já tenha as migrations 001–018. Os blocos podem ser reaplicados e preservam dados existentes.

- 019 corrige `pg_catalog.coalesce` / `pg_catalog.nullif` no cadastro e adiciona índices.
- 020 reinstala geração, cancelamento, aceitação e administração segura de convites.
- 021 cria o chat geral e as mensagens diretas, com RLS por empresa e participantes.
- 022 instala o limite de IA: 30 solicitações por usuário e empresa por hora.

Em um banco novo, execute 001–022 na ordem. **Nunca execute `tests/fixtures` no Supabase.**

Para conferir a estrutura, execute `supabase/diagnostics/verificar_instalacao.sql`. Os schemas `auth` e `storage` já pertencem ao Supabase e não devem ser recriados.

## 2. Usar os convites

Em `/app/equipe`, um proprietário ou administrador gera o link e o compartilha manualmente com o colega. O sistema não envia e-mail automaticamente.

O colega entra ou cria a conta com o mesmo e-mail usado no convite, confirma esse endereço e clica em **Aceitar e entrar na empresa**. O token vale 7 dias. Renovar um convite substitui seu link anterior.

Se falhar, a tela apresenta a orientação e permite abrir **Ver detalhe técnico**. Não esconda esse detalhe ao diagnosticar: ele diferencia função ausente, e-mail divergente, conta sem confirmação, convite expirado e acesso suspenso.

## 3. Usar o chat

Acesse `/app/conversas`, disponível na sidebar.

- **Geral da empresa**: conversa acessível aos membros ativos da empresa.
- **Mensagens diretas**: visíveis apenas ao remetente e ao destinatário, dentro da mesma empresa. O administrador não recebe acesso às mensagens diretas de outros colegas por essa interface.
- Autoria é validada por `auth.uid()` no banco. Destinatários devem ter vínculo ativo com a mesma empresa.
- Clientes do portal não recebem acesso ao chat interno.
- As mensagens são armazenadas no Supabase. O cliente recebe atualizações em tempo real quando `supabase_realtime` está disponível; também consulta atualizações automaticamente a cada 15 segundos.
- A interface carrega as últimas 100 mensagens e permite consultar anteriores até 1.000. Não há anexos, leitura confirmada, chamada de vídeo ou indicação de presença de outros usuários nesta versão.

## 4. Ativar respostas reais de IA

O front-end está em `/app/assistente`. O backend está em `supabase/functions/orbita-assistant/`.

Configure, em **Edge Functions → Secrets**, no projeto Supabase:

- `OPENAI_API_KEY`: sua chave da API OpenAI; nunca coloque em uma variável `VITE_`.
- `OPENAI_MODEL`: opcional; padrão `gpt-4.1-mini`.
- `APP_ORIGINS`: opcional; origens permitidas, separadas por vírgula, por exemplo `http://localhost:5173,https://seu-dominio.com`.

`SUPABASE_URL` e `SUPABASE_ANON_KEY` são variáveis fornecidas pelo ambiente das Edge Functions. A função usa o JWT do próprio usuário para consultar dados sob RLS; não usa `service_role`.

Publique com a CLI do Supabase autenticada e vinculada ao seu projeto:

```text
supabase functions deploy orbita-assistant --project-ref SEU_PROJECT_REF
```

O código contém `handler.ts` e `index.ts`; publique os dois arquivos juntos. `supabase/config.toml` mantém verificação JWT ligada. Não copie esses arquivos TypeScript para o SQL Editor.

Sem a chave ou sem a função publicada, a interface informa que a IA ainda não está configurada. Ela não inventa uma resposta demonstrativa.

## Funcionamento da IA

O usuário pode incluir ou excluir o resumo da empresa antes de enviar a pergunta. Quando incluído, o servidor consulta uma amostra de até 30 registros por módulo, conforme o perfil. Técnicos recebem apenas ordens e agenda atribuídas a eles; valores financeiros são incluídos somente para perfis autorizados.

A pergunta e o contexto selecionado são enviados à OpenAI pela Responses API com `store: false`. A conversa é mantida somente na tela, sem tabela de histórico. A IA auxilia na interpretação e redação: não executa SQL, não altera cadastros e não envia mensagens automaticamente. A interface permite copiar a resposta e revisá-la antes de usar.

## Validação local

`npm test` verifica arquivos/rotas, calendário e handler da IA com chamadas de rede simuladas. `npm run test:sql` executa migrations e testes de convites, isolamento de mensagens, autoria e quota de IA em PostgreSQL 17 descartável. `npm run test:browser` usa respostas interceptadas e não escreve no Supabase real.

Fontes da implementação: [Responses API](https://developers.openai.com/api/docs/guides/text), [autenticação de Edge Functions](https://supabase.com/docs/guides/functions/auth).
