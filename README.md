# tapo-cctv-web

Menampilkan kamera CCTV TP-Link Tapo di browser, tanpa aplikasi Tapo.

[MediaMTX](https://github.com/bluenviron/mediamtx) mengambil stream RTSP dari kamera, lalu menyajikannya ulang sebagai HLS, WebRTC, dan RTSP. Halaman web di `web/` memutar stream HLS dengan [hls.js](https://github.com/video-dev/hls.js).

```
Kamera Tapo ──RTSP (TCP)──> MediaMTX ──HLS──> browser / aplikasi
                                     ├─WebRTC
                                     └─RTSP (re-stream)
```

## Kebutuhan

- Linux (x86_64, arm64, atau armv7/armv6, misalnya Raspberry Pi)
- `python3` dan `curl`
- Komputer dan kamera berada di jaringan lokal yang sama
- Camera Account Tapo: buka aplikasi Tapo, lalu Camera Settings > Advanced Settings > Camera Account. Akun ini berbeda dari akun cloud TP-Link.

## Cara menjalankan

```bash
git clone https://github.com/habibhkrnwn/tapo-cctv-web.git
cd tapo-cctv-web
cp .env.example .env
# Isi CAMERA_HOST, CAMERA_USER, dan CAMERA_PASS di .env
./start.sh
```

Saat pertama dijalankan, `start.sh` mengunduh MediaMTX ke `bin/`. Setelah itu, buka:

- Di komputer yang sama: http://localhost:8080
- Dari perangkat lain di jaringan yang sama: `http://<IP-komputer>:8080`

Tekan `Ctrl+C` untuk menghentikan server.

## Endpoint

| Stream | URL |
| --- | --- |
| Halaman viewer | `http://<host>:8080` |
| HLS HD (stream1) | `http://<host>:8888/cctv/index.m3u8` |
| HLS SD (stream2) | `http://<host>:8888/cctv_sd/index.m3u8` |
| WebRTC | `http://<host>:8889/cctv/` |
| RTSP re-stream | `rtsp://<host>:8554/cctv` |

Port yang dipakai: 8080 (web), 8888 (HLS), 8889 dan 8189/udp (WebRTC), 8554 (RTSP).

URL HLS juga bisa diputar langsung di aplikasi, misalnya ExoPlayer/Media3 di Android atau AVPlayer di iOS. URL RTSP re-stream bisa dipakai untuk OpenCV atau model deteksi, sehingga kamera hanya melayani satu koneksi.

## Kenapa HLS, bukan WebRTC

Kamera Tapo mengirim H264 Main profile. Decoder WebRTC di Firefox (OpenH264) hanya berhasil decode keyframe dari stream ini. Hasilnya sekitar 0.5 fps, padahal kamera mengirim 15 fps. Dengan HLS, browser memakai decoder video biasa. Hasil tes di Firefox:

| | WebRTC | HLS |
| --- | --- | --- |
| Frame tampil | ~0.5 fps | 15 fps |
| Delay | – | ~0.7 s (SD) – 1.0 s (HD) |

Endpoint WebRTC tetap aktif untuk browser lain.

## Konfigurasi

- `.env` menyimpan alamat dan akun kamera. File ini tidak masuk git.
- `mediamtx.yml` adalah template konfigurasi MediaMTX. `start.sh` mengisi `{{CAMERA_URL}}` dari `.env`, lalu menulis hasilnya ke `mediamtx.run.yml`. File hasil ini juga tidak masuk git.
- Setelah mengubah `.env` atau `mediamtx.yml`, jalankan ulang `./start.sh`.

## Troubleshooting

- **Stream tidak muncul.** Cek log MediaMTX di terminal. `dial tcp ...: i/o timeout` berarti komputer tidak bisa menjangkau kamera. Pastikan keduanya di jaringan yang sama, lalu cek dengan `ping <CAMERA_HOST>`.
- **`401 Unauthorized` dari kamera.** Username atau password salah. Pakai Camera Account dari aplikasi Tapo, bukan akun cloud TP-Link.
- **VLC gagal membuka RTSP kamera.** Paksa transport TCP. Buka Media > Open Network Stream > Show more options, lalu isi `:rtsp-tcp` di Edit Options.
- **Video patah-patah.** Pilih SD, dekatkan kamera ke router, atau sambungkan komputer ke router dengan kabel LAN.

## Keamanan

Server ini tidak memakai login, jadi siapa pun di jaringan lokal yang sama bisa menonton. Jangan buka port-port di atas ke internet. Untuk akses dari luar, pakai VPN seperti Tailscale, atau pasang autentikasi MediaMTX (`authInternalUsers`) sebelum memakai tunnel publik.
