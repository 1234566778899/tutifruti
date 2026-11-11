-- Bucket público para fotos de perfil (cada usuario escribe solo en su carpeta)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 2097152, array['image/jpeg','image/png'])
on conflict (id) do nothing;

create policy "avatars lectura" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars subir propio" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars actualizar propio" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars borrar propio" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Permite editar el avatar a una URL de foto
alter table public.profiles add constraint avatar_len check (char_length(avatar) <= 300);
