# Evolução comercial e critérios de aceite

## Implementado no código entregue
- Navegação SaaS e autenticação integrada ao Supabase.
- Tabelas de operações, equipes, clientes, ativos, cotações, finanças e estoque.
- RLS multiempresa e verificação de papéis.
- CRUDs operacionais + detalhes de ordens, cotações, estoque, faturas e clientes.
- Dashboard, relatórios e portal de leitura para cliente.
- Armazenamento privado de anexos e links assinados para equipe.

## Próximo ciclo técnico (não implementado nesta versão)
- Testes automatizados end-to-end e testes de políticas RLS com usuários reais.
- Cobrança de assinaturas SaaS (gateway, checkout, webhooks, trials, inadimplência).
- Emissão de notas fiscais integrada aos municípios/provedores.
- Convites e lembretes enviados via provedor transacional.
- Notificações push/WhatsApp e filas de retentativa.
- Ordem de serviço offline, fotos antes/depois e assinatura digital.
- Contratos recorrentes gerando OS automaticamente por job transacional.
- Configuração de módulos por empresa/segmento (menus ainda são comuns).
- Controle de filiais avançado e regras refinadas por técnico atribuído.
- Fluxo de aprovação de orçamentos pelo cliente com assinatura e trilha de auditoria.
- PDF profissional de orçamento, relatório de serviço e recibos.
- Faturamento e reconciliação com taxas de gateway, impostos e repasses.
- Compliance LGPD, logs de acesso, observabilidade, backups e testes de carga.

## Testes de aceitação obrigatórios
1. Criar contas A e B, empresas A e B; verificar isolamento total das consultas e gravações.
2. OWNER convida TECHNICIAN e FINANCE; aceitar com e-mails corretos; rejeitar token expirado ou e-mail divergente.
3. TECHNICIAN não consegue editar valores financeiros nem consultar despesas.
4. CLIENT vinculado a um cadastro vê apenas suas ordens, propostas e faturas.
5. Uma OS com cliente da empresa B não pode ser criada na empresa A.
6. Somatório de orçamento atualizado ao incluir itens; pagamentos não podem exceder fatura.
7. Estoque não permite saldo negativo; a alteração deve ocorrer por movimento.
8. Upload de arquivo em bucket privado só pode ser feito por membro autorizado.
9. Dashboard e relatórios refletem a inserção e edição de novos dados.
10. Revisar procedimentos de recuperação de senha, confirmações de e-mail e redirects Vercel.

## Complementos adicionados na revisão da versão 1.1
- Resposta transacional a orçamento pelo cliente, com checagem de vínculo, vencimento, estado e auditoria (migration 002).
- Bloqueio da edição dos itens após envio do orçamento.
- Impressão de orçamento e opção de salvar como PDF no navegador.
- Rotina de geração idempotente de ordens recorrentes para contratos (RPC de execução restrita ao backend; agendamento pendente de configuração).

### Aceites complementares
11. Cliente A não pode responder uma proposta do cliente B nem de outra empresa.
12. Proposta enviada e vencida não aceita aprovação; decisão é irreversível no fluxo normal.
13. Novo item só pode ser inserido se o orçamento estiver em rascunho.
14. Reexecutar geração de OS de um mesmo contrato/data não deve duplicar atendimentos.
15. Orçamento impresso deve exibir corretamente dados com caracteres especiais e valores.

### Versão 1.2 — Adicionado nesta entrega
- [x] Pesquisa, ordenação e filtro por status nas listagens
- [x] CSV filtrado e proteção básica contra fórmulas maliciosas
- [x] Alertas operacionais por vencimento e estoque mínimo no dashboard
- [x] Estados de erro e botão de nova tentativa
- [ ] Paginação e agregação server-side para operações em escala
- [ ] Testes integrados em Supabase real e compilação CI
