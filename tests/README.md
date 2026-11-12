# Testes locais

**Não cole arquivos desta pasta no SQL Editor do Supabase.**

- `node tests/validate-package.cjs`: verifica rotas e arquivos essenciais.
- `node tests/validate-sql.cjs`: cria um PostgreSQL 17 descartável no Docker, simula schemas Supabase, aplica as 19 migrations e testa cadastro, convites e isolamento. Exige Docker. Não lê `.env` nem acessa o Supabase remoto.
- `node tests/browser-qa.cjs`: usa Playwright e Chrome headless com respostas de API interceptadas. Não grava dados no Supabase. Exige o servidor local, `playwright` disponível e Chrome instalado.

Para corrigir o banco real, use exclusivamente as instruções de `docs/CORRECAO_ERRO_42883.md`.
