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

---

### 5. .env Dosyasını Ayarla:

```bash
nano .env.base
```

İçeriği şöyle olmalı:

```bash
export PRIVATE_KEY=0xPRIVATEKEYİNİZ
export RPC_URL="https://base-sepolia-rpc-url"
```

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

