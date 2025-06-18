##  Boundless Prover Node Kurulum Rehberi:

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

- altına export *PRIVATE_KEY=0xPRIVATEKEYİNİZ* bu formatta gir.
- RPC altına export RPC_URL="https://base-sepolia-rpc-url" bu formatta gir.
- CTRL x bas ve y enter yaparak kaydet.

Doğru çıktı örneği aşağıdaki gibidir



Ardından:

```bash
source .env.base
```

---

### 6. Base Ağına USDC Stake Et

```bash
source ~/.bashrc
boundless account deposit-stake 5
```

---

### 7. ETH Deposit İşlemini Yap

```bash
boundless account deposit 0.0001
```

Stake bakiyeni görmek istersen:

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

