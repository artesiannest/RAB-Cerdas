# RAB Cerdas | Project Budget Control

Sistem pemantauan Rencana Anggaran Biaya untuk satu perusahaan. Tampilan clean modern, form login di tengah layar, layout responsive dan laporan rupiah.

## Mulai cepat
1. Ekstrak ZIP.
2. Buka index.html untuk mencoba mode demo. Disarankan gunakan Live Server di VS Code agar penyimpanan browser konsisten.
3. Klik Isi akun demo, lalu Masuk ke dashboard.
4. Untuk GitHub Pages, upload ISI folder paket ke root repository (index.html sejajar dengan style.css, config.js dan app.js).
5. Settings > Pages > Deploy from a branch > main > / (root) > Save. Buka URL yang diberikan GitHub setelah deployment selesai.

Tidak memerlukan npm, build, node_modules atau instalasi library pada frontend.

## Akun demo lokal
| Peran | Email | Kata sandi |
|---|---|---|
| Administrator | admin@rabin.demo | RabinDemo26! |
| Project Manager | pm@rabin.demo | RabinDemo26! |
| Keuangan | finance@rabin.demo | RabinDemo26! |
| Manajemen / Viewer | viewer@rabin.demo | RabinDemo26! |

Akun demo bukan akun Supabase. Password demo adalah bagian dari contoh publik. Jangan gunakan mode demo untuk menyimpan data rahasia perusahaan.

## Modul
- Dashboard: total RAB, baseline anggaran disetujui, realisasi, sisa anggaran, persentase penggunaan biaya dan perhatian proyek.
- Proyek: tambah proyek, PIC, klien/divisi, tanggal rencana, status pelaksanaan, progres manual dan catatan.
- Rincian RAB: kategori, uraian, volume, satuan, harga satuan, subtotal, diskon, pajak dan cadangan.
- Persetujuan: draf > pengajuan > disetujui atau dikembalikan ke draf oleh admin.
- Revisi: RAB yang disetujui dibekukan. Buat revisi untuk mengubah rincian, dengan snapshot angka lama dan persetujuan ulang.
- Realisasi: pilih proyek/komponen, tanggal, nominal, vendor/penerima, referensi bukti dan uraian. Kelebihan biaya tetap dicatat dan ditandai.
- Pembatalan: transaksi tidak dihapus; pembatalan membutuhkan alasan dan tidak dihitung dalam realisasi aktif.
- Laporan: CSV dapat dibuka di Excel; cetak / simpan PDF menggunakan dialog browser.
- Riwayat: catatan perubahan dan snapshot revisi sebelumnya.
- Pengaturan: informasi mode penyimpanan dan export data JSON. File backup tidak termasuk kata sandi atau token login.

## Hak akses
| Aksi | Admin | PM | Keuangan | Viewer |
|---|---|---|---|---|
| Melihat seluruh proyek | Ya | Ya | Ya | Ya |
| Membuat proyek | Ya | Ya | Tidak | Tidak |
| Edit RAB draf | Ya | Milik sendiri di cloud | Tidak | Tidak |
| Mengajukan RAB | Ya | Milik sendiri | Tidak | Tidak |
| Menyetujui/mengembalikan RAB | Ya | Tidak | Tidak | Tidak |
| Memperbarui progres | Ya | Milik sendiri | Tidak | Tidak |
| Mencatat/membatalkan realisasi | Ya | Tidak | Ya | Tidak |

Dalam mode demo, PM dapat mengedit seluruh contoh draf agar alur mudah dicoba. Di cloud, kepemilikan proyek diterapkan di server. Administrator boleh mengelola sekaligus menyetujui proyek: pemisahan pembuat/penyetuju secara ketat belum diterapkan.

## Perhitungan
1. Jumlah baris = volume × harga satuan, dibulatkan per baris ke rupiah terdekat.
2. Diskon = subtotal × persentase diskon, dibulatkan.
3. Dasar biaya = subtotal − diskon.
4. Pajak = dasar biaya × persentase pajak, dibulatkan.
5. Cadangan = dasar biaya × persentase cadangan, dibulatkan.
6. Total RAB = dasar biaya + pajak + cadangan.
7. Realisasi = jumlah transaksi yang tidak dibatalkan. Nominal diinput termasuk pajak.
8. Sisa = total RAB − realisasi. Nilai negatif menunjukkan kelebihan anggaran.

Progres pekerjaan diisi manual dan berbeda dari persentase penggunaan anggaran. Pajak default nol dan harus disesuaikan oleh perusahaan; aplikasi tidak menentukan kewajiban/tarif pajak. Cadangan belum dialokasikan per komponen. Jika revisi belum disetujui, dashboard memakai snapshot anggaran disetujui sebelumnya sebagai baseline; tabel detail tetap memperlihatkan RAB revisi saat ini.

## Supabase | akun dan database bersama
Mode default lokal belum sinkron antarperangkat. Untuk internal perusahaan gunakan mode supabase berikut.

1. Buat proyek Supabase untuk RAB Cerdas.
2. Buka SQL Editor. Jalankan seluruh file supabase/schema.sql. Tabel memiliki prefix rabin_ sehingga tidak memakai tabel aplikasi lain.
3. Authentication > Users > Add user: buat akun admin dengan email perusahaan dan password Anda. Konfirmasi email sesuai pengaturan proyek. Jangan membuka signup umum untuk aplikasi internal ini.
4. Edit email pada supabase/akun.sql, lalu jalankan untuk memberi akun tersebut peran admin.
5. Buat pegawai lainnya di Authentication > Users, lalu gunakan contoh insert di akun.sql untuk role pm, finance atau viewer. Tidak ada pengaturan role melalui formulir publik.
6. Buka pengaturan API proyek. Salin Project URL dan publishable key (atau anon key). JANGAN memakai secret key atau service_role pada frontend.
7. Edit config.js:

```js
window.RAB_CONFIG = {
  mode: 'supabase',
  company: 'Nama Perusahaan Anda',
  supabaseUrl: 'https://PROJECT_REF.supabase.co',
  publishableKey: 'ISI_PUBLISHABLE_KEY'
};
```

8. Upload config.js dan file frontend ke GitHub Pages. Tidak perlu mengunggah schema SQL untuk menjalankan halaman, tetapi simpan SQL sebagai dokumentasi instalasi.
9. Login dengan akun yang dibuat pada langkah 3. Proyek cloud dimulai kosong; data demo tidak otomatis dipindahkan.
10. Buat proyek sebagai admin/PM, isi komponen RAB, ajukan, setujui sebagai admin, kemudian catat pengeluaran sebagai keuangan.
11. Setiap akun aktif dapat melihat proyek perusahaan. PM mengubah hanya proyek yang dibuatnya. Keuangan hanya mengubah realisasi pada RAB disetujui. Viewer hanya membaca.
12. Klik Perbarui data untuk melihat perubahan pegawai lain. Ini sinkronisasi melalui database saat dimuat/disimpan, bukan realtime otomatis.

Sesi cloud disimpan dalam sessionStorage pada tab yang digunakan; token diperbarui ketika diperlukan. Tabel tidak mengizinkan penulisan langsung dari browser. Penulisan melalui RPC dengan pemeriksaan peran, status, data transaksi dan nomor versi. Jika pengguna lain lebih dulu menyimpan, perubahan lama ditolak; klik Perbarui data dan ulangi perubahan.

## Mengatur perusahaan
Ubah company dalam config.js. Untuk mengubah nama/peran pegawai cloud, gunakan rabin_profiles melalui Supabase SQL Editor/Table Editor sebagai pemilik proyek. Untuk menonaktifkan pegawai: set active=false. Jangan memasukkan data ke tabel melalui akun yang tidak berwenang.

## Panduan mencoba alur
1. Masuk sebagai PM. Buat proyek baru dan tambahkan rincian RAB, diskon/pajak/cadangan.
2. Ajukan persetujuan. RAB terkunci dalam status menunggu.
3. Keluar lalu masuk sebagai admin. Persetujuan > Detail > Setujui RAB.
4. Keluar lalu masuk sebagai keuangan. Realisasi Biaya > Catat pengeluaran.
5. Masuk sebagai PM/admin, perbarui progres pelaksanaan. Lihat realisasi dibanding RAB.
6. Jika anggaran berubah, buat revisi. Catatan pengeluaran tetap tersimpan dan transaksi baru menunggu RAB disetujui lagi.
7. Export CSV atau cetak laporan pada menu Laporan. Rincian proyek dicetak sesuai tab aktif.

## Lingkup dan batasan
- Paket ini menyediakan frontend dan SQL backend siap konfigurasi, belum dikaitkan dengan akun Supabase Anda.
- Mode lokal adalah demonstrasi, bukan autentikasi/otorisasi yang aman; browser dapat mengubah data lokal.
- Mode cloud dirancang untuk SATU perusahaan dalam satu proyek Supabase, bukan SaaS multi-tenant.
- Belum ada upload lampiran bukti (gunakan nomor referensi), notifikasi email, transaksi komitmen/PO, termin tagihan, cashflow berjadwal, multi-currency, progress berbobot pekerjaan, WBS bertingkat, manajemen user dalam aplikasi atau tanda tangan digital.
- Export CSV, bukan XLSX. Simpan PDF melalui print browser. Backup JSON tersedia untuk export, belum ada restore/import dalam aplikasi.
- Riwayat perubahan cloud ditulis server, tetapi bukan audit ledger independen yang tahan perubahan oleh pemilik database.
- Sistem ini membantu monitoring anggaran; tidak mengklaim sertifikasi atau kepatuhan pada standar akuntansi/konstruksi tertentu.

## Verifikasi paket
Pengujian logika dan DOM dilakukan: login salah/benar, enam menu, empat tab detail, rumus/pembulatan, penambahan komponen, pengajuan PM, penolakan aksi persetujuan PM, persetujuan admin, pencatatan/pembatalan realisasi, revisi dan pembatasan viewer. Sintaks JavaScript serta sintaks SQL/PLpgSQL diperiksa dengan parser.
Koneksi Supabase dan kebijakan pada server cloud belum diuji pada proyek aktif. Pemeriksaan visual browser desktop/mobile belum dijalankan. Uji keempat role pada proyek Supabase sebelum memasukkan data perusahaan.

## Referensi integrasi
- https://supabase.com/docs/guides/api
- https://supabase.com/docs/guides/auth
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/getting-started/api-keys
