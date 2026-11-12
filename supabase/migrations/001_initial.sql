-- ÓRBITA OS · Schema inicial multiempresa, 2026-11
-- Executar integralmente no SQL Editor do Supabase (projeto novo).
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', email text, phone text, avatar_url text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create function public.new_user_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin insert into public.profiles(id,full_name,email) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),new.email) on conflict(id) do update set email=excluded.email;return new;end;$$;
drop trigger if exists trg_profile_auth on auth.users;
create trigger trg_profile_auth after insert on auth.users for each row execute function public.new_user_profile();
insert into public.profiles(id,full_name,email) select id,coalesce(raw_user_meta_data->>'full_name',''),email from auth.users on conflict(id) do nothing;

create table public.organizations (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>=2),slug text not null unique,
 industry text not null default 'GENERAL', email text, phone text, settings jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.organization_members (
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check(role in ('OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE','CLIENT')),
 status text not null default 'ACTIVE' check(status in ('ACTIVE','SUSPENDED')),
 created_at timestamptz not null default now(), primary key(organization_id,user_id)
);
create index on public.organization_members(user_id);
-- Helpers SECURITY DEFINER evitam recursão nas policies. Nenhuma função aceita identidade arbitrária.
create function public.is_org_member(p_org uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.organization_members where organization_id=p_org and user_id=(select auth.uid()) and status='ACTIVE');
$$;
create function public.has_org_role(p_org uuid,p_roles text[]) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.organization_members where organization_id=p_org and user_id=(select auth.uid()) and status='ACTIVE' and role=any(p_roles));
$$;
create function public.create_organization(p_name text,p_industry text default 'GENERAL') returns uuid language plpgsql security definer set search_path = '' as $$
declare v_org uuid;v_name text;begin
 if auth.uid() is null then raise exception 'Autenticação necessária';end if;
 v_name=trim(p_name);if length(v_name)<2 or length(v_name)>120 then raise exception 'Nome deve ter entre 2 e 120 caracteres';end if;
 insert into public.organizations(name,industry,slug) values(v_name,coalesce(nullif(trim(p_industry),''),'GENERAL'),replace(pg_catalog.gen_random_uuid()::text, '-', '')) returning id into v_org;
 insert into public.organization_members(organization_id,user_id,role) values(v_org,auth.uid(),'OWNER');
 return v_org;
end;$$;
revoke all on function public.create_organization(text,text) from public;
grant execute on function public.create_organization(text,text) to authenticated;

create table public.customers (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null check(length(trim(name))>=2), type text not null default 'COMPANY' check(type in ('PERSON','COMPANY')),
 email text,phone text,tax_id text,notes text,created_at timestamptz not null default now()
);
create index on public.customers(organization_id,name);
create table public.customer_users (
 organization_id uuid not null references public.organizations(id) on delete cascade,
 customer_id uuid not null references public.customers(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(organization_id,customer_id,user_id)
);
create index on public.customer_users(user_id);
create function public.is_org_client(p_org uuid,p_customer uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.customer_users where organization_id=p_org and customer_id=p_customer and user_id=(select auth.uid()));
$$;

create table public.sites (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 customer_id uuid not null references public.customers(id) on delete cascade,
 name text not null,address text,city text,state text,zip_code text,created_at timestamptz not null default now(),
 unique(id,organization_id)
);
create table public.assets (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 customer_id uuid references public.customers(id) on delete set null,site_id uuid references public.sites(id) on delete set null,
 name text not null,serial_number text,category text,brand text,model text,status text not null default 'ACTIVE',
 installed_on date,warranty_until date,notes text,created_at timestamptz not null default now()
);
create table public.services (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,description text,price numeric(14,2) not null default 0 check(price>=0),duration_minutes int not null default 60 check(duration_minutes>0),
 active boolean not null default true,created_at timestamptz not null default now()
);
create table public.work_orders (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 number bigint generated by default as identity, customer_id uuid not null references public.customers(id),
 site_id uuid references public.sites(id),asset_id uuid references public.assets(id),
 title text not null,description text,status text not null default 'OPEN' check(status in ('OPEN','SCHEDULED','IN_PROGRESS','DONE','CANCELED')),
 priority text not null default 'NORMAL' check(priority in ('LOW','NORMAL','HIGH','URGENT')),
 scheduled_at timestamptz,due_at timestamptz,assigned_to uuid references auth.users(id),
 estimated_amount numeric(14,2) not null default 0 check(estimated_amount>=0),completed_at timestamptz,
 created_by uuid references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(id,organization_id)
);
create index on public.work_orders(organization_id,status,created_at desc);
create table public.work_order_tasks (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 work_order_id uuid not null references public.work_orders(id) on delete cascade,
 title text not null,completed boolean not null default false,completed_at timestamptz,position integer not null default 0,created_at timestamptz not null default now()
);
create table public.work_order_notes (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 work_order_id uuid not null references public.work_orders(id) on delete cascade,
 author_id uuid not null references auth.users(id),body text not null,created_at timestamptz not null default now()
);
create table public.time_entries (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 work_order_id uuid not null references public.work_orders(id) on delete cascade,
 user_id uuid not null references auth.users(id),minutes integer not null check(minutes>0),description text,created_at timestamptz not null default now()
);
create table public.quotes (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 number bigint generated by default as identity,customer_id uuid not null references public.customers(id),title text not null,
 status text not null default 'DRAFT' check(status in ('DRAFT','SENT','APPROVED','REJECTED','CANCELED')),
 total numeric(14,2) not null default 0 check(total>=0),valid_until date,notes text,created_at timestamptz not null default now()
);
create table public.quote_items (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 quote_id uuid not null references public.quotes(id) on delete cascade,description text not null,
 quantity numeric(14,3) not null default 1 check(quantity>0),unit_price numeric(14,2) not null default 0 check(unit_price>=0),
 created_at timestamptz not null default now()
);
create table public.contracts (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 customer_id uuid not null references public.customers(id),title text not null,
 status text not null default 'ACTIVE' check(status in ('DRAFT','ACTIVE','PAUSED','EXPIRED','CANCELED')),
 amount numeric(14,2) not null default 0 check(amount>=0),billing_cycle text not null default 'MONTHLY' check(billing_cycle in ('MONTHLY','QUARTERLY','YEARLY','ONE_TIME')),
 starts_on date not null default current_date,ends_on date,next_service_on date,description text,created_at timestamptz not null default now()
);
create table public.invoices (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 number bigint generated by default as identity,customer_id uuid not null references public.customers(id),
 work_order_id uuid references public.work_orders(id),contract_id uuid references public.contracts(id),
 title text not null,amount numeric(14,2) not null check(amount>=0),paid_amount numeric(14,2) not null default 0 check(paid_amount>=0),
 status text not null default 'PENDING' check(status in ('DRAFT','PENDING','PARTIAL','PAID','CANCELED')),
 due_date date,created_at timestamptz not null default now(),check(paid_amount<=amount)
);
create table public.payments (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 invoice_id uuid not null references public.invoices(id) on delete cascade,amount numeric(14,2) not null check(amount>0),
 method text not null default 'OTHER',paid_at timestamptz not null default now(),notes text,created_at timestamptz not null default now()
);
create table public.expenses (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,category text,amount numeric(14,2) not null check(amount>=0),
 incurred_on date not null default current_date,status text not null default 'PAID' check(status in ('PENDING','PAID','CANCELED')),
 created_at timestamptz not null default now()
);
create table public.inventory_items (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 sku text,name text not null,unit text not null default 'UN',cost numeric(14,2) not null default 0 check(cost>=0),
 sale_price numeric(14,2) not null default 0 check(sale_price>=0),quantity numeric(14,3) not null default 0,
 min_quantity numeric(14,3) not null default 0,created_at timestamptz not null default now(),unique(organization_id,sku)
);
create table public.stock_movements (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 item_id uuid not null references public.inventory_items(id) on delete cascade,
 work_order_id uuid references public.work_orders(id), delta numeric(14,3) not null check(delta<>0),
 reason text,created_by uuid references auth.users(id),created_at timestamptz not null default now()
);
create table public.calendar_events (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 title text not null,starts_at timestamptz not null,ends_at timestamptz not null,
 work_order_id uuid references public.work_orders(id),assigned_to uuid references auth.users(id),notes text,
 created_at timestamptz not null default now(),check(ends_at>starts_at)
);
create table public.documents (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 work_order_id uuid references public.work_orders(id),customer_id uuid references public.customers(id),
 file_name text not null,storage_path text not null unique,mime_type text,uploaded_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,title text not null,body text,read_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.audit_logs (
 id bigint generated always as identity primary key,organization_id uuid not null references public.organizations(id) on delete cascade,
 actor_id uuid,entity text not null,entity_id uuid not null,action text not null,
 details jsonb not null default '{}'::jsonb,created_at timestamptz not null default now()
);
create table public.organization_invitations (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete cascade,
 email text not null,role text not null check(role in ('ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE')),
 token uuid not null unique default gen_random_uuid(),expires_at timestamptz not null default(now()+interval '7 days'),accepted_at timestamptz,
 created_at timestamptz not null default now(),unique(organization_id,email)
);
-- Constrain cross-tenant references through immutable trigger; prevents data correlation by foreign UUID.
create function public.enforce_org_references() returns trigger language plpgsql set search_path = '' as $$
declare ref_id uuid; ref_org uuid; ref_tbl text;begin
 if TG_TABLE_NAME='customer_users' then
  if not exists(select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then raise exception 'Cliente não pertence à empresa';end if;
 end if;
 if TG_TABLE_NAME='sites' then
  if not exists(select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then raise exception 'Cliente não pertence à empresa';end if;
 end if;
 if TG_TABLE_NAME='assets' then
  if new.customer_id is not null and not exists(select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then raise exception 'Cliente inválido';end if;
  if new.site_id is not null and not exists(select 1 from public.sites where id=new.site_id and organization_id=new.organization_id) then raise exception 'Unidade inválida';end if;
 end if;
 if TG_TABLE_NAME in ('work_orders','quotes','contracts','invoices') then
  if not exists(select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then raise exception 'Cliente inválido';end if;
 end if;
 if TG_TABLE_NAME in ('work_orders','calendar_events') then
  if new.assigned_to is not null and not exists(select 1 from public.organization_members where organization_id=new.organization_id and user_id=new.assigned_to and status='ACTIVE') then raise exception 'Responsável fora da empresa';end if;
 end if;
 if TG_TABLE_NAME='work_orders' then
  if new.site_id is not null and not exists(select 1 from public.sites where id=new.site_id and organization_id=new.organization_id and customer_id=new.customer_id) then raise exception 'Unidade inválida';end if;
  if new.asset_id is not null and not exists(select 1 from public.assets where id=new.asset_id and organization_id=new.organization_id) then raise exception 'Ativo inválido';end if;
 end if;
 -- Check every optional reference to work order, quote, invoice, contract, inventory and customer.
 if TG_TABLE_NAME in ('work_order_tasks','work_order_notes','time_entries','calendar_events','documents','stock_movements') then
  if new.work_order_id is not null and not exists(select 1 from public.work_orders where id=new.work_order_id and organization_id=new.organization_id) then raise exception 'OS inválida';end if;
 end if;
 if TG_TABLE_NAME='quote_items' and not exists(select 1 from public.quotes where id=new.quote_id and organization_id=new.organization_id) then raise exception 'Orçamento inválido';end if;
 if TG_TABLE_NAME='payments' and not exists(select 1 from public.invoices where id=new.invoice_id and organization_id=new.organization_id) then raise exception 'Fatura inválida';end if;
 if TG_TABLE_NAME='stock_movements' and not exists(select 1 from public.inventory_items where id=new.item_id and organization_id=new.organization_id) then raise exception 'Item inválido';end if;
 if TG_TABLE_NAME='invoices' then
  if new.work_order_id is not null and not exists(select 1 from public.work_orders where id=new.work_order_id and organization_id=new.organization_id) then raise exception 'OS inválida';end if;
  if new.contract_id is not null and not exists(select 1 from public.contracts where id=new.contract_id and organization_id=new.organization_id) then raise exception 'Contrato inválido';end if;
 end if;
 if TG_TABLE_NAME='documents' and new.customer_id is not null and not exists(select 1 from public.customers where id=new.customer_id and organization_id=new.organization_id) then raise exception 'Cliente inválido';end if;
 return new;
end;$$;
do $$ declare t text; begin foreach t in array array['customer_users','sites','assets','work_orders','work_order_tasks','work_order_notes','time_entries','quotes','quote_items','contracts','invoices','payments','stock_movements','calendar_events','documents'] loop
 execute format('create trigger trg_org_refs before insert or update on public.%I for each row execute function public.enforce_org_references()',t);
 end loop;end $$;

-- Triggers de integridade: totais calculados exclusivamente no servidor.
create function public.recalc_quote_total() returns trigger language plpgsql security definer set search_path = '' as $$
begin update public.quotes set total=coalesce((select sum(quantity*unit_price) from public.quote_items where quote_id=coalesce(new.quote_id,old.quote_id)),0) where id=coalesce(new.quote_id,old.quote_id);return null;end;$$;
create trigger trg_quote_total after insert or update or delete on public.quote_items for each row execute function public.recalc_quote_total();
create function public.recalc_invoice_payment() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_id uuid;v_paid numeric;v_total numeric;begin
 v_id=coalesce(new.invoice_id,old.invoice_id);
 select amount into v_total from public.invoices where id=v_id for update;
 select coalesce(sum(amount),0) into v_paid from public.payments where invoice_id=v_id;
 if v_paid>v_total then raise exception 'Pagamentos excedem o valor da fatura';end if;
 update public.invoices set paid_amount=v_paid,status=case when v_paid>=v_total then 'PAID' when v_paid>0 then 'PARTIAL' else 'PENDING' end where id=v_id and status<>'CANCELED';
 return null;
end;$$;
create trigger trg_invoice_paid after insert or update or delete on public.payments for each row execute function public.recalc_invoice_payment();
create function public.apply_stock_movement() returns trigger language plpgsql security definer set search_path = '' as $$
begin update public.inventory_items set quantity=quantity+new.delta where id=new.item_id and organization_id=new.organization_id and quantity+new.delta>=0;
 if not found then raise exception 'Estoque insuficiente ou item inválido';end if;return new;end;$$;
create trigger trg_stock after insert on public.stock_movements for each row execute function public.apply_stock_movement();
create function public.prevent_stock_mutation() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Movimentos de estoque são imutáveis. Lance um ajuste inverso.';end;$$;
create trigger trg_stock_immutable before update or delete on public.stock_movements for each row execute function public.prevent_stock_mutation();
create function public.prevent_payment_mutation() returns trigger language plpgsql set search_path='' as $$begin raise exception 'Pagamentos são imutáveis; registre ajustes pela área financeira.';end;$$;
create trigger trg_payments_immutable before update or delete on public.payments for each row execute function public.prevent_payment_mutation();
create function public.prevent_identity_change() returns trigger language plpgsql set search_path='' as $$
begin if new.organization_id<>old.organization_id then raise exception 'Não é permitido transferir registros entre empresas';end if;return new;end;$$;
do $$ declare t text;begin foreach t in array array['customers','sites','assets','services','work_orders','work_order_tasks','work_order_notes','time_entries','quotes','quote_items','contracts','invoices','expenses','inventory_items','calendar_events','documents','notifications','customer_users','organization_invitations'] loop
 execute format('create trigger trg_identity before update on public.%I for each row execute function public.prevent_identity_change()',t);
 end loop;end $$;

-- Protege alterações em membros; gestão apenas por OWNER e convite validado.
create function public.accept_org_invitation(p_token uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_inv public.organization_invitations%rowtype;v_email text;begin
 if auth.uid() is null then raise exception 'Autenticação necessária';end if;
 v_email=lower(coalesce(auth.jwt()->>'email',''));
 select * into v_inv from public.organization_invitations where token=p_token and accepted_at is null and expires_at>now() for update;
 if not found or lower(v_inv.email)<>v_email then raise exception 'Convite inválido ou expirado';end if;
 insert into public.organization_members(organization_id,user_id,role,status) values(v_inv.organization_id,auth.uid(),v_inv.role,'ACTIVE') on conflict(organization_id,user_id) do nothing;
 update public.organization_invitations set accepted_at=now() where id=v_inv.id;
 return v_inv.organization_id;
end;$$;
revoke all on function public.accept_org_invitation(uuid) from public;grant execute on function public.accept_org_invitation(uuid) to authenticated;
create function public.create_customer_link(p_org uuid,p_customer uuid,p_email text) returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid;begin
 if not public.has_org_role(p_org,array['OWNER','ADMIN','MANAGER']) then raise exception 'Acesso negado';end if;
 if not exists(select 1 from public.customers where id=p_customer and organization_id=p_org) then raise exception 'Cliente inválido';end if;
 select id into v_user from auth.users where lower(email)=lower(trim(p_email)) and email_confirmed_at is not null;
 if v_user is null then raise exception 'O cliente precisa criar e confirmar uma conta com esse e-mail antes de ser vinculado';end if;
 insert into public.customer_users(organization_id,customer_id,user_id) values(p_org,p_customer,v_user) on conflict do nothing;
end;$$;
revoke all on function public.create_customer_link(uuid,uuid,text) from public;grant execute on function public.create_customer_link(uuid,uuid,text) to authenticated;

-- Habilitar RLS em TODAS as tabelas públicas.
do $$declare t text;begin foreach t in array array['profiles','organizations','organization_members','customers','customer_users','sites','assets','services','work_orders','work_order_tasks','work_order_notes','time_entries','quotes','quote_items','contracts','invoices','payments','expenses','inventory_items','stock_movements','calendar_events','documents','notifications','audit_logs','organization_invitations'] loop
 execute format('alter table public.%I enable row level security',t);end loop;end $$;
create policy profile_read on public.profiles for select to authenticated using (id=(select auth.uid()) or exists(select 1 from public.organization_members m1 join public.organization_members m2 on m1.organization_id=m2.organization_id where m1.user_id=(select auth.uid()) and m1.status='ACTIVE' and m2.user_id=profiles.id and m2.status='ACTIVE'));
create policy profile_own_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy org_read on public.organizations for select to authenticated using(public.is_org_member(id) or exists(select 1 from public.customer_users cu where cu.organization_id=id and cu.user_id=(select auth.uid())));
create policy org_update on public.organizations for update to authenticated using(public.has_org_role(id,array['OWNER','ADMIN'])) with check(public.has_org_role(id,array['OWNER','ADMIN']));
create policy membership_read on public.organization_members for select to authenticated using(public.is_org_member(organization_id));
create policy membership_owner_insert on public.organization_members for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER']) and role<>'OWNER');
create policy membership_owner_update on public.organization_members for update to authenticated using(public.has_org_role(organization_id,array['OWNER'])) with check(public.has_org_role(organization_id,array['OWNER']));
create policy membership_owner_delete on public.organization_members for delete to authenticated using(public.has_org_role(organization_id,array['OWNER']) and user_id<>(select auth.uid()));
-- Add read policies for operational records, plus role-scoped write policies.
do $$ declare t text;begin foreach t in array array['customers','sites','assets','services','work_orders','work_order_tasks','work_order_notes','time_entries','quotes','quote_items','contracts','invoices','payments','expenses','inventory_items','stock_movements','calendar_events','documents'] loop
 execute format('create policy %I on public.%I for select to authenticated using(public.is_org_member(organization_id))','read_'||t,t);
 end loop;end $$;
-- Financeiro restrito: substituir acesso genérico de leitura.
drop policy read_invoices on public.invoices;drop policy read_payments on public.payments;drop policy read_expenses on public.expenses;
create policy read_invoices on public.invoices for select to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']) or public.is_org_client(organization_id,customer_id));
create policy read_payments on public.payments for select to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']) or exists(select 1 from public.invoices i where i.id=invoice_id and public.is_org_client(i.organization_id,i.customer_id)));
create policy read_expenses on public.expenses for select to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','FINANCE']));
-- Dados de clientes são visíveis apenas ao cliente vinculado.
create policy client_customers on public.customers for select to authenticated using(public.is_org_client(organization_id,id));
create policy client_sites on public.sites for select to authenticated using(public.is_org_client(organization_id,customer_id));
create policy client_assets on public.assets for select to authenticated using(customer_id is not null and public.is_org_client(organization_id,customer_id));
create policy client_orders on public.work_orders for select to authenticated using(public.is_org_client(organization_id,customer_id));
create policy client_quotes on public.quotes for select to authenticated using(public.is_org_client(organization_id,customer_id));
create policy client_contracts on public.contracts for select to authenticated using(public.is_org_client(organization_id,customer_id));
create policy client_quote_items on public.quote_items for select to authenticated using(exists(select 1 from public.quotes q where q.id=quote_id and public.is_org_client(q.organization_id,q.customer_id)));
create policy client_work_order_tasks on public.work_order_tasks for select to authenticated using(exists(select 1 from public.work_orders w where w.id=work_order_id and public.is_org_client(w.organization_id,w.customer_id)));
-- Standard writes for service operations: staff except FINANCE and CLIENT.
do $$ declare t text;begin foreach t in array array['customers','sites','assets','services','work_orders','work_order_tasks','work_order_notes','time_entries','calendar_events'] loop
 execute format('create policy %I on public.%I for insert to authenticated with check(public.has_org_role(organization_id,array[''OWNER'',''ADMIN'',''MANAGER'',''DISPATCHER'',''TECHNICIAN'']))','insert_'||t,t);
 execute format('create policy %I on public.%I for update to authenticated using(public.has_org_role(organization_id,array[''OWNER'',''ADMIN'',''MANAGER'',''DISPATCHER'',''TECHNICIAN''])) with check(public.has_org_role(organization_id,array[''OWNER'',''ADMIN'',''MANAGER'',''DISPATCHER'',''TECHNICIAN'']))','update_'||t,t);
 end loop;end $$;
-- Notas sempre de autoria própria.
drop policy insert_work_order_notes on public.work_order_notes;
create policy insert_work_order_notes on public.work_order_notes for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']) and author_id=auth.uid());
drop policy update_work_order_notes on public.work_order_notes;
-- Só time_entries criados pelo próprio usuário.
drop policy insert_time_entries on public.time_entries;
create policy insert_time_entries on public.time_entries for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']) and user_id=auth.uid());
-- Gestão financeira e comercial.
do $$ declare t text;begin foreach t in array array['quotes','quote_items','contracts','invoices','payments','expenses'] loop
 execute format('create policy %I on public.%I for insert to authenticated with check(public.has_org_role(organization_id,array[''OWNER'',''ADMIN'',''MANAGER'',''FINANCE'']))','insert_'||t,t);
 end loop;end $$;
do $$ declare t text;begin foreach t in array array['quotes','quote_items','contracts','invoices','expenses'] loop
 execute format('create policy %I on public.%I for update to authenticated using(public.has_org_role(organization_id,array[''OWNER'',''ADMIN'',''MANAGER'',''FINANCE''])) with check(public.has_org_role(organization_id,array[''OWNER'',''ADMIN'',''MANAGER'',''FINANCE'']))','update_'||t,t);
 end loop;end $$;
-- Pagamentos somente inserção. Fatura total pago/status protegidos por trigger abaixo.
create function public.protect_invoice_totals() returns trigger language plpgsql set search_path='' as $$
begin
 if current_setting('orbita.recalculating_payment',true)='yes' then return new;end if;
 if tg_op='UPDATE' and (new.paid_amount is distinct from old.paid_amount or (new.status in ('PARTIAL','PAID') and new.status is distinct from old.status)) then raise exception 'Os pagamentos devem ser registrados pela tabela payments';end if;
 if tg_op='INSERT' and (new.paid_amount<>0 or new.status in ('PARTIAL','PAID')) then raise exception 'Não é permitido criar fatura como paga';end if;
 return new;
end;$$;
create trigger trg_protect_invoice_totals before insert or update on public.invoices for each row execute function public.protect_invoice_totals();
create or replace function public.recalc_invoice_payment() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_paid numeric;v_total numeric;begin
 v_id=coalesce(new.invoice_id,old.invoice_id);
 select amount into v_total from public.invoices where id=v_id for update;
 select coalesce(sum(amount),0) into v_paid from public.payments where invoice_id=v_id;
 if v_paid>v_total then raise exception 'Pagamentos excedem o valor da fatura';end if;
 perform set_config('orbita.recalculating_payment','yes',true);
 update public.invoices set paid_amount=v_paid,status=case when v_paid>=v_total then 'PAID' when v_paid>0 then 'PARTIAL' else 'PENDING' end where id=v_id and status<>'CANCELED';
 perform set_config('orbita.recalculating_payment','',true);
 return null;end;$$;
-- Itens de estoque alterados exclusivamente por movements.
create function public.protect_stock_qty() returns trigger language plpgsql set search_path='' as $$
begin if tg_op='INSERT' and new.quantity<>0 then raise exception 'Crie o item com estoque zero e registre entrada';end if;
 if tg_op='UPDATE' and new.quantity is distinct from old.quantity and current_setting('orbita.adjusting_stock',true)<>'yes' then raise exception 'Use movimentações para alterar quantidades';end if;return new;end;$$;
create trigger trg_protect_stock before insert or update on public.inventory_items for each row execute function public.protect_stock_qty();
create or replace function public.apply_stock_movement() returns trigger language plpgsql security definer set search_path='' as $$
begin perform set_config('orbita.adjusting_stock','yes',true);
 update public.inventory_items set quantity=quantity+new.delta where id=new.item_id and organization_id=new.organization_id and quantity+new.delta>=0;
 if not found then raise exception 'Estoque insuficiente ou item inválido';end if;
 perform set_config('orbita.adjusting_stock','',true);return new;end;$$;
create policy insert_stock on public.stock_movements for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','TECHNICIAN']) and created_by=auth.uid());
create policy insert_items on public.inventory_items for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy update_items on public.inventory_items for update to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER'])) with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_user_read on public.customer_users for select to authenticated using(user_id=auth.uid() or public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_user_insert on public.customer_users for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy customer_user_delete on public.customer_users for delete to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
create policy notifications_select on public.notifications for select to authenticated using(user_id=auth.uid());
create policy notifications_update on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy audit_read on public.audit_logs for select to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN']));
create policy invitation_read on public.organization_invitations for select to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN']));
create policy invitation_create on public.organization_invitations for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN']));
create policy invitation_delete on public.organization_invitations for delete to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN']));
create policy docs_insert on public.documents for insert to authenticated with check(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']) and uploaded_by=auth.uid());
create policy docs_delete on public.documents for delete to authenticated using(public.has_org_role(organization_id,array['OWNER','ADMIN','MANAGER']));
-- Storage privado. Caminho deve começar pelo UUID da organização e upload somente para membro operacional.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('orbita-private','orbita-private',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp','text/plain']) on conflict(id) do nothing;
create policy orbita_upload on storage.objects for insert to authenticated with check(bucket_id='orbita-private' and public.has_org_role((split_part(name,'/',1))::uuid,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN']));
create policy orbita_read on storage.objects for select to authenticated using(bucket_id='orbita-private' and public.is_org_member((split_part(name,'/',1))::uuid));
create policy orbita_delete on storage.objects for delete to authenticated using(bucket_id='orbita-private' and public.has_org_role((split_part(name,'/',1))::uuid,array['OWNER','ADMIN','MANAGER']));
-- Consulta separada para cliente autenticado que pode usar o portal.
create policy client_docs on public.documents for select to authenticated using(customer_id is not null and public.is_org_client(organization_id,customer_id));
-- Os arquivos do portal do cliente são entregues por função RPC que valida acesso.
create function public.customer_document_signed_path(p_document uuid) returns text language plpgsql stable security definer set search_path='' as $$
declare v record;begin
 select organization_id,customer_id,storage_path into v from public.documents where id=p_document;
 if not found or v.customer_id is null or not public.is_org_client(v.organization_id,v.customer_id) then raise exception 'Acesso negado';end if;
 return v.storage_path;
end;$$;
-- Segurança adicional: evitar acessos anônimos a tudo, exceto funções especificamente autorizadas.
revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;

-- Acesso do cliente apenas aos arquivos vinculados ao seu cadastro.
create policy orbita_client_storage_read on storage.objects for select to authenticated using (
 bucket_id='orbita-private' and exists (
  select 1 from public.documents d
  where d.storage_path=name and d.customer_id is not null
  and public.is_org_client(d.organization_id,d.customer_id)
 )
);
-- Convites podem ser renovados apenas pelos administradores.
create policy invitation_update on public.organization_invitations for update to authenticated
 using(public.has_org_role(organization_id,array['OWNER','ADMIN']))
 with check(public.has_org_role(organization_id,array['OWNER','ADMIN']));
-- Impede a saída ou desativação do último proprietário do workspace.
create function public.protect_last_owner() returns trigger language plpgsql set search_path='' as $$
begin
 if old.role='OWNER' and old.status='ACTIVE' and (tg_op='DELETE' or new.role<>'OWNER' or new.status<>'ACTIVE') then
  if (select count(*) from public.organization_members where organization_id=old.organization_id and role='OWNER' and status='ACTIVE')<=1 then
   raise exception 'O workspace precisa ter pelo menos um proprietário ativo';
  end if;
 end if;
 if tg_op='DELETE' then return old;end if;
 if new.organization_id<>old.organization_id or new.user_id<>old.user_id then raise exception 'Identidade de vínculo imutável';end if;
 return new;
end;$$;
create trigger trg_last_owner before update or delete on public.organization_members for each row execute function public.protect_last_owner();
-- Protege valor total dos orçamentos contra alteração direta pelo cliente.
create function public.protect_quote_total() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' and new.total<>0 then raise exception 'Adicione itens para calcular o total';end if;
 if tg_op='UPDATE' and new.total is distinct from old.total and current_setting('orbita.calculating_quote',true)<>'yes' then raise exception 'O total deve ser calculado a partir dos itens';end if;
 return new;
end;$$;
create trigger trg_protect_quote_total before insert or update on public.quotes for each row execute function public.protect_quote_total();
create or replace function public.recalc_quote_total() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid;begin
 v_id=coalesce(new.quote_id,old.quote_id);
 perform set_config('orbita.calculating_quote','yes',true);
 update public.quotes set total=coalesce((select sum(quantity*unit_price) from public.quote_items where quote_id=v_id),0) where id=v_id;
 perform set_config('orbita.calculating_quote','',true);
 return null;
end;$$;
-- Registro de status de OS no campo de conclusão.
create function public.manage_work_order_completion() returns trigger language plpgsql set search_path='' as $$
begin
 if new.status='DONE' and (tg_op='INSERT' or old.status is distinct from 'DONE') then new.completed_at=now();end if;
 if new.status<>'DONE' then new.completed_at=null;end if;
 return new;
end;$$;
create trigger trg_order_completion before insert or update on public.work_orders for each row execute function public.manage_work_order_completion();
-- Auditoria mínima de alterações relevantes, gerada pelo servidor.
create function public.audit_operational_change() returns trigger language plpgsql security definer set search_path='' as $$
declare v_id uuid;v_org uuid;begin
 if tg_op='DELETE' then v_id=old.id;v_org=old.organization_id;else v_id=new.id;v_org=new.organization_id;end if;
 insert into public.audit_logs(organization_id,actor_id,entity,entity_id,action,details)
 values(v_org,auth.uid(),tg_table_name,v_id,tg_op,jsonb_build_object('at',now()));
 if tg_op='DELETE' then return old;end if;
 return new;
end;$$;
do $$declare t text;begin foreach t in array array['customers','sites','assets','services','work_orders','quotes','contracts','invoices','expenses','inventory_items'] loop
 execute format('create trigger trg_audit_%I after insert or update or delete on public.%I for each row execute function public.audit_operational_change()',t,t);
 end loop;end $$;
create index idx_orders_org_schedule on public.work_orders(organization_id,scheduled_at);
create index idx_quotes_org_created on public.quotes(organization_id,created_at desc);
create index idx_invoices_org_due on public.invoices(organization_id,due_date);
create index idx_events_org_start on public.calendar_events(organization_id,starts_at);
create index idx_invites_token on public.organization_invitations(token);
create index idx_docs_org_customer on public.documents(organization_id,customer_id);
create index idx_contracts_org_next on public.contracts(organization_id,next_service_on);
-- Garantir grants de API para authenticated; RLS continua restringindo cada registro.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
