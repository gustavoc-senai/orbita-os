# Órbita OS — Enterprise Workspace

Sistema de gestão multiempresa em React, TypeScript, Vite e Supabase. Mantém os cadastros, autenticação, permissões e fluxos operacionais existentes.

## Executar localmente

1. Instale as dependências: `npm install`.
2. Configure `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` em `.env.local`, usando `.env.example` como referência. Use apenas a chave pública no front-end.
3. Execute `npm run dev` e abra o endereço informado pelo Vite.
4. Entre na conta, crie a empresa em `/setup` e convide a equipe em `/app/equipe`.

## Banco de dados: arquivos corretos para o Supabase

- **Banco novo:** execute as migrations `001` a `022`, em ordem, no SQL Editor.
- **Banco existente com as migrations anteriores:** execute somente as migrations ainda não aplicadas. Não reaplique a instalação inicial.
- **Erro `pg_catalog.coalesce` no cadastro:** execute `supabase/migrations/019_workspace_and_query_indexes.sql`.
- **Conferência após a correção:** execute `supabase/diagnostics/verificar_instalacao.sql`, somente leitura e compatível com o SQL Editor.

Instruções detalhadas: [docs/CORRECAO_ERRO_42883.md](docs/CORRECAO_ERRO_42883.md).

**Os arquivos em `tests/fixtures` são exclusivamente para o PostgreSQL temporário usado nos testes. Eles não devem ser executados no Supabase.** Não recrie os schemas `auth` e `storage` gerenciados pela plataforma.

## Interface

- Identidade visual compartilhada entre os 35 módulos, centrais de gestão, autenticação e portal do cliente.
- Temas escuro e claro persistidos no navegador e acessíveis em Configurações.
- Navegação compacta por centrais, favoritos sincronizados com o catálogo e pesquisa por `Ctrl+K`.
- Central de Módulos organizada em 12 áreas empresariais, com busca e favoritos.
- Dashboard com dados reais, evolução financeira, agenda e pendências operacionais.
- Onboarding com cadastro, revisão e seleção da empresa recém-criada.
- Diretório de equipe com busca, filtros, paginação e consulta do perfil.
- Portal do cliente independente, com atendimentos, propostas e faturas; navegação inferior no celular.
- Tabelas dos cadastros transformadas em cards no celular, com filtros, ordenação, CSV e ações preservadas.
- Modais com navegação por teclado, Escape e restauração de foco; redução de movimento respeitada.

## Agenda em calendário

A rota `/app/agenda` usa a tabela existente `calendar_events`.

- Visões **Mês**, **Semana** e **Dia**, com botão Hoje e navegação por período.
- Clique no número do dia para consultar a programação lateral. Use `+` para agendar nesse dia.
- Nas visões Semana e Dia, clique no horário desejado para criar um compromisso.
- Clique em um compromisso para consultar ou editar; exclusão conforme a função autorizada.
- Busca, filtro por profissional e exportação CSV do período consultado.
- Horários sobrepostos aparecem em colunas; compromissos que atravessam a meia-noite aparecem nos dias correspondentes.
- Datas são editadas no horário local e salvas em UTC. O término precisa ser posterior ao início.
- A visualização inicial no celular é Dia. A grade semanal tem rolagem interna para preservar a leitura.

A agenda não integra calendários externos e não envia lembretes automáticos. Mantém as permissões existentes do banco.

## Verificações

```text
npm run typecheck
npm test
npm run build
npm run test:sql
npm run test:browser
```

- `test`: integridade dos arquivos/rotas e casos de calendário, incluindo ano bissexto, sobreposição, meia-noite e horário local.
- `test:sql`: exige Docker; inicia PostgreSQL 17 descartável, aplica as 22 migrations e valida criação de empresa, associação OWNER, autenticação, convites, isolamento e reaplicação da migration 019. Não lê credenciais da aplicação.
- `test:browser`: exige Chrome, Playwright e servidor local. Usa respostas de API interceptadas para conferir interface, calendário e responsividade. Nenhuma escrita é feita no Supabase real. Instale Playwright para esta verificação com `npm install --no-save --package-lock=false playwright`. A URL padrão é `http://localhost:5173`; configure `ORBITA_QA_URL` para testar outra porta.

A validação do banco remoto com os usuários reais deve ser feita após aplicar a migration no seu projeto Supabase. Os testes locais não aplicam mudanças nesse projeto.

## Escopo preservado

A plataforma mantém os fluxos de ordens, orçamentos, pagamentos registrados, estoque, documentos, equipe e portal. Não simula gateway de pagamento, envio de e-mail, assinatura SaaS, emissão fiscal, mapas ou métricas sem dados de suporte. Novas integrações exigem desenvolvimento específico.

## Conversas, IA e reparação dos convites

Acesse `/app/conversas` para chat geral e mensagens individuais, e `/app/assistente` para o Órbita AI. Execute `supabase/ATUALIZAR_SISTEMA.sql` no SQL Editor para instalar as atualizações 019–022. A IA também requer a publicação da Edge Function e configuração da chave OpenAI somente no servidor.

Guia completo: [docs/ATIVAR_CHAT_E_IA.md](docs/ATIVAR_CHAT_E_IA.md).
