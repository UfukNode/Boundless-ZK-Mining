![GtP8PwbWoAA-KTL](https://github.com/user-attachments/assets/89f63f2d-b776-4e8d-a1f5-c53a2ebe25de)

#  Boundless Prover Node Kurulum Rehberi: (Base Mainnet)

Bu rehberde, Base Mainnet ağı üzerinde çalışan bir Boundless Prover node’unu nasıl kuracağınızı ve order alarak proof üretebileceğinizi adım adım anlattım.

|  Bileşen         | Minimum Gereksinim            |
| ------------------- | ----------------------------- |
| **İşlemci**         | Min. 16 vCPU                      |
| **RAM**             | Min. 32 GB                        |
| **Disk**      | Min. 200 GB SSD             |

---

## Bu Node’u Neden Kuruyoruz?
Boundless ağı, cihazlara “şu işlemi hesapla” diye görevler veriyor.
Sen de bu node’u kurarak bu görevleri üstleniyor, işlemleri yapıyor ve karşılığında kazanç elde ediyorsun.

- Bu görevlere sistemde “Order” deniyor.
- Senin node’un da bu order’ları yakalamaya çalışıyor.
- İşlemi ilk tamamlayan kazanıyor — yani sistemin hızlıysa, RPC'in sağlamsa ve donanımın iyiyse öne geçiyorsun.

---

### 1. Gerekli Güncellemeleri Yap:

```bash
apt update && apt upgrade -y
```

### 2. Gerekli Paketleri Kur:

```bash
apt install -y build-essential clang gcc make cmake pkg-config autoconf automake ninja-build
apt install -y curl wget git tar unzip lz4 jq htop tmux nano ncdu iptables nvme-cli bsdmainutils
apt install -y libssl-dev libleveldb-dev libclang-dev libgbm1
```

---

### 3. Gerekli Araçları Script ile Yükle: (Uzun Sürebilir)

```bash
bash <(curl -s https://raw.githubusercontent.com/UfukNode/Boundless-ZK-Mining/refs/heads/main/gerekli_bagimliliklar.sh)
```
- Kurulum bittikten sonra aşağıdaki gibi çıktı alacaksınız.

![image](https://github.com/user-attachments/assets/688d06e5-4a8b-4a01-87f5-08a3949ef098)

- Terminali yeniden başlatıp, adımlara devam edin.

---

### 4. Reposu Klonla ve Kurulumu Başlat:

```bash
git clone https://github.com/boundless-xyz/boundless
cd boundless
git checkout release-0.10
bash ./scripts/setup.sh
```
```bash
bash ./scripts/setup.sh
```
- Bu kısım biraz uzun sürebilir. Lütfen sabırla bekleyin.

![image](https://github.com/user-attachments/assets/e55f5a37-e7b5-480d-b9d7-961d888f5bcd)

---

### 5. Base .env Dosyasını Ayarla:

```bash
nano .env.base
```

İçeriği şöyle olmalı:

1- Altına export PRIVATE_KEY=0xPRIVATEKEYİNİZ bu formatta gir.
2- RPC altına export RPC_URL="https://base-sepolia-rpc-url" bu formatta gir.
3- CTRL x bas ve y enter yaparak kaydet.

- Doğru çıktı örneği aşağıdaki gibidir



Ardından:

```bash
source .env.base
```

---

### 6. Base Ağına USDC Stake Et

```bash
source ~/.bashrc
```
```bash
source ~/.bashrc
boundless account deposit-stake 5
```
- Başarılı stake çıktı örneği:

![image](https://github.com/user-attachments/assets/0863d49a-08f7-4bcf-befa-a1609e390817)

---

### 7. ETH Deposit İşlemini Yap

```bash
boundless account deposit 0.0001
```
- Başarılı deposit çıktı örneği:

![image](https://github.com/user-attachments/assets/1f197201-6c24-42dc-bcb1-193097372fdd)

📌 Stake bakiyeni görmek istersen:

```bash
boundless account stake-balance
```

---

### 8. Node'u Başlat

```bash
just broker
```

---

### 9. Logları Kontrol Et

```bash
docker compose logs -f broker
```
Aşağıdaki gibi çıktı almanız gerekiyor.

---

## 📊 Explorer Üzerinden Node Performansını Takip Etme:

Node’unu kurduktan sonra her şeyin doğru çalışıp çalışmadığını en net göreceğin yer:
→ https://explorer.beboundless.xyz/provers/"cüzdan-adresini-gir"
Burada cüzdan adresine tıkladığında node’unun detaylı istatistiklerini görebilirsin.

![image](https://github.com/user-attachments/assets/b0cf0733-ca7a-4fdd-929c-582e4d957e2b)

### Neleri Takip Etmelisin:

| Alan                     | Açıklama                                                                       |
| ------------------------ | ------------------------------------------------------------------------------ |
| **Orders Taken**         | Şimdiye kadar aldığın görev (order) sayısıdır. Artıyorsa node aktif.           |
| **Cycles Proved**        | Toplam işlenen ZK işlem gücü (cycle). Ne kadar yüksekse, katkın o kadar büyük. |
| **Order Earnings (ETH)** | Order'lardan kazandığın toplam ETH miktarı.                                    |
| **Average ETH/MC**       | 1 milyon cycle başına kazandığın ETH miktarıdır. Kârlılığı gösterir.           |
| **Peak MHz Reached**     | Node’un bir anda ulaştığı maksimum işlem gücü. Donanım kalitesini gösterir.    |
| **Fulfillment Rate**     | Aldığın görevleri başarıyla tamamlama oranı. %95+ olması idealdir.             |

![image](https://github.com/user-attachments/assets/2a9d6147-f9de-4b6e-a05a-c2e1f57b3363)

