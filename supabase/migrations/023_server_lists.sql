-- Listagem com busca, filtros, contagem e paginação no servidor, sob as RLS existentes.
begin;
create or replace function public.workspace_records(p_org uuid,p_table text,p_search text default '',p_status text default 'ALL',p_sort text default 'created_at',p_asc boolean default false,p_offset integer default 0,p_limit integer default 15)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
declare v_where text;v_rows jsonb;v_total bigint;v_statuses jsonb;
begin
 if not public.has_org_role(p_org,array['OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE']) then raise exception 'Acesso negado' using errcode='42501';end if;
 if p_table is null or p_table<>all(array['customers','sites','assets','services','work_orders','quotes','contracts','invoices','expenses','inventory_items','calendar_events','leads','opportunities','suppliers','purchase_orders','team_shifts','training_records','inspections','nonconformities','support_tickets','service_requests','vehicles','route_stops','projects','project_milestones','customer_feedback','follow_ups','cost_centers','financial_goals','campaigns','referral_partners','procedures','risk_register','customer_segments','loyalty_rewards']) then raise exception 'Módulo inválido' using errcode='22023';end if;
 if p_limit is null or p_limit<1 or p_limit>500 or p_offset is null or p_offset<0 or length(coalesce(p_search,''))>200 then raise exception 'Parâmetros de consulta inválidos' using errcode='22023';end if;
 if not exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=to_regclass('public.'||p_table) and a.attname=p_sort and a.attnum>0 and not a.attisdropped) then raise exception 'Ordenação inválida' using errcode='22023';end if;
 v_where := 'r.organization_id=$1 and ($3=''ALL'' or coalesce(to_jsonb(r)->>''status'',to_jsonb(r)->>''stage'','''')=$3) and ($2='''' or exists(select 1 from jsonb_each_text(to_jsonb(r)) k where strpos(lower(k.value),lower($2))>0) or exists(select 1 from public.customers c where c.organization_id=$1 and c.id::text=to_jsonb(r)->>''customer_id'' and strpos(lower(c.name),lower($2))>0) or exists(select 1 from public.organization_members m join public.profiles p on p.id=m.user_id where m.organization_id=$1 and m.user_id::text=to_jsonb(r)->>''assigned_to'' and strpos(lower(p.full_name||'' ''||coalesce(p.email,'''')),lower($2))>0))';
 execute format('select count(*) from public.%I r where %s',p_table,v_where) into v_total using p_org,coalesce(btrim(p_search),''),coalesce(p_status,'ALL');
 execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from (select r.* from public.%I r where %s order by r.%I %s nulls last,r.id %s offset $4 limit $5) x',p_table,v_where,p_sort,case when p_asc then 'asc' else 'desc' end,case when p_asc then 'asc' else 'desc' end)
 into v_rows using p_org,coalesce(btrim(p_search),''),coalesce(p_status,'ALL'),p_offset,p_limit;
 execute format('select coalesce(jsonb_agg(s),''[]''::jsonb) from (select distinct coalesce(to_jsonb(r)->>''status'',to_jsonb(r)->>''stage'') s from public.%I r where r.organization_id=$1) x where s is not null',p_table) into v_statuses using p_org;
 return jsonb_build_object('rows',v_rows,'total',v_total,'statuses',v_statuses);
end;$fn$;
revoke all on function public.workspace_records(uuid,text,text,text,text,boolean,integer,integer) from public,anon;
grant execute on function public.workspace_records(uuid,text,text,text,text,boolean,integer,integer) to authenticated;
notify pgrst,'reload schema';
commit;
