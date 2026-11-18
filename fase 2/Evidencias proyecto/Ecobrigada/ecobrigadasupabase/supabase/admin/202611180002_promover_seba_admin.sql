-- SOLO EL PROPIETARIO desde SQL Editor (rol postgres). NO en Flutter.
-- Concede administración a la cuenta ya registrada seba@gmail.com.
-- No crea usuarios ni modifica sus contraseñas.
begin;
do $$
declare v_id uuid;
begin
 select u.id into v_id from auth.users u where lower(u.email)='seba@gmail.com';
 if v_id is null then
   raise exception 'No existe seba@gmail.com en Supabase Auth. Primero debe existir esa cuenta.';
 end if;
 insert into public.perfiles(id,nombre,role)
 values(v_id,'Seba','admin')
 on conflict (id) do update set role='admin';
 raise notice 'Rol admin asignado al usuario UUID %',v_id;
end $$;
commit;
-- Verificar:
select u.email,p.role from auth.users u join public.perfiles p on p.id=u.id
where lower(u.email)='seba@gmail.com';
