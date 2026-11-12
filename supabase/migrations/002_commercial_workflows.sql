-- ÓRBITA OS · Complementos comerciais. Executar após 001_initial.sql.
-- Aprovação/rejeição segura de orçamentos pelo cliente, trilha e serviços recorrentes.

alter table public.quotes add column if not exists responded_at timestamptz;
alter table public.quotes add column if not exists responded_by uuid references auth.users(id);
alter table public.quotes add column if not exists response_note text;

-- Apenas rascunhos podem ter seus itens alterados. O cálculo interno do total continua permitido.
create or replace function public.lock_approved_quote_items() returns trigger
language plpgsql set search_path = '' as $$
declare v_status text;
begin
 select status into v_status from public.quotes where id=coalesce(new.quote_id,old.quote_id);
 if v_status is distinct from 'DRAFT' then
  raise exception 'Itens de propostas enviadas ou finalizadas são imutáveis';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end;$$;
create trigger trg_lock_quote_items before insert or update or delete on public.quote_items
for each row execute function public.lock_approved_quote_items();

-- Protege o registro de decisão contra sobrescrita manual pelo frontend.
create or replace function public.protect_quote_response() returns trigger
language plpgsql set search_path = '' as $$
begin
 if tg_op='INSERT' then
  if new.responded_at is not null or new.responded_by is not null then
   raise exception 'Resposta deve ser registrada pelo portal';
  end if;
 else
  if current_setting('orbita.client_quote_response',true) <> 'yes' and
   (new.responded_at is distinct from old.responded_at or
    new.responded_by is distinct from old.responded_by or
    new.response_note is distinct from old.response_note) then
   raise exception 'Resposta protegida';
  end if;
  if old.status in ('APPROVED','REJECTED') and new.status <> old.status then
   raise exception 'Proposta respondida não pode ser reaberta diretamente';
  end if;
 end if;
 return new;
end;$$;
create trigger trg_protect_quote_response before insert or update on public.quotes
for each row execute function public.protect_quote_response();

-- Recria a RPC para marcar o contexto de decisão antes de salvar.
create or replace function public.respond_to_quote(
 p_quote uuid, p_decision text, p_note text default null
) returns text language plpgsql security definer set search_path = '' as $$
declare q public.quotes%rowtype;
begin
 if auth.uid() is null then raise exception 'Faça login para responder'; end if;
 if p_decision not in ('APPROVED','REJECTED') then raise exception 'Resposta inválida'; end if;
 select * into q from public.quotes where id=p_quote for update;
 if not found or not public.is_org_client(q.organization_id,q.customer_id) then raise exception 'Proposta indisponível'; end if;
 if q.status <> 'SENT' then raise exception 'Somente propostas enviadas podem receber resposta'; end if;
 if q.valid_until is not null and q.valid_until < current_date then raise exception 'Proposta vencida; solicite uma nova'; end if;
 perform set_config('orbita.client_quote_response','yes',true);
 update public.quotes set status=p_decision,responded_at=now(),responded_by=auth.uid(),
 response_note=nullif(left(trim(coalesce(p_note,'')),1000),'') where id=p_quote;
 perform set_config('orbita.client_quote_response','',true);
 insert into public.audit_logs(organization_id,actor_id,entity,entity_id,action,details)
 values(q.organization_id,auth.uid(),'quotes',q.id,'CLIENT_'||p_decision,jsonb_build_object('previous_status',q.status));
 return p_decision;
end;$$;

-- Recorrência de OS por contrato: idempotente, limitada a uma geração por contrato/data.
alter table public.work_orders add column if not exists source_contract_id uuid references public.contracts(id);
alter table public.work_orders add column if not exists source_service_date date;
create unique index if not exists uq_recurring_service on public.work_orders(source_contract_id,source_service_date)
 where source_contract_id is not null;
create index if not exists idx_contract_next_service on public.contracts(next_service_on)
 where status='ACTIVE';

create or replace function public.generate_due_contract_orders(p_max integer default 100)
returns integer language plpgsql security definer set search_path = '' as $$
declare c public.contracts%rowtype; v_count integer := 0; v_next date;
begin
 -- Esta RPC deve ser invocada exclusivamente por responsável autorizado via job backend.
 if current_user <> 'postgres' and auth.role() <> 'service_role' then
  raise exception 'Execução restrita ao backend';
 end if;
 if p_max < 1 or p_max > 500 then raise exception 'Limite inválido'; end if;
 for c in select * from public.contracts
  where status='ACTIVE' and next_service_on is not null and next_service_on <= current_date
   and (ends_on is null or next_service_on <= ends_on)
  order by next_service_on,id for update skip locked limit p_max loop
  insert into public.work_orders(organization_id,customer_id,title,description,status,priority,
    scheduled_at,estimated_amount,source_contract_id,source_service_date)
  values(c.organization_id,c.customer_id,c.title,
   concat('OS automática do contrato ',c.id::text, E'\n',coalesce(c.description,'')),
   'OPEN','NORMAL',c.next_service_on::timestamp,0,c.id,c.next_service_on)
  on conflict do nothing;
  v_next := case c.billing_cycle
    when 'MONTHLY' then (c.next_service_on + interval '1 month')::date
    when 'QUARTERLY' then (c.next_service_on + interval '3 months')::date
    when 'YEARLY' then (c.next_service_on + interval '1 year')::date
    else null end;
  update public.contracts set next_service_on=v_next where id=c.id;
  v_count:=v_count+1;
 end loop;
 return v_count;
end;$$;
revoke all on function public.generate_due_contract_orders(integer) from public,anon,authenticated;
grant execute on function public.generate_due_contract_orders(integer) to service_role;
-- Agende pelo Supabase Cron usando credenciais de backend, após revisar a periodicidade.

-- Uma decisão final precisa passar pela RPC de autorização, mesmo para quem possui acesso comercial.
create or replace function public.enforce_quote_decision() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.status in ('APPROVED','REJECTED') and
 (tg_op='INSERT' or new.status is distinct from old.status) and
 current_setting('orbita.client_quote_response',true) <> 'yes' then
  raise exception 'Aprovação/rejeição somente pelo portal do cliente';
 end if;
 return new;
end;$$;
create trigger trg_enforce_quote_decision before insert or update on public.quotes
for each row execute function public.enforce_quote_decision();
