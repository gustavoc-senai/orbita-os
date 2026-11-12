-- ÓRBITA OS 017: relacionamento explícito para joins do PostgREST em gestão de equipe.
-- Preserve usuários e empresas existentes. Executar após migration 016.
insert into public.profiles(id,full_name,email)
select id,coalesce(raw_user_meta_data->>'full_name',''),email
from auth.users
on conflict(id) do nothing;
do $$begin
 if not exists(select 1 from pg_constraint where conname='organization_members_profile_fk' and conrelid='public.organization_members'::regclass) then
  alter table public.organization_members
    add constraint organization_members_profile_fk foreign key(user_id) references public.profiles(id) on delete cascade;
 end if;
end$$;
-- Pós-execução: verifique os relacionamentos na API e recarregue o cache PostgREST se necessário.
notify pgrst, 'reload schema';
