-- ÓRBITA OS 1.3 — Convites profissionais, bloqueio e gestão segura de membros
-- Execute DEPOIS de 001 e 002, uma vez no SQL Editor do Supabase.

-- Convites somente por RPC: cliente não escolhe manualmente tokens ou altera campos protegidos.
drop policy if exists invitation_create on public.organization_invitations;
drop policy if exists invitation_update on public.organization_invitations;
drop policy if exists invitation_delete on public.organization_invitations;

create or replace function public.create_team_invite(p_org uuid,p_email text,p_role text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_email text;v_token uuid;begin
 if not public.has_org_role(p_org,array['OWNER','ADMIN']) then raise exception 'Sem permissão para enviar convites';end if;
 v_email=lower(trim(coalesce(p_email,'')));
 if length(v_email)>254 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'E-mail inválido';end if;
 if p_role not in ('ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE') then raise exception 'Perfil inválido';end if;
 if exists(select 1 from public.organization_members m join public.profiles p on p.id=m.user_id where m.organization_id=p_org and lower(p.email)=v_email and m.status='ACTIVE') then
  raise exception 'Este profissional já faz parte da equipe';
 end if;
 insert into public.organization_invitations(organization_id,email,role,token,expires_at,accepted_at)
 values(p_org,v_email,p_role,gen_random_uuid(),now()+interval '7 days',null)
 on conflict(organization_id,email) do update set role=excluded.role,token=excluded.token,
 expires_at=excluded.expires_at,accepted_at=null,created_at=now()
 returning token into v_token;
 return v_token;
end;$$;
revoke all on function public.create_team_invite(uuid,text,text) from public;
grant execute on function public.create_team_invite(uuid,text,text) to authenticated;

create or replace function public.cancel_team_invite(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_org uuid;begin
 select organization_id into v_org from public.organization_invitations where id=p_id;
 if v_org is null or not public.has_org_role(v_org,array['OWNER','ADMIN']) then raise exception 'Convite não encontrado ou acesso negado';end if;
 delete from public.organization_invitations where id=p_id and accepted_at is null;
end;$$;
revoke all on function public.cancel_team_invite(uuid) from public;
grant execute on function public.cancel_team_invite(uuid) to authenticated;

create or replace function public.set_team_member(p_org uuid,p_user uuid,p_role text,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare v_old public.organization_members%rowtype;begin
 if not public.has_org_role(p_org,array['OWNER']) then raise exception 'Somente o proprietário pode gerenciar perfis e suspensões';end if;
 if p_role not in ('OWNER','ADMIN','MANAGER','DISPATCHER','TECHNICIAN','FINANCE')
 or p_status not in ('ACTIVE','SUSPENDED') then raise exception 'Dados inválidos';end if;
 select * into v_old from public.organization_members where organization_id=p_org and user_id=p_user for update;
 if not found then raise exception 'Membro não encontrado';end if;
 if v_old.role='OWNER' and (p_role<>'OWNER' or p_status<>'ACTIVE') then
  raise exception 'Proprietários não podem ser suspensos ou rebaixados por esta operação';
 end if;
 if v_old.role<>'OWNER' and p_role='OWNER' then raise exception 'Transferência de propriedade requer fluxo específico';end if;
 update public.organization_members set role=p_role,status=p_status where organization_id=p_org and user_id=p_user;
end;$$;
revoke all on function public.set_team_member(uuid,uuid,text,text) from public;
grant execute on function public.set_team_member(uuid,uuid,text,text) to authenticated;

-- Revalida o token, o endereço autenticado e a situação da associação.
create or replace function public.accept_org_invitation(p_token uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_inv public.organization_invitations%rowtype;v_email text;v_existing public.organization_members%rowtype;begin
 if auth.uid() is null then raise exception 'Entre na sua conta para aceitar o convite';end if;
 select lower(email) into v_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
 if v_email is null then raise exception 'Confirme seu endereço de e-mail antes de aceitar';end if;
 select * into v_inv from public.organization_invitations where token=p_token and accepted_at is null and expires_at>now() for update;
 if not found or lower(v_inv.email)<>v_email then raise exception 'Convite expirado, cancelado ou de outro e-mail';end if;
 select * into v_existing from public.organization_members where organization_id=v_inv.organization_id and user_id=auth.uid() for update;
 if found then
  if v_existing.role='OWNER' then raise exception 'Não é possível alterar o proprietário por convite';end if;
  if v_existing.status='SUSPENDED' then raise exception 'Acesso suspenso; contate o proprietário';end if;
  -- Um convite não eleva permissões de membros já existentes.
 else
  insert into public.organization_members(organization_id,user_id,role,status)
  values(v_inv.organization_id,auth.uid(),v_inv.role,'ACTIVE');
 end if;
 update public.organization_invitations set accepted_at=now() where id=v_inv.id;
 return v_inv.organization_id;
end;$$;
revoke all on function public.accept_org_invitation(uuid) from public;
grant execute on function public.accept_org_invitation(uuid) to authenticated;

-- As permissões RLS continuam sendo aplicadas a toda consulta operacional.
