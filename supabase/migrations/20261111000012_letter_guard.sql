-- Guardia de la letra: el árbitro IA a veces marca válida una respuesta que no empieza con la letra de la ronda
-- (visto con "Mesa" en ronda D). Antes de puntuar, el servidor revisa la letra de forma determinista y corrige.

create or replace function public._starts_with_letter(p_value text, p_letter text) returns boolean
language sql immutable as $$
  select case
    when btrim(coalesce(p_value, '')) = '' then false
    when p_letter = 'Ñ' then lower(left(btrim(p_value), 1)) = 'ñ'
    -- la Ñ es distinta de la N: "Ñandú" no vale en ronda N
    when p_letter = 'N' then lower(left(btrim(p_value), 1)) <> 'ñ' and upper(left(public.norm(p_value), 1)) = 'N'
    else upper(left(public.norm(p_value), 1)) = p_letter end
$$;

create or replace function public._finish_validation(p_round uuid, p_ai boolean) returns void
language plpgsql security definer set search_path = public as $$
declare rd rounds;
begin
  select * into rd from rounds where id = p_round for update;
  if rd.status <> 'validating' then return; end if;
  update answers set
    status = 'invalid',
    reason = 'No empieza con la letra ' || rd.letter || '.',
    checks = coalesce(checks, '{}'::jsonb) || jsonb_build_object('letter', false)
  where round_id = p_round and status in ('valid', 'doubtful') and not _starts_with_letter(value, rd.letter);
  perform _score_round(p_round);
  update rounds set status = 'results', validated_by_ai = p_ai, next_at = now() + interval '20 seconds' where id = p_round;
end $$;
revoke execute on function public._finish_validation(uuid, boolean) from public, anon, authenticated;
grant execute on function public._finish_validation(uuid, boolean) to service_role;
