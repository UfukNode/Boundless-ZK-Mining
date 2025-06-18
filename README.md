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

Elbette Ufuk, verdiğin stile uygun kısa ve net hale getirdim. Repona ekleyebileceğin şekilde:

---

## Vast.ai'e SSH Key Ekleme

1. Bilgisayarında **Terminal** (veya PowerShell) aç.
2. Aşağıdaki komutu gir:

```bash
ssh-keygen
```

3. Gelen 3 soruya da sadece **Enter** yaparak geç.
4. SSH key dosyan oluşturup bilgisayarındaki key yolunu verecek. Onu kopyala.

![kopyala](https://github.com/user-attachments/assets/d6da34b4-a93b-4db7-a755-5eeb644545ec)

6. Verdiği yolu kopyala ve aşağıdaki gibi başına `cat` ekleyerek terminale gir.

```bash
cat ~/.ssh/id_rsa.pub
```

![Adsız tasarım](https://github.com/user-attachments/assets/a2da6842-94dd-42ef-9fe8-971474780f37)

6. [https://vast.ai/](https://cloud.vast.ai/?ref_id=222215) sitesine gir → soldan **Keys** git.
7. Sağ üstten `new` deyip kopyaladığın satırı yapıştır ve kaydet.

✅ Artık terminalden sunucularına şifresiz bağlanabilirsin.

---


## Vast.ai Template Seçimi ve Sunucu Kiralama

Boundless node'unu çalıştırmak için uygun bir sunucu kiralaman gerekir. Aşağıdaki adımları takip ederek doğru konfigürasyona sahip sunucuyu seçebilirsin.

1. Vast paneline gir ve sol üstten **“Templates”** sekmesine tıkla.
2. Açılan listeden **“Ubuntu 22.04 VM”** template’ini seç (aşağıdaki görselde gösterildiği gibi).

![Adsız tasarım](https://github.com/user-attachments/assets/452408df-df90-481d-8999-abdec53de3e7)

4. Üst menüden GPU seçimini yap: **RTX 3090** veya **4090** önerilir.
   > Daha düşük sistemlerle de çalışabilir ama performans düşer.
5. Depolamayı **150-200 GB SSD** aralığına ayarla (NVMe önerilir).
6. Sol üstteki sıralama menüsünden **Price (inc)** seçeneğini işaretle.
   > Bu sayede fiyat/performans en iyi sunucular üstte listelenir.
7. Listeden sana uygun cihazı seçip **Rent** butonuna bas.

![1](https://github.com/user-attachments/assets/29c2df12-340e-4aa9-adf9-d684398945a8)

---

## Sunucuya Giriş:

1. Soldan "Instances" kısmına git.
2. Cihazının üzerinde bulunan terminal butonuna tıkla ve "SSH" ile başlayan komutu kopyala.
3. Powershell veya terminaline yapıştır ve sunucuna giriş yap.

![Adsız tasarım](https://github.com/user-attachments/assets/dc14064a-63f0-43a9-b31e-81a2ca2a4bbd)

---

## Boundless Prover Node Kurulum Adımları:

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
Aşağıdaki çıktıdaki gibi bir süre yüklemeyi beklemelisiniz.

![Ekran görüntüsü 2025-06-18 131640](https://github.com/user-attachments/assets/86d08b4a-1672-4521-ad29-70068ee1bf19)

---

### 9. Logları Kontrol Et

```bash
docker compose logs -f broker
```
Aşağıdaki gibi çıktı almanız gerekiyor.

![Ekran görüntüsü 2025-06-18 133700](https://github.com/user-attachments/assets/c4758f65-b931-4f81-91d0-2701f5233662)

- CTRL + C yaparak logları durdurabilirsiniz. Prover node'unuz arkada çalışmaya devam edecek.

---

### Gerekli Komutlar:

## 1. Node'u Durdur:
```bash
just broker down
```

## Node'u Tekrar Başlat:
```bash
just broker up
```

## Logları Kontrol Et:
```bash
docker compose logs -f broker
```

---

## 📊 Explorer Üzerinden Node Performansını Takip Etme:

Node’unu kurduktan sonra her şeyin doğru çalışıp çalışmadığını en net göreceğin yer: https://explorer.beboundless.xyz/provers/"cüzdan-adresini-gir"
- Burada cüzdan adresine tıkladığında node’unun detaylı istatistiklerini görebilirsin.

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

