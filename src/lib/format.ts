export const money = (value: number | null | undefined) => new Intl.NumberFormat('pt-BR',{style:'currency', currency:'BRL'}).format(Number(value || 0));
export const date = (value: string | null | undefined) => value ? new Intl.DateTimeFormat('pt-BR',{timeZone:'UTC'}).format(new Date(value.length===10?value+'T12:00:00Z':value)) : '—';
export const datetime = (value: string | null | undefined) => value ? new Intl.DateTimeFormat('pt-BR',{dateStyle:'short',timeStyle:'short'}).format(new Date(value)):'—';
export const initials = (name: string) => name.trim().split(/\s+/).slice(0,2).map(s=>s[0]?.toUpperCase()).join('') || 'O';
export const statusLabels:Record<string,string> = {OPEN:'Aberta',IN_PROGRESS:'Em andamento',SCHEDULED:'Agendada',DONE:'Concluída',CANCELED:'Cancelada',PENDING:'Pendente',SENT:'Enviado',APPROVED:'Aprovado',REJECTED:'Recusado',DRAFT:'Rascunho',PAID:'Pago',OVERDUE:'Atrasado',PARTIAL:'Parcial',ACTIVE:'Ativo',PAUSED:'Pausado',EXPIRED:'Expirado',LOW:'Baixa',NORMAL:'Normal',HIGH:'Alta',URGENT:'Urgente',NEW:'Novo',COMPLETED:'Concluído',RESOLVED:'Resolvido',FINISHED:'Finalizado',WON:'Ganho',LOST:'Perdido',CLOSED:'Encerrado',RECEIVED:'Recebido',ORDERED:'Pedido realizado',PLANNED:'Planejado',ON_HOLD:'Em espera',BLOCKED:'Bloqueado',WAITING:'Aguardando',SUSPENDED:'Suspenso',INACTIVE:'Inativo',CRITICAL:'Crítica',MEDIUM:'Média',CONTACTED:'Contatado',QUALIFIED:'Qualificado',DISCOVERY:'Descoberta',PROPOSAL:'Proposta',NEGOTIATION:'Negociação',ANALYZING:'Em análise',MAINTENANCE:'Em manutenção',ON_THE_WAY:'A caminho',ARRIVED:'No local',REVIEWED:'Revisado',PHONE:'Telefone',EMAIL:'E-mail',WHATSAPP:'WhatsApp',MEETING:'Reunião',SOCIAL:'Redes sociais',OTHER:'Outro',PUBLISHED:'Publicado',ARCHIVED:'Arquivado'};
export const labelStatus = (s:string)=> statusLabels[s] || s;
export const errMessage = (e:unknown):string => {
 if(e instanceof Error) return e.message;
 if(e && typeof e==='object'){
  const problem=e as {message?:unknown;details?:unknown;hint?:unknown;code?:unknown};
  const details=[problem.message,problem.details,problem.hint].filter((v):v is string=>typeof v==='string'&&!!v);
  return `${details.join(' · ')||'O servidor retornou um erro sem descrição'}${problem.code?` (código ${String(problem.code)})`:''}`;
 }
 return typeof e==='string'?e:'Não foi possível concluir a operação.';
};
