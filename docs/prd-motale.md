<!-- prd-progress
role: co-maker (metadata, background, success-metrics); executor (sisanya)
pace: normal
prd-language: Bahasa Indonesia (istilah teknis English)
sections:
  metadata: done
  background: done
  success-metrics: done
  documentation: done
  timeline: done
  scope: done
  discussions: done
  competitive-analysis: done
  product-requirement: done
  acceptance-criteria: done
  event-tracker: done
  test-cases: done
gaps:
- Epic link
- QA owner
- Sumber studi literatur
- Target motivasi bermain
- Lama periode uji coba
-->
<!-- Format rules for scripts/build_docx.py:
  - "# " is the project name. "## " is a section. "### " is a sub-heading.
  - In tables, a cell containing only ^ merges into the cell above.
  - Use <br> for a line break inside a table cell.
  - HTML comments (like this one) are not exported.
  - Status values: todo, in-progress, done, skipped. -->

# Motale (Puffy Pond)

Disclaimer: filled by AI in Executor role. Every item marked (*) is a prediction. Validate and check each one before sharing or acting on this PRD.

| | |
|---|---|
| **Target release** | November 2026 (sekitar 17 Nov 2026, 2 minggu dari 3 Nov 2026) |
| **Epic** | [TBD: link epic] |
| **Document status** | Draft |
| **Document owner** | @Rizki Hidayatul Laeli |
| **Designer** | @Adri Maulana Putra, @Graceilla Natasya |
| **Tech lead** | @Filbert Naldo Wijaya |
| **Technical writers** | @Rizki Hidayatul Laeli |
| **QA** | [TBD: QA] |

## Background

### What is the background that initiates this project?
Anak dengan cerebral palsy (CP) perlu latihan motorik anggota gerak atas secara rutin, termasuk di rumah. Dari riset, tim menemukan dua hal: latihan itu terasa membosankan dan repetitif sehingga anak kurang termotivasi, dan orang tua serta terapis sulit memantau perkembangan gerak anak di luar sesi terapi. Motale menjawab keduanya lewat drawing game yang dikendalikan gerakan tangan di depan kamera iPad, untuk anak usia 10–12 tahun dengan CP (MACS I–II).

### What are the problems? Has the problem been verified?
The problems are:
- **Latihan membosankan:** latihan motorik anggota gerak atas itu repetitif, jadi anak CP usia 10–12 tahun kurang termotivasi latihan di rumah.
- **Progres tidak terlihat:** orang tua tidak tahu perkembangan gerak anak di antara sesi terapi, jadi sulit melaporkan kondisi anak ke terapis.
- **Gerakan kurang variatif:** latihan di rumah jarang melatih gerakan dua tangan sekaligus (bilateral) dan gerakan dengan jangkauan luas.
- **Kurang stimulus:** anak lebih mau bergerak kalau ada musik ceria dan visual yang cerah dan kontras, tapi latihan biasa tidak punya keduanya.

What we know so far: keempat masalah di atas muncul dari wawancara dengan 2 dokter rehabilitasi, 2 terapis, dan 3 orang tua anak CP, observasi langsung di acara World Cerebral Palsy Day 2026, serta studi literatur [TBD: judul atau link jurnal].

What we have not known:
- Apakah menggambar dengan gerakan tangan bisa membuat anak latihan lebih lama dibanding latihan biasa.
- Apakah orang tua benar-benar membuka report secara rutin.

### What are the objectives?
- Anak mau latihan gerak anggota gerak atas lebih sering dan lebih lama karena aktivitasnya terasa seperti bermain.
- Anak melakukan lebih banyak gerakan bilateral dan gerakan dengan jangkauan luas selama bermain.
- Orang tua bisa melihat dan memahami perkembangan gerak anak di antara sesi terapi.
- Orang tua bisa membawa data report ke terapis sebagai bahan diskusi.

## Success Metrics

| Objective | Goal | Metric |
|---|---|---|
| Anak mau latihan lebih sering dan lebih lama | Durasi bermain | Rata-rata detik di halaman Canvas per sesi (dari sidecar). Target: ≥ 10 menit per sesi |
| ^ | Motivasi bermain | Anak lanjut main tanpa disuruh, dari observasi tim atau laporan orang tua. Target: [TBD: berapa dari N anak] |
| Anak melakukan lebih banyak gerakan bilateral dan jangkauan luas | Jangkauan gerak | Luas heatmap yang terisi dibagi luas kanvas per sesi. Target: ≥ 50% |
| ^ | Progres level | Template level Medium terbuka (unlock) dalam periode uji coba [TBD: lama periode] |
| Orang tua bisa melihat dan memahami perkembangan gerak anak | Pemahaman report | Orang tua bisa menjelaskan Highest ROM, heatmap, dan hand dominance tanpa dibantu. Target: ≥ 2 dari 3 orang tua |
| ^ | Penggunaan report | Orang tua membuka halaman Report minimal 1 kali per minggu, dari laporan orang tua saat follow-up |
| Orang tua bisa membawa data report ke terapis | Report dibawa ke terapis | Orang tua menunjukkan report ke terapis minimal 1 kali selama periode uji coba |
| ^ | Report berguna untuk klinis | Dokter rehab atau terapis menyebut minimal 1 metric di report yang bisa dipakai untuk evaluasi |

## Documentation

| Document | Link |
|---|---|
| Deck "Motale for Expert" (Little Crew, Nov 2026) | File PDF `deck_c7_for expert.pdf`, simpan di folder tim (*) |
| Tabel fitur dan acceptance criteria per epic | `PuffyPond2/docs/PuffyPond_PRD.xlsx` (*) |
| README aplikasi (cara menjalankan, alur halaman, kontrol) | `PuffyPond2/README.md` (*) |
| Rencana app flow update (1 Nov 2026) | `PuffyPond2/docs/superpowers/plans/2026-11-01-app-flow-update.md` (*) |
| Repository code PuffyPond2 (Swift, Xcode 26) | Link repo Git, diisi oleh @tech-lead (*) |
| Rangkuman wawancara 2 dokter rehab, 2 terapis, 3 orang tua | Dokumen rangkuman wawancara, dibuat oleh @product-owner (*) |
| Catatan observasi World Cerebral Palsy Day 2026 | Dokumen catatan observasi, dibuat oleh @product-owner (*) |
| Studi literatur gamifikasi terapi motorik anak CP | Daftar jurnal yang sudah dibaca tim, dikumpulkan oleh @product-owner (*) |
| Desain UI (Home, Canvas, Gallery, Report) | File Figma, dibagikan oleh @designer (*) |

## Timeline

| Milestones | Finished by |
|---|---|
| **Finalize VPC** | 4 Nov 2026 (*) |
| **Solution Concept** | 5 Nov 2026 (*) |
| **Wireframe** | 6 Nov 2026 (*) |
| **Lo-Fi** | 9 Nov 2026 (*) |
| **Hi-Fi** | 11 Nov 2026 (*) |
| **1st Prototype** | 14 Nov 2026 (*) |
| **Uji coba dengan anak, orang tua, dan terapis** | 16 Nov 2026 (*) |
| **Release / Apple review** | 17 Nov 2026 (*) |

## Scope

- Interface: iPad (landscape, utama) dan Mac, memakai kamera depan (*)
- Language: UI dalam Bahasa Inggris untuk v1 (*)
- Country to launch: Indonesia (*)
- Constraint lain: semua data tersimpan di perangkat, tanpa jaringan dan tanpa akun; angka gerak adalah estimasi kamera 2D, bukan pengukuran klinis (*)

In Scope for v1 (MVP):
- Menggambar dengan gerakan tangan: fist untuk melukis, open hand untuk bergerak, dua tangan bisa melukis bersamaan (masalah: latihan membosankan, gerakan kurang variatif) (*)
- Ganti warna dan tool dengan menggosok paint pot dan tool bubble di tepi kanvas, supaya anak menjangkau ke samping (masalah: gerakan kurang variatif) (*)
- Template bertingkat Easy, Medium, Hard dengan progressive unlock dan Daily Quest (masalah: latihan membosankan) (*)
- Musik ceria dan sound feedback yang merespons gerakan (masalah: kurang stimulus) (*)
- Galeri museum 3D dengan navigasi gerakan paddle, plus galeri 2D (masalah: latihan membosankan) (*)
- Report harian untuk orang tua: Highest ROM, heatmap, hand dominance (masalah: progres tidak terlihat) (*)

Out of Scope for v1:
- Audio yang merespons lukisan di galeri: butuh desain suara baru, belum ada di code, tidak menguji hipotesis inti (*)
- Mengatur posisi bingkai di galeri: butuh mode edit 3D baru; urutan otomatis sudah cukup untuk v1 (*)
- Akun, cloud sync, dan berbagi report online: menambah risiko privasi data anak dan butuh backend (*)
- Dashboard khusus terapis: v1 cukup lewat orang tua yang menunjukkan report di iPad (*)
- Pengukuran klinis tervalidasi: butuh studi validasi dengan alat ukur standar (*)

Core Hypothesis: Kami percaya anak CP usia 10–12 tahun (MACS I–II) akan latihan gerak anggota gerak atas lebih lama jika latihannya berupa menggambar dengan tangan di depan kamera yang diiringi musik, dan kami akan tahu saat rata-rata durasi di halaman Canvas mencapai ≥ 10 menit per sesi. (*)

## Discussions (Optional)

| Question | Answer | Date Answered |
|---|---|---|
| Berapa lama periode uji coba dengan anak dan orang tua? | Open (*) | |
| Siapa yang menjadi QA untuk v1? | Open (*) | |
| Apakah UI perlu Bahasa Indonesia untuk orang tua di v1? | Open (*) | |
| Berapa target jumlah anak yang ikut uji coba? | Open (*) | |
| Apakah sudut ROM dari kamera perlu dibandingkan dengan goniometer terapis? | Open (*) | |

## Competitive Analysis (Optional)

| Competitor Name | Observation | Notes |
|---|---|---|
| Home exercise program dari terapis (lembar latihan atau video) | Predicted: gerakan diulang dengan hitungan, tanpa umpan balik dan tanpa catatan progres; anak cepat bosan, may be out of date (*) | Motale mengganti hitungan repetisi dengan aktivitas menggambar dan mencatat progres otomatis (*) |
| Game motion-sensing di konsol rumah | Predicted: seru dan memakai gerakan seluruh tubuh, tapi butuh perangkat tambahan dan tidak dirancang untuk kemampuan motorik anak CP, may be out of date (*) | Motale cukup memakai kamera iPad dan level template disesuaikan bertahap (*) |
| Aplikasi rehabilitasi berbasis game untuk tangan | Predicted: banyak yang berbasis sentuhan layar atau alat khusus, sehingga gerakan bahu dan jangkauan luas kurang terlatih, may be out of date (*) | Motale fokus ke gerakan bilateral dan jangkauan luas di udara tanpa menyentuh layar (*) |
| Menggambar biasa dengan kertas dan krayon | Predicted: disukai anak, tapi gerakannya kecil (tangan dan pergelangan) dan tidak ada data untuk orang tua, may be out of date (*) | Kanvas lebar dan pot di tepi memaksa gerakan lengan yang luas, dan report mengisi kekosongan data (*) |

## Product Requirement

**App Overview:**
Motale (nama app di code: Puffy Pond) adalah drawing game di iPad untuk anak usia 10–12 tahun dengan cerebral palsy (MACS I–II). Anak melukis di udara dengan kepalan tangan di depan kamera, mengganti warna dan kuas dengan gerakan menggosok, lalu memajang lukisannya di museum 3D. Selama bermain, app mencatat gerakan lengan dan menampilkannya sebagai report harian untuk orang tua. (*)

**User Story**
- Sebagai anak, aku ingin menggerakkan tangan di depan kamera untuk menggambar di kanvas secara real-time sekaligus mengganti warna dan memilih kuas, sehingga aku bisa bebas bereksperimen menciptakan karya seni yang interaktif dan berwarna tanpa harus menyentuh layar iPad.
- Sebagai anak, aku ingin melihat kembali hasil gambarku di galeri/museum virtual, berinteraksi dengan gambar lewat suara yang merespons karyaku, serta mengatur posisi bingkai di dalam ruangan galeri, sehingga aku bisa menikmati pameran seniku sendiri secara imersif.
- Sebagai orang tua, aku ingin bisa melihat report gerakan anakku, sehingga aku tahu kondisi anakku dari hasil mainnya.

**Feature List vs Importance (MVP)**

| User Flow | User Story | Requirement | Importance |
|---|---|---|---|
| **EPIC 1: Hand Drawing** | **Feature 1.1: Mulai menggambar dan pilih mode**<br>Sebagai anak, aku ingin memilih Freeform atau Template sehingga aku bisa menggambar bebas atau mengikuti panduan. | The system should menampilkan Home (Start drawing, View gallery, Report) dan halaman pilihan Freeform atau Templates. (*) | P1 - MVP (*) |
| ^ | **Feature 1.2: Pilih template (Daily Quest dan progressive unlock)**<br>Sebagai anak, aku ingin memilih template dari mudah ke sulit sehingga tantangannya naik bertahap. | The system should menampilkan Daily Quest dan 9 template Easy, Medium, Hard, dan membuka template berikutnya setelah lukisan template sebelumnya tersimpan. (*) | P1 - MVP (*) |
| ^ | **Feature 1.3: Cek jarak (Get Ready)**<br>Sebagai anak, aku ingin tahu harus berdiri di mana sehingga kamera bisa membaca kedua tanganku. | The system should mendeteksi lebar bahu 13–22% lebar gambar (sekitar 1 m), menahan 1,5 detik, lalu membuka kanvas otomatis, dengan tombol Skip. (*) | P1 - MVP (*) |
| ^ | **Feature 1.4: Melukis dengan kepalan tangan secara real-time**<br>Sebagai anak, aku ingin melukis dengan mengepalkan tangan sehingga aku tidak perlu menyentuh layar. | The system should melukis saat fist, berhenti saat open hand, mendukung dua tangan sekaligus, dan menampilkan cat basah tersimulasi. (*) | P1 - MVP (*) |
| ^ | **Feature 1.5: Ganti warna dengan menggosok paint pot**<br>Sebagai anak, aku ingin mengganti warna dengan gerakan tangan sehingga lukisanku berwarna-warni. | The system should mengganti warna karakter saat ring pada paint pot di sisi kanan terisi penuh karena digosok. (*) | P1 - MVP (*) |
| ^ | **Feature 1.6: Pilih tool dengan menggosok tool bubble**<br>Sebagai anak, aku ingin memilih kuas berbeda sehingga aku bisa mencoba tekstur cat yang beragam. | The system should menyediakan 5 tool (Thick oil, Liquid oil, Brush, Eraser, Blender) di sisi kiri dan menggantinya saat bubble digosok sampai penuh. (*) | P1 - MVP (*) |
| ^ | **Feature 1.7: Musik dan sound feedback**<br>Sebagai anak, aku ingin mendengar musik yang ikut ramai saat aku bergerak sehingga aku semangat terus bergerak. | The system should memutar musik 118 BPM yang makin ramai saat gerakan bertambah, bunyi blip mengikuti tinggi dan posisi tangan, dan tombol musik on/off. (*) | P1 - MVP (*) |
| ^ | **Feature 1.8: Kontrol kanvas dan Save image**<br>Sebagai anak, aku ingin menyimpan lukisanku sehingga aku bisa melihatnya lagi. | The system should menampilkan Save image setelah ada cat, konfirmasi saat keluar tanpa menyimpan, dan tombol clear, musik, camera preview, bantuan. (*) | P1 - MVP (*) |
| ^ | **Feature 1.9: Review dan interaksi dengan lukisan**<br>Sebagai anak, aku ingin menarik dan meregangkan lukisanku sehingga aku bisa bermain dengan hasil karyaku. | The system should menampilkan lukisan di lembaran elastis yang bisa ditarik (1 fist), diregang dan diputar (2 fist), diberi riak (open hand), dengan tombol dwell Save to gallery dan Keep drawing. (*) | P2 (*) |
| ^ | **Feature 1.10: Menggambar tanpa kamera**<br>Sebagai anak, aku ingin tetap bisa menggambar dengan sentuhan sehingga aku bisa main walau kamera tidak tersedia. | The system should mendukung semua langkah lewat sentuhan atau mouse, dan menampilkan pesan saat akses kamera ditolak. (*) | P2 (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Feature 2.1: Menjelajah galeri 3D dengan gerakan paddle**<br>Sebagai anak, aku ingin berjalan di museum dengan mengayun tangan sehingga melihat karyaku terasa seperti pameran. | The system should memajang lukisan di museum 3D dan berpindah lukisan saat open hand diayun ke bawah ≥ 25% tinggi layar dalam 0,8 detik (kanan = maju, kiri = mundur). (*) | P1 - MVP (*) |
| ^ | **Feature 2.2: Galeri 2D**<br>Sebagai anak, aku ingin melihat semua lukisanku dalam grid sehingga aku cepat menemukan satu lukisan. | The system should menampilkan grid thumbnail per hari dan membuka lukisan yang dipilih di galeri 3D. (*) | P2 (*) |
| ^ | **Feature 2.3: Menurunkan lukisan**<br>Sebagai anak, aku ingin menghapus lukisan yang tidak aku suka sehingga galeri berisi karya favoritku. | The system should menghapus PNG dan sidecar setelah konfirmasi "Take this painting down?". (*) | P2 (*) |
| ^ | **Feature 2.4: Audio yang merespons karya**<br>Sebagai anak, aku ingin mendengar suara dari lukisanku sehingga pameranku terasa hidup. | The system should memutar suara yang dibuat dari warna atau tool lukisan saat anak berdiri di depannya. (*) | P3 (*) |
| ^ | **Feature 2.5: Mengatur layout bingkai**<br>Sebagai anak, aku ingin memindahkan bingkai di ruangan sehingga aku bisa mengatur pameranku sendiri. | The system should menyediakan arrange mode untuk memindahkan bingkai dengan fist dan menyimpan posisinya. (*) | P3 (*) |
| **EPIC 3: Movement Report** | **Feature 3.1: Membuka Report dan memilih hari**<br>Sebagai orang tua, aku ingin memilih tanggal di kalender sehingga aku bisa melihat report hari tertentu. | The system should menampilkan kalender bulanan dengan titik untuk hari yang ada lukisan dan bintang untuk Daily Quest. (*) | P1 - MVP (*) |
| ^ | **Feature 3.2: Melihat lukisan per hari**<br>Sebagai orang tua, aku ingin melihat lukisan anak hari itu sehingga aku tahu apa yang ia kerjakan. | The system should menampilkan deretan lukisan hari terpilih dengan nama template dan jam. (*) | P2 (*) |
| ^ | **Feature 3.3: Statistik ROM**<br>Sebagai orang tua, aku ingin melihat seberapa tinggi anak mengangkat lengannya sehingga aku tahu perkembangan geraknya. | The system should menampilkan Highest ROM bahu kiri dan kanan, siku paling lurus, tinggi tangan di atas bahu, reach area, grip cycles, dan flag condong. (*) | P1 - MVP (*) |
| ^ | **Feature 3.4: Heatmap dan hand dominance**<br>Sebagai orang tua, aku ingin melihat area yang dilukis dan tangan mana yang lebih banyak dipakai sehingga aku tahu apakah kedua tangan terlatih. | The system should menampilkan heatmap 32 × 20 dan porsi waktu melukis tangan kiri dan kanan. (*) | P1 - MVP (*) |
| ^ | **Feature 3.5: Perekaman data gerak**<br>Sebagai orang tua, aku ingin data anakku tersimpan aman di perangkat sehingga privasinya terjaga. | The system should merekam statistik hanya di halaman Canvas dari kamera, dan menyimpannya sebagai JSON sidecar di perangkat tanpa jaringan. (*) | P1 - MVP (*) |

## Acceptance Criteria

| User Flow | User Story | Screen | Acceptance Criteria | Positive Flow |
|---|---|---|---|---|
| **EPIC 1: Hand Drawing** | **Feature 1.1: Mulai menggambar dan pilih mode** | Home, Mode Picker | • Home menampilkan tombol Start drawing, View gallery, dan Report.<br>• Start drawing membuka "What do you want to paint?" dengan Freeform dan Choose template.<br>• Freeform membuka Get Ready dengan kanvas kosong.<br>• Halaman pilihan mode punya tombol Home. (*) | POSITIVE:<br>1. Anak tap Start drawing.<br>2. Anak pilih Freeform.<br>3. Halaman Get Ready terbuka. (*) |
| ^ | ^ | Mode Picker | ^ | NEGATIVE FLOW:<br>1. Anak tap Home di halaman pilihan mode.<br>2. App kembali ke Home tanpa membuka kanvas. (*) |
| ^ | **Feature 1.2: Pilih template (Daily Quest dan progressive unlock)** | Templates | • Daily Quest tampil paling atas, diacak sekali per hari, tidak sama dengan kemarin.<br>• 9 template: Easy (fish, duck, sun), Medium (turtle, snail, cat), Hard (octopus, seahorse, butterfly).<br>• Template terbuka setelah lukisan template sebelumnya tersimpan.<br>• Template terkunci menampilkan "Save a painting of <template sebelumnya> to unlock".<br>• Menghapus lukisan bisa mengunci template lagi.<br>• Ada tombol Back dan Home. (*) | POSITIVE:<br>1. Anak buka Templates.<br>2. Anak tap template yang terbuka (Fish).<br>3. Get Ready terbuka dengan template Fish. (*) |
| ^ | ^ | Templates | ^ | NEGATIVE FLOW:<br>1. Anak tap template yang terkunci (Turtle).<br>2. Template tidak terbuka dan teks syarat unlock tetap tampil. (*) |
| ^ | **Feature 1.3: Cek jarak (Get Ready)** | Get Ready | • Menampilkan outline skeleton dan lengan yang terbaca kamera.<br>• Posisi pas jika lebar bahu 13–22% lebar gambar dan badan di tengah (±18%).<br>• Diam 1,5 detik sampai ring penuh, lalu kanvas terbuka otomatis.<br>• Deteksi hilang < 0,3 detik tidak me-reset hitungan.<br>• Tombol Skip selalu ada. (*) | POSITIVE:<br>1. Anak mundur sampai bahu pas di outline.<br>2. Ring terisi 1,5 detik.<br>3. Kanvas terbuka otomatis. (*) |
| ^ | ^ | Get Ready | ^ | NEGATIVE FLOW:<br>1. Anak berdiri terlalu dekat (bahu > 22% lebar gambar).<br>2. Ring tidak terisi dan anak diminta mundur; anak bisa tap Skip. (*) |
| ^ | **Feature 1.4: Melukis dengan kepalan tangan secara real-time** | Canvas | • Setiap tangan punya karakter cat yang mengikuti tangan secara real-time.<br>• Open hand: karakter bergerak tanpa cat.<br>• Fist: karakter melukis; fist yang longgar tetap melukis sebentar.<br>• Dua tangan bisa melukis bersamaan dengan warna dan tool masing-masing.<br>• Kanvas lebar dan pot di tepi mendorong gerakan lengan yang luas.<br>• Template tampil sebagai garis titik-titik. (*) | POSITIVE:<br>1. Anak menggerakkan open hand; karakter ikut.<br>2. Anak mengepal dan mengayun lengan; cat muncul.<br>3. Anak membuka tangan; berhenti melukis. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Tangan anak keluar dari pandangan kamera saat melukis.<br>2. Goresan berhenti dan karakter berhenti; goresan lanjut saat tangan terlihat lagi. (*) |
| ^ | **Feature 1.5: Ganti warna dengan menggosok paint pot** | Canvas | • Paint pot berjajar di sisi kanan kanvas.<br>• Menggosok bolak-balik mengisi ring; makin cepat makin cepat terisi.<br>• Ring penuh mengganti warna, dengan suara dan animasi di HUD.<br>• Warna cerah dan kontras.<br>• Chip HUD menampilkan warna dan tool tiap tangan. (*) | POSITIVE:<br>1. Anak membawa karakter ke pot.<br>2. Anak menggosok sampai ring penuh.<br>3. Karakter melukis dengan warna baru. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Anak berhenti menggosok sebelum ring penuh.<br>2. Warna tidak berganti dan ring kosong lagi. (*) |
| ^ | **Feature 1.6: Pilih tool dengan menggosok tool bubble** | Canvas | • Tool bubble berjajar di sisi kiri dengan 5 karakter.<br>• Thick oil (Snail), Liquid oil (Jellyfish), Brush (Octopus), Eraser (Starfish), Blender (Sponge).<br>• Ring penuh mengganti tool dengan suara swap.<br>• Tangan kiri dan kanan bisa memakai tool berbeda. (*) | POSITIVE:<br>1. Anak membawa karakter ke bubble Jellyfish.<br>2. Anak menggosok sampai penuh.<br>3. Goresan berikutnya memakai Liquid oil. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Anak menggosok bubble tool yang sedang dipakai.<br>2. Tool tidak berubah dan tidak ada suara swap. (*) |
| ^ | **Feature 1.7: Musik dan sound feedback** | Canvas | • Musik toy-pop 118 BPM diputar di kanvas.<br>• Lapisan musik makin ramai saat gerakan bertambah.<br>• Bunyi blip: nada mengikuti tinggi tangan, pan kiri/kanan mengikuti posisi tangan.<br>• Setiap aksi punya sound effect (ganti warna, ganti tool, selesai).<br>• Karakter bergoyang mengikuti beat.<br>• Tombol speaker menyalakan dan mematikan musik. (*) | POSITIVE:<br>1. Kanvas terbuka, musik mulai.<br>2. Anak mengayun lengan; musik makin ramai dan blip berbunyi.<br>3. Anak ganti warna; terdengar sound effect. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Orang tua tap tombol speaker.<br>2. Musik berhenti, ikon berubah menjadi speaker coret, dan melukis tetap berjalan. (*) |
| ^ | **Feature 1.8: Kontrol kanvas dan Save image** | Canvas | • Tombol: Home, eraser sentuh (iPad), musik, camera preview, bantuan, clear.<br>• Save image muncul hanya setelah ada cat.<br>• Save image memotret kanvas tanpa karakter, pot, atau garis template, lalu membuka Review.<br>• Home saat belum disimpan memunculkan "Leave without saving?".<br>• Clear menghapus cat, goresan, dan garis template. (*) | POSITIVE:<br>1. Anak selesai melukis.<br>2. Tombol Save image muncul.<br>3. Anak tap Save image; Review terbuka. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Anak tap Home sebelum menyimpan.<br>2. Muncul "Leave without saving?"; Keep drawing kembali ke kanvas tanpa kehilangan cat. (*) |
| ^ | **Feature 1.9: Review dan interaksi dengan lukisan** | Review | • Lukisan tampil di lembaran elastis.<br>• 1 fist menarik, 2 fist meregang dan memutar (0,3×–3,5×), open hand membuat riak dengan suara splash.<br>• Lembaran kembali ke bentuk semula saat dilepas; gambar tersimpan tidak berubah.<br>• Tombol Keep drawing dan Save to gallery bisa di-tap atau dipilih dengan dwell open hand; hanya pemicu pertama dihitung. (*) | POSITIVE:<br>1. Anak meregangkan lembaran dengan 2 fist.<br>2. Anak menahan open hand di Save to gallery.<br>3. Lukisan tersimpan dan galeri 3D terbuka dengan sorakan. (*) |
| ^ | ^ | Review | ^ | NEGATIVE FLOW:<br>1. Anak memilih Keep drawing.<br>2. App kembali ke kanvas yang sama dan cat masih ada; tidak ada lukisan baru di galeri. (*) |
| ^ | **Feature 1.10: Menggambar tanpa kamera** | Semua halaman | • Semua langkah bisa lewat sentuhan atau mouse.<br>• Drag untuk melukis; drag melewati pot atau bubble untuk ganti warna atau tool.<br>• Hapus: tombol eraser di iPad, ⌥-drag atau klik kanan-drag di Mac.<br>• Lukisan dari sentuhan tidak punya data gerak. (*) | POSITIVE:<br>1. Anak tap Skip di Get Ready.<br>2. Anak drag jari untuk melukis.<br>3. Anak menyimpan; lukisan muncul di galeri. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Akses kamera ditolak.<br>2. Muncul "Camera access is off" dengan tombol Open Settings; anak tetap bisa melukis dengan sentuhan. (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Feature 2.1: Menjelajah galeri 3D dengan gerakan paddle** | 3D Gallery | • Galeri terbuka dari View gallery atau setelah Save to gallery.<br>• Lukisan dipajang dalam bingkai, terbaru di depan; karakter hewan berkunjung.<br>• Open hand diayun ke bawah ≥ 25% tinggi layar dalam 0,8 detik: kanan maju, kiri mundur; cooldown 0,6 detik.<br>• Tombol panah dan swipe juga berfungsi.<br>• Header menampilkan tanggal dan "n of N".<br>• Lukisan baru disambut sorakan dan confetti. (*) | POSITIVE:<br>1. Anak membuka galeri.<br>2. Anak mengayun open hand ke bawah di sisi kanan.<br>3. Kamera berjalan ke lukisan berikutnya. (*) |
| ^ | ^ | 3D Gallery | ^ | NEGATIVE FLOW:<br>1. Galeri belum berisi lukisan.<br>2. Muncul "No paintings yet" dengan tombol Start drawing. (*) |
| ^ | **Feature 2.2: Galeri 2D** | 2D Gallery | • View gallery in 2D membuka grid thumbnail per hari, terbaru di depan.<br>• Tap thumbnail membuka lukisan itu di galeri 3D.<br>• Tombol 3D kembali ke museum. (*) | POSITIVE:<br>1. Anak tap View gallery in 2D.<br>2. Anak tap satu lukisan.<br>3. Galeri 3D terbuka di lukisan itu. (*) |
| ^ | ^ | 2D Gallery | ^ | NEGATIVE FLOW:<br>1. Galeri 2D dibuka tanpa lukisan.<br>2. Muncul "No paintings yet" dengan tombol Start drawing. (*) |
| ^ | **Feature 2.3: Menurunkan lukisan** | 3D Gallery | • Tombol trash memunculkan "Take this painting down?".<br>• Konfirmasi menghapus PNG dan sidecar, lalu galeri memajang ulang lukisan.<br>• Menghapus bisa mengunci template lagi dan mengubah Report. (*) | POSITIVE:<br>1. Anak tap trash.<br>2. Anak pilih Take it down.<br>3. Lukisan hilang dari galeri. (*) |
| ^ | ^ | 3D Gallery | ^ | NEGATIVE FLOW:<br>1. Anak tap trash lalu menutup dialog.<br>2. Lukisan tetap ada. (*) |
| ^ | **Feature 2.4: Audio yang merespons karya** | 3D Gallery | • Saat anak berdiri di depan lukisan, suara dibuat dari warna atau tool lukisan itu.<br>• Gerakan tangan ke arah lukisan memicu respons audio.<br>• Belum ada di code (P3). (*) | POSITIVE:<br>1. Anak berjalan ke lukisan.<br>2. Musik lukisan diputar.<br>3. Anak mendorong open hand; suara bereaksi. (*) |
| ^ | ^ | 3D Gallery | ^ | NEGATIVE FLOW:<br>1. Musik dimatikan di pengaturan.<br>2. Galeri tidak memutar suara lukisan. (*) |
| ^ | **Feature 2.5: Mengatur layout bingkai** | 3D Gallery (arrange mode) | • Anak masuk arrange mode, memegang bingkai dengan fist, dan memindahkannya.<br>• Posisi tersimpan dan tetap sama saat galeri dibuka lagi.<br>• Belum ada di code (P3). (*) | POSITIVE:<br>1. Anak masuk arrange mode.<br>2. Anak memindahkan bingkai dengan fist.<br>3. Layout tetap setelah galeri dibuka lagi. (*) |
| ^ | ^ | 3D Gallery (arrange mode) | ^ | NEGATIVE FLOW:<br>1. Anak melepas bingkai di posisi yang sudah terisi.<br>2. Bingkai kembali ke posisi asal. (*) |
| **EPIC 3: Movement Report** | **Feature 3.1: Membuka Report dan memilih hari** | Home, Report | • Report terbuka dari tombol Report di Home.<br>• Kalender bulanan: titik untuk hari dengan lukisan, bintang untuk Daily Quest.<br>• Tap hari menampilkan detail di kanan.<br>• Tombol panah untuk pindah bulan. (*) | POSITIVE:<br>1. Orang tua tap Report.<br>2. Orang tua tap hari bertanda.<br>3. Lukisan dan statistik hari itu muncul. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. Orang tua tap hari tanpa lukisan.<br>2. Muncul "No drawing this day". (*) |
| ^ | **Feature 3.2: Melihat lukisan per hari** | Report | • Deretan lukisan hari itu, terbaru di depan.<br>• Setiap item: thumbnail, nama template atau freeform, dan jam.<br>• Thumbnail dimuat di background. (*) | POSITIVE:<br>1. Orang tua memilih hari.<br>2. Deretan lukisan tampil dengan template dan jam. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. Lukisan hari itu sudah dihapus dari galeri.<br>2. Lukisan tidak tampil lagi di deretan. (*) |
| ^ | **Feature 3.3: Statistik ROM** | Report | • Highest ROM abduksi bahu kiri dan kanan dalam derajat.<br>• Siku paling lurus, tinggi tangan di atas bahu, reach area, grip cycles per lengan.<br>• Flag condong jika bahu miring > 15°.<br>• Nilai harian adalah maksimum (ROM) atau jumlah (waktu, grip) dari semua sesi.<br>• Kiri/kanan adalah sisi tubuh anak.<br>• Catatan "Camera estimates, not a clinical measurement." selalu tampil. (*) | POSITIVE:<br>1. Orang tua memilih hari anak melukis dengan kamera.<br>2. Kartu Highest ROM menampilkan sudut kiri dan kanan.<br>3. Orang tua membaca statistik lainnya. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. Orang tua memilih hari yang lukisannya dibuat dengan sentuhan.<br>2. Muncul "No movement data — these were drawn by touch or before tracking existed." (*) |
| ^ | **Feature 3.4: Heatmap dan hand dominance** | Report | • Heatmap grid 32 × 20: transparan jika kosong, kuning ke merah makin lama dilukis.<br>• Hand dominance: Left % dan Right %, total 100%. (*) | POSITIVE:<br>1. Orang tua memilih hari.<br>2. Heatmap dan bar hand dominance tampil. (*) |
| ^ | ^ | Report | ^ | NEGATIVE FLOW:<br>1. Hari itu tidak ada waktu melukis dengan fist.<br>2. Muncul "No painting time recorded". (*) |
| ^ | **Feature 3.5: Perekaman data gerak** | Canvas, penyimpanan | • Statistik direkam hanya di Canvas, dari tangan dan tubuh yang terbaca kamera.<br>• Sendi dipakai jika confidence ≥ 0,5; nilai diambil dari median 0,3 detik.<br>• Disimpan sebagai JSON sidecar di Application Support/Gallery/.<br>• Tanpa jaringan dan tanpa akun. (*) | POSITIVE:<br>1. Anak melukis dengan kamera dan menyimpan.<br>2. PNG dan JSON sidecar tersimpan.<br>3. Report menampilkan angka hari ini. (*) |
| ^ | ^ | Canvas | ^ | NEGATIVE FLOW:<br>1. Kamera kehilangan tubuh anak selama satu frame.<br>2. Frame itu tidak membuat rekor ROM palsu karena nilai diambil dari median. (*) |

## Event Tracker (Optional)

Catatan: v1 tidak memakai jaringan, jadi event dicatat ke log lokal di perangkat dan diambil saat uji coba. Pencatatan event ini belum ada di code. (*)

| User Flow | User Story | Event Tracker |
|---|---|---|
| **EPIC 1: Hand Drawing** | **Feature 1.1: Mulai menggambar dan pilih mode** | DR_Home_Page<br>DR_StartDrawing_Button<br>DR_Freeform_Button<br>DR_ChooseTemplate_Button (*) |
| ^ | **Feature 1.2: Pilih template** | DR_Templates_Page<br>DR_Template_Select (properti: template, level)<br>DR_DailyQuest_Select<br>DR_Template_Unlock (properti: template) (*) |
| ^ | **Feature 1.3: Cek jarak** | DR_GetReady_Page<br>DR_GetReady_Complete (properti: durasi)<br>DR_GetReady_Skip (*) |
| ^ | **Feature 1.4–1.7: Melukis, warna, tool, musik** | DR_Canvas_Page (properti: durasi sesi)<br>DR_Stroke_Start (properti: tangan)<br>DR_Color_Change<br>DR_Tool_Change (properti: tool)<br>DR_Music_Toggle (*) |
| ^ | **Feature 1.8–1.9: Save image dan Review** | DR_SaveImage_Button<br>DR_Review_Page<br>DR_SaveToGallery_Button<br>DR_KeepDrawing_Button<br>DR_LeaveWithoutSaving_Confirm (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Feature 2.1–2.3: Galeri 3D, 2D, hapus** | GL_Gallery3D_Page<br>GL_Paddle_Gesture (properti: arah)<br>GL_Gallery2D_Page<br>GL_Painting_Remove (*) |
| **EPIC 3: Movement Report** | **Feature 3.1–3.4: Report** | RP_Report_Page<br>RP_Day_Select (properti: tanggal, ada data gerak) (*) |

Metric yang tidak bisa dihitung dari event: motivasi bermain, pemahaman report, report dibawa ke terapis, dan report berguna untuk klinis. Keempatnya diambil dari observasi dan wawancara saat uji coba. (*)

## Test Case

| User Flow | Scenario | Test Steps | Expected Result |
|---|---|---|---|
| **EPIC 1: Hand Drawing** | **Scenario 1.1.1**: Mulai Freeform | 1. Buka app di iPad.<br>2. Tap Start drawing.<br>3. Tap Freeform. | - Halaman Get Ready terbuka dengan kanvas kosong. (*) |
| ^ | **Scenario 1.1.2**: Kembali ke Home dari pilihan mode | 1. Tap Start drawing.<br>2. Tap Home. | - Home tampil lagi. (*) |
| ^ | **Scenario 1.2.1**: Pilih template yang terbuka | 1. Siapkan galeri kosong.<br>2. Buka Templates.<br>3. Tap Fish. | - Get Ready terbuka; garis titik-titik Fish tampil di kanvas. (*) |
| ^ | **Scenario 1.2.2**: Template terkunci | 1. Siapkan galeri tanpa lukisan Sun.<br>2. Buka Templates.<br>3. Tap Turtle. | - Turtle tidak terbuka; teks "Save a painting of Sun to unlock" tampil. (*) |
| ^ | **Scenario 1.2.3**: Unlock lalu terkunci lagi | 1. Simpan lukisan dari template Sun.<br>2. Cek Turtle terbuka.<br>3. Hapus lukisan Sun di galeri.<br>4. Buka Templates lagi. | - Turtle terkunci lagi. (*) |
| ^ | **Scenario 1.3.1**: Jarak pas | 1. Pilih Freeform.<br>2. Berdiri sekitar 1 m di tengah kamera.<br>3. Diam 1,5 detik. | - Ring penuh dan kanvas terbuka otomatis. (*) |
| ^ | **Scenario 1.3.2**: Terlalu dekat | 1. Pilih Freeform.<br>2. Berdiri sekitar 40 cm dari kamera. | - Ring tidak terisi; tombol Skip tetap bisa dipakai. (*) |
| ^ | **Scenario 1.4.1**: Melukis dengan fist | 1. Buka kanvas.<br>2. Gerakkan open hand.<br>3. Kepalkan tangan dan ayun lengan.<br>4. Buka tangan. | - Karakter ikut tanpa cat saat open hand; cat muncul saat fist; berhenti saat tangan dibuka. (*) |
| ^ | **Scenario 1.4.2**: Dua tangan bersamaan | 1. Buka kanvas.<br>2. Kepalkan kedua tangan dan ayun bersamaan. | - Dua goresan muncul bersamaan dengan warna masing-masing tangan. (*) |
| ^ | **Scenario 1.4.3**: Tangan keluar kamera | 1. Melukis dengan fist.<br>2. Gerakkan tangan keluar dari pandangan kamera. | - Goresan berhenti; lanjut saat tangan terlihat lagi. (*) |
| ^ | **Scenario 1.5.1**: Ganti warna | 1. Bawa karakter ke pot di kanan.<br>2. Gosok sampai ring penuh. | - Warna karakter dan chip HUD berganti; ada suara. (*) |
| ^ | **Scenario 1.5.2**: Gosok tidak sampai penuh | 1. Gosok pot sebentar.<br>2. Berhenti sebelum ring penuh. | - Warna tetap; ring kosong lagi. (*) |
| ^ | **Scenario 1.6.1**: Ganti tool | 1. Bawa karakter ke bubble Jellyfish.<br>2. Gosok sampai penuh.<br>3. Melukis dengan fist. | - Goresan berupa Liquid oil yang transparan dan mengalir. (*) |
| ^ | **Scenario 1.6.2**: Gosok tool yang sama | 1. Pakai Brush (Octopus).<br>2. Gosok bubble Octopus. | - Tool tidak berubah; tidak ada suara swap. (*) |
| ^ | **Scenario 1.7.1**: Musik merespons gerakan | 1. Buka kanvas.<br>2. Diam 5 detik.<br>3. Ayun kedua lengan 10 detik. | - Musik makin ramai saat bergerak; blip berbunyi mengikuti tangan. (*) |
| ^ | **Scenario 1.7.2**: Matikan musik | 1. Buka kanvas.<br>2. Tap tombol speaker. | - Musik berhenti; ikon speaker coret; melukis tetap berjalan. (*) |
| ^ | **Scenario 1.8.1**: Save image | 1. Melukis satu goresan.<br>2. Tap Save image. | - Review terbuka; gambar tanpa karakter, pot, atau garis template. (*) |
| ^ | **Scenario 1.8.2**: Keluar tanpa menyimpan | 1. Melukis satu goresan.<br>2. Tap Home.<br>3. Pilih Keep drawing. | - Dialog "Leave without saving?" muncul; kembali ke kanvas dengan cat utuh. (*) |
| ^ | **Scenario 1.9.1**: Simpan ke galeri dengan dwell | 1. Dari Review, tahan open hand di Save to gallery sampai ring penuh. | - Lukisan tersimpan; galeri 3D terbuka di lukisan itu dengan sorakan. (*) |
| ^ | **Scenario 1.9.2**: Keep drawing | 1. Dari Review, tap Keep drawing. | - Kanvas yang sama terbuka; jumlah lukisan di galeri tidak bertambah. (*) |
| ^ | **Scenario 1.10.1**: Melukis dengan sentuhan | 1. Tap Skip di Get Ready.<br>2. Drag jari di kanvas.<br>3. Save image lalu Save to gallery. | - Lukisan tersimpan; Report hari itu menampilkan "No movement data". (*) |
| ^ | **Scenario 1.10.2**: Akses kamera ditolak | 1. Tolak izin kamera di Settings.<br>2. Buka kanvas. | - Muncul "Camera access is off" dengan Open Settings; drag jari tetap melukis. (*) |
| **EPIC 2: Virtual Museum / Gallery** | **Scenario 2.1.1**: Paddle maju dan mundur | 1. Siapkan 3 lukisan.<br>2. Buka galeri.<br>3. Ayun open hand ke bawah di sisi kanan.<br>4. Ayun di sisi kiri. | - Pindah ke lukisan berikutnya, lalu kembali; header "n of 3" berubah. (*) |
| ^ | **Scenario 2.1.2**: Galeri kosong | 1. Hapus semua lukisan.<br>2. Buka View gallery. | - Muncul "No paintings yet" dengan Start drawing. (*) |
| ^ | **Scenario 2.2.1**: Buka dari 2D | 1. Buka galeri 3D.<br>2. Tap View gallery in 2D.<br>3. Tap lukisan kedua. | - Galeri 3D terbuka di lukisan kedua. (*) |
| ^ | **Scenario 2.2.2**: Galeri 2D kosong | 1. Hapus semua lukisan.<br>2. Buka galeri 2D. | - Muncul "No paintings yet". (*) |
| ^ | **Scenario 2.3.1**: Hapus lukisan | 1. Buka galeri.<br>2. Tap trash.<br>3. Pilih Take it down. | - Lukisan hilang; file PNG dan sidecar terhapus. (*) |
| ^ | **Scenario 2.3.2**: Batal hapus | 1. Tap trash.<br>2. Tutup dialog. | - Lukisan tetap ada. (*) |
| ^ | **Scenario 2.4.1**: Audio lukisan (P3) | 1. Buka galeri.<br>2. Berdiri di depan lukisan. | - Suara dari lukisan diputar. (*) |
| ^ | **Scenario 2.5.1**: Pindah bingkai (P3) | 1. Masuk arrange mode.<br>2. Pindahkan bingkai dengan fist.<br>3. Tutup dan buka galeri lagi. | - Bingkai tetap di posisi baru. (*) |
| **EPIC 3: Movement Report** | **Scenario 3.1.1**: Pilih hari bertanda | 1. Siapkan lukisan hari ini.<br>2. Buka Report.<br>3. Tap hari ini. | - Titik tampil di tanggal; detail hari muncul di kanan. (*) |
| ^ | **Scenario 3.1.2**: Hari tanpa lukisan | 1. Buka Report.<br>2. Tap tanggal tanpa lukisan. | - Muncul "No drawing this day". (*) |
| ^ | **Scenario 3.1.3**: Bintang Daily Quest | 1. Simpan lukisan Daily Quest.<br>2. Buka Report. | - Tanggal hari ini bertanda bintang. (*) |
| ^ | **Scenario 3.2.1**: Deretan lukisan | 1. Simpan 2 lukisan hari ini.<br>2. Buka Report hari ini. | - 2 thumbnail tampil dengan nama template dan jam. (*) |
| ^ | **Scenario 3.3.1**: Statistik ROM tampil | 1. Melukis dengan kamera sambil mengangkat lengan ke samping.<br>2. Simpan.<br>3. Buka Report hari ini. | - Highest ROM kiri dan kanan tampil dalam derajat; catatan "Camera estimates" tampil. (*) |
| ^ | **Scenario 3.3.2**: Tanpa data gerak | 1. Melukis hanya dengan sentuhan.<br>2. Simpan.<br>3. Buka Report hari ini. | - Muncul "No movement data". (*) |
| ^ | **Scenario 3.4.1**: Heatmap dan hand dominance | 1. Melukis di sisi kiri kanvas dengan tangan kiri lebih lama.<br>2. Simpan.<br>3. Buka Report. | - Heatmap merah di sisi kiri; Left % lebih besar dari Right %. (*) |
| ^ | **Scenario 3.4.2**: Tidak ada waktu melukis | 1. Buka kanvas, hanya bergerak dengan open hand, lalu simpan lukisan sentuhan.<br>2. Buka Report. | - Muncul "No painting time recorded" atau "No movement data". (*) |
| ^ | **Scenario 3.5.1**: Data tersimpan lokal | 1. Aktifkan airplane mode.<br>2. Melukis dan simpan.<br>3. Cek folder Application Support/Gallery/. | - PNG dan JSON sidecar ada; app berjalan tanpa jaringan. (*) |
