-- Buat user dahulu melalui Authentication > Users > Add user.
-- Ganti EMAIL dan NAMA. Jalankan sebagai pemilik proyek melalui SQL Editor.
insert into public.rabin_profiles(id,name,email,role)
select id,'Administrator Perusahaan',email,'admin'
from auth.users where lower(email)=lower('GANTI_EMAIL_ADMIN@perusahaan.com')
on conflict(id) do update set name=excluded.name,role=excluded.role,active=true;

-- Contoh penambahan PM. Ganti email dan role sesuai kebutuhan:
-- role hanya: admin / pm / finance / viewer
-- insert into public.rabin_profiles(id,name,email,role)
-- select id,'Nama Pegawai',email,'pm' from auth.users
-- where lower(email)=lower('pegawai@perusahaan.com')
-- on conflict(id) do update set name=excluded.name,role=excluded.role,active=true;
