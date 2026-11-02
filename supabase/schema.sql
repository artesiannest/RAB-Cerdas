-- RAB Cerdas: single-company workspace, no public signup or anonymous data access.
create table if not exists public.rabin_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check(length(name) between 1 and 100),
 email text not null,
 role text not null check(role in ('admin','pm','finance','viewer')),
 active boolean not null default true
);
create table if not exists public.rabin_projects (
 id uuid primary key,
 owner_id uuid not null references auth.users(id),
 payload jsonb not null,
 version integer not null default 1,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create unique index if not exists rabin_project_code on public.rabin_projects(lower(payload->>'code'));
alter table public.rabin_profiles enable row level security;
alter table public.rabin_projects enable row level security;
create or replace function public.rabin_role() returns text language sql stable security definer set search_path=pg_catalog,public as $$
 select role from public.rabin_profiles where id=auth.uid() and active=true
$$;
revoke all on function public.rabin_role() from public;
grant execute on function public.rabin_role() to authenticated;
drop policy if exists rabin_profile_select on public.rabin_profiles;
create policy rabin_profile_select on public.rabin_profiles for select to authenticated using (id=auth.uid() or public.rabin_role()='admin');
drop policy if exists rabin_project_select on public.rabin_projects;
create policy rabin_project_select on public.rabin_projects for select to authenticated using (public.rabin_role() is not null);
revoke all on public.rabin_profiles,public.rabin_projects from anon,authenticated;
grant select on public.rabin_profiles,public.rabin_projects to authenticated;

create or replace function public.rabin_budget_total(p jsonb) returns numeric language sql immutable set search_path=pg_catalog,public as $$
 with subtotal as (select coalesce(sum(round((value->>'qty')::numeric*(value->>'price')::numeric)),0) n from jsonb_array_elements(p->'lines')),
 net as (select n-round(n*(p->>'discount')::numeric/100) n from subtotal)
 select n+round(n*(p->>'tax')::numeric/100)+round(n*(p->>'contingency')::numeric/100) from net
$$;
revoke all on function public.rabin_budget_total(jsonb) from public;

create or replace function public.rabin_save_project(p_id uuid,p_payload jsonb,p_version integer)
returns public.rabin_projects language plpgsql security definer set search_path=pg_catalog,public as $$
declare
 r public.rabin_projects; v_role text; v_name text; oldp jsonb; newp jsonb:=p_payload;
 oldstatus text; newstatus text; l jsonb; a jsonb; prior jsonb;
 allow_budget boolean; owner_ok boolean; expected_history jsonb; line_ids text[];
begin
 select role,name into v_role,v_name from public.rabin_profiles where id=auth.uid() and active=true;
 if v_role is null then raise exception 'Akun tidak aktif atau belum diberi akses.'; end if;
 if v_role='viewer' then raise exception 'Akun viewer tidak dapat mengubah data.'; end if;
 if p_id is null or jsonb_typeof(newp) is distinct from 'object' then raise exception 'Data proyek tidak valid.'; end if;
 select * into r from public.rabin_projects where id=p_id for update;
 if not found then
  if p_version<>0 or v_role not in ('admin','pm') then raise exception 'Tidak dapat membuat proyek.'; end if;
  if newp->>'status' is distinct from 'draft' or (newp->>'revision')::integer<>1 or jsonb_array_length(coalesce(newp->'actuals','[]'))<>0 then raise exception 'Proyek baru harus berupa draf tanpa realisasi.'; end if;
  oldp:=null;
 else
  if r.version<>p_version then raise exception 'Data sudah berubah. Klik Perbarui data sebelum menyimpan kembali.'; end if;
  oldp:=r.payload; oldstatus:=oldp->>'status'; newstatus:=newp->>'status';
  owner_ok:=v_role='admin' or (v_role='pm' and r.owner_id=auth.uid());
  if v_role='pm' and not owner_ok then raise exception 'Anda bukan pemilik proyek ini.'; end if;
  if v_role='finance' and ((newp-ARRAY['actuals','logs']) is distinct from (oldp-ARRAY['actuals','logs']) or oldstatus<>'approved') then raise exception 'Keuangan hanya dapat mencatat realisasi pada RAB disetujui.'; end if;
  if newstatus is distinct from oldstatus then
   if not ((oldstatus='draft' and newstatus='review' and owner_ok) or
           (oldstatus='review' and newstatus in ('approved','draft') and v_role='admin') or
           (oldstatus='approved' and newstatus='draft' and owner_ok)) then raise exception 'Perubahan status tidak diizinkan.'; end if;
  end if;
  allow_budget:=oldstatus='draft' and owner_ok;
  if not allow_budget and (newp->'lines' is distinct from oldp->'lines' or newp->'discount' is distinct from oldp->'discount' or newp->'tax' is distinct from oldp->'tax' or newp->'contingency' is distinct from oldp->'contingency') then raise exception 'Rincian RAB terkunci. Buat revisi sebelum mengubahnya.'; end if;
  if not allow_budget and (newp-ARRAY['actuals','logs','history','revision','status','phase','progress','notes']) is distinct from (oldp-ARRAY['actuals','logs','history','revision','status','phase','progress','notes']) then raise exception 'Informasi proyek terkunci di luar draf.'; end if;
  if newp->'actuals' is distinct from oldp->'actuals' then
   if v_role not in ('admin','finance') or oldstatus<>'approved' or newstatus<>'approved' then raise exception 'Tidak diizinkan mengubah realisasi.'; end if;
   -- Existing transaction facts remain immutable. Only a one-way cancellation is allowed.
   for prior in select value from jsonb_array_elements(oldp->'actuals') loop
    select value into a from jsonb_array_elements(newp->'actuals') where value->>'id'=prior->>'id';
    if a is null then raise exception 'Transaksi tidak boleh dihapus.'; end if;
    if (a-ARRAY['void','voidReason']) is distinct from (prior-ARRAY['void','voidReason']) then raise exception 'Fakta transaksi tidak boleh diubah. Batalkan dan catat transaksi pengganti.'; end if;
    if coalesce((prior->>'void')::boolean,false) and a is distinct from prior then raise exception 'Pembatalan tidak dapat dibatalkan kembali.'; end if;
   end loop;
  end if;
 end if;
 if length(trim(coalesce(newp->>'name',''))) not between 1 and 120 or length(trim(coalesce(newp->>'code',''))) not between 1 and 40 or length(trim(coalesce(newp->>'client',''))) not between 1 and 120 or length(trim(coalesce(newp->>'manager',''))) not between 1 and 100 then raise exception 'Lengkapi informasi proyek.'; end if;
 if (newp->>'start') is null or (newp->>'end') is null or (newp->>'end')::date<(newp->>'start')::date then raise exception 'Tanggal proyek tidak valid.'; end if;
 if coalesce(newp->>'status','') not in ('draft','review','approved') or coalesce(newp->>'phase','') not in ('planned','active','done','hold') then raise exception 'Status tidak valid.'; end if;
 if coalesce((newp->>'progress')::numeric,-1) not between 0 and 100 or (newp->>'phase'='done' and (newp->>'progress')::numeric<>100) then raise exception 'Progres tidak valid.'; end if;
 if coalesce((newp->>'discount')::numeric,-1) not between 0 and 100 or coalesce((newp->>'tax')::numeric,-1) not between 0 and 100 or coalesce((newp->>'contingency')::numeric,-1) not between 0 and 100 then raise exception 'Persentase harus 0–100.'; end if;
 if jsonb_typeof(newp->'lines') is distinct from 'array' or jsonb_typeof(newp->'actuals') is distinct from 'array' then raise exception 'Rincian biaya tidak valid.'; end if;
 if jsonb_array_length(newp->'lines')>5000 or jsonb_array_length(newp->'actuals')>20000 then raise exception 'Batas jumlah rincian terlampaui.'; end if;
 if newp->>'status' in ('review','approved') and (jsonb_array_length(newp->'lines')=0 or (select coalesce(sum(round((value->>'qty')::numeric*(value->>'price')::numeric)),0) from jsonb_array_elements(newp->'lines'))*(1-(newp->>'discount')::numeric/100)<=0) then raise exception 'Total RAB harus lebih dari nol.'; end if;
 if (select count(*) from jsonb_array_elements(newp->'lines'))<>(select count(distinct value->>'id') from jsonb_array_elements(newp->'lines')) then raise exception 'ID komponen tidak unik.'; end if;
 select array_agg(value->>'id') into line_ids from jsonb_array_elements(newp->'lines');
 for l in select value from jsonb_array_elements(newp->'lines') loop
  if l->>'id' is null or length(trim(coalesce(l->>'name','')))=0 or length(trim(coalesce(l->>'category','')))=0 or length(trim(coalesce(l->>'unit','')))=0 or coalesce((l->>'qty')::numeric,0) not between 0.001 and 1000000000 or coalesce((l->>'price')::numeric,-1) not between 0 and 1000000000000 then raise exception 'Komponen biaya tidak valid.'; end if;
 end loop;
 if (select count(*) from jsonb_array_elements(newp->'actuals'))<>(select count(distinct value->>'id') from jsonb_array_elements(newp->'actuals')) then raise exception 'ID transaksi tidak unik.'; end if;
 for a in select value from jsonb_array_elements(newp->'actuals') loop
  if a->>'id' is null or a->>'lineId' is null or not coalesce((a->>'lineId')=any(line_ids),false) or coalesce((a->>'amount')::numeric,0) not between 1 and 100000000000000 or (a->>'amount')::numeric<>trunc((a->>'amount')::numeric) or a->>'date' is null or (a->>'date')::date>current_date or length(trim(coalesce(a->>'vendor','')))=0 or length(trim(coalesce(a->>'reference','')))=0 or length(trim(coalesce(a->>'description','')))=0 then raise exception 'Transaksi realisasi tidak valid.'; end if;
  if coalesce((a->>'void')::boolean,false) and length(trim(coalesce(a->>'voidReason','')))=0 then raise exception 'Alasan pembatalan wajib diisi.'; end if;
 end loop;
 -- Revisions and audit are assigned by the server, not trusted from clients.
 expected_history:=coalesce(oldp->'history','[]'::jsonb);
 if oldstatus='approved' and newp->>'status'='draft' then
  expected_history:=jsonb_build_array(jsonb_build_object('revision',oldp->'revision','date',now(),'lines',oldp->'lines','discount',oldp->'discount','tax',oldp->'tax','contingency',oldp->'contingency','total',
   public.rabin_budget_total(oldp)
  ))||expected_history;
  newp:=jsonb_set(newp,'{revision}',to_jsonb((oldp->>'revision')::integer+1));
 else newp:=jsonb_set(newp,'{revision}',coalesce(oldp->'revision','1'::jsonb)); end if;
 newp:=jsonb_set(newp,'{history}',expected_history);
 newp:=jsonb_set(newp,'{logs}',jsonb_build_array(jsonb_build_object('date',now(),'actor',v_name,'action',case when oldp is null then 'Proyek dibuat' when oldstatus is distinct from newp->>'status' then 'Status RAB: '||coalesce(oldstatus,'')||' → '||(newp->>'status') when oldp->'actuals' is distinct from newp->'actuals' then 'Realisasi biaya diperbarui' else 'Data proyek diperbarui' end))||coalesce(oldp->'logs','[]'::jsonb));
 if oldp is null then
  insert into public.rabin_projects(id,owner_id,payload) values(p_id,auth.uid(),newp) returning * into r;
 else update public.rabin_projects set payload=newp,version=version+1,updated_at=now() where id=p_id returning * into r; end if;
 return r;
end $$;
revoke all on function public.rabin_save_project(uuid,jsonb,integer) from public;
grant execute on function public.rabin_save_project(uuid,jsonb,integer) to authenticated;
