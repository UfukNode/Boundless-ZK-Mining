#!/bin/bash

# dpkg kilitli mi diye kontrol et ve düzelt
if sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
  echo "[UYARI] dpkg başka bir işlem tarafından kullanılıyor. Lütfen bekleyin."
  exit 1
fi

if sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
  echo "[UYARI] apt başka bir işlem tarafından kullanılıyor. Lütfen bekleyin."
  exit 1
fi

# dpkg yarım kaldıysa düzelt
sudo dpkg --configure -a

# Boundless ZK Mining Otomatik Kurulum

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

adim_yazdir() {
    echo -e "${BLUE}[ADIM]${NC} $1"
}

basarili_yazdir() {
    echo -e "${GREEN}[BASARILI]${NC} $1"
}

uyari_yazdir() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
}

hata_yazdir() {
    echo -e "${RED}[HATA]${NC} $1"
}

bilgi_yazdir() {
    echo -e "${CYAN}[BILGI]${NC} $1"
}

# GPU sayısını tespit et
gpu_sayisi_tespit() {
    local gpu_count=0
    if command -v nvidia-smi &> /dev/null; then
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    fi
    echo $gpu_count
}

# GPU modelini tespit et
gpu_model_tespit() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1
    else
        echo "Unknown"
    fi
}

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}       Boundless Prover Kurulum Scripti          ${NC}"
echo -e "${PURPLE}=================================================${NC}"
echo ""

# 1. Sistem güncellemeleri
adim_yazdir "Sistem güncelleniyor..."
apt update && apt upgrade -y
basarili_yazdir "Sistem güncellemeleri tamamlandı"

# 2. Gerekli paketleri kur
adim_yazdir "Gerekli paketler kuruluyor..."
apt install -y build-essential clang gcc make cmake pkg-config autoconf automake ninja-build
apt install -y curl wget git tar unzip lz4 jq htop tmux nano ncdu iptables nvme-cli bsdmainutils
apt install -y libssl-dev libleveldb-dev libclang-dev libgbm1 bc
basarili_yazdir "Gerekli paketler kuruldu"

# 3. Gerekli bağımlılıklar scripti çalıştır
adim_yazdir "Gerekli bağımlılıklar kuruluyor... (Bu işlem uzun sürebilir)"
bash <(curl -s https://raw.githubusercontent.com/UfukNode/Boundless-ZK-Mining/refs/heads/main/gerekli_bagimliliklar.sh)
basarili_yazdir "Bağımlılıklar kuruldu"

# 4. Boundless reposunu klonla
adim_yazdir "Boundless repository klonlanıyor..."
if [[ -d "boundless" ]]; then
    bilgi_yazdir "Boundless dizini zaten mevcut, güncelleniyor..."
    cd boundless
    git fetch
    git checkout release-0.10
else
    git clone https://github.com/boundless-xyz/boundless
    cd boundless
    git checkout release-0.10
fi
basarili_yazdir "Repository klonlandı ve release-0.10 dalına geçildi"

adim_yazdir "Setup scripti çalıştırılıyor..."
bash ./scripts/setup.sh
basarili_yazdir "Setup scripti tamamlandı"

# GPU sayısını ve modelini tespit et
gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)

if [[ $gpu_count -eq 0 ]]; then
    hata_yazdir "GPU tespit edilemedi! Nvidia GPU ve sürücülerin kurulu olduğundan emin olun."
    exit 1
fi

bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"

# GPU'ya göre broker ayarlarını optimize et
adim_yazdir "Broker ayarları GPU modeli ve sayısına göre optimize ediliyor..."

# Broker template dosyasını kontrol et ve oluştur
if [[ ! -f "broker-template.toml" ]]; then
    bilgi_yazdir "broker-template.toml bulunamadı, oluşturuluyor..."
    cat > broker-template.toml << 'EOF'
max_concurrent_proofs = 2
peak_prove_khz = 100
EOF
fi

cp broker-template.toml broker.toml

# broker.toml dosyasını GPU'ya göre yapılandır
if [[ $gpu_model == *"3090"* ]]; then
    cat > broker.toml << 'EOF'
[market]
mcycle_price = "0.0000005"
peak_prove_khz = 150
max_mcycle_limit = 8000
min_deadline = 300
max_concurrent_proofs = 2
lockin_priority_gas = 800
EOF
    basarili_yazdir "RTX 3090 için ayarlar yapılandırıldı"
elif [[ $gpu_model == *"4090"* ]]; then
    cat > broker.toml << 'EOF'
[market]
mcycle_price = "0.0000005"
peak_prove_khz = 150
max_mcycle_limit = 10000
min_deadline = 300
max_concurrent_proofs = 3
lockin_priority_gas = 800
EOF
    basarili_yazdir "RTX 4090 için ayarlar yapılandırıldı"
else
    cat > broker.toml << 'EOF'
[market]
mcycle_price = "0.0000005"
peak_prove_khz = 100
max_mcycle_limit = 5000
min_deadline = 300
max_concurrent_proofs = 2
lockin_priority_gas = 800
EOF
    bilgi_yazdir "Varsayılan ayarlar kullanıldı"
fi

# 5. Network seçimi ve .env dosyalarını ayarla
adim_yazdir "Network yapılandırması başlatılıyor..."

echo ""
echo -e "${PURPLE}Hangi ağda prover çalıştırmak istiyorsunuz:${NC}"
echo "1. Base Sepolia (Test ağı)"
echo "2. Base Mainnet"
echo "3. Ethereum Sepolia"
echo ""
read -p "Seçiminizi girin (1/2/3): " network_secim

echo ""
echo "Lütfen aşağıdaki bilgileri girin:"
echo ""

# Private key al
echo -n "Private Key'inizi girin: "
read -s private_key
echo ""

while [[ -z "$private_key" ]]; do
    hata_yazdir "Private key boş olamaz!"
    echo -n "Private Key'inizi tekrar girin: "
    read -s private_key
    echo ""
done

bilgi_yazdir "Private key alındı"

# Network'e göre işlemleri yap
if [[ $network_secim == "1" ]]; then
    echo -n "Base Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    # ENV dosyasını güncelle
    if [[ -f ".env.base-sepolia" ]]; then
        cp .env.base-sepolia .env.base-sepolia.backup
        sed -i '/^export PRIVATE_KEY=/d' .env.base-sepolia
        sed -i '/^export RPC_URL=/d' .env.base-sepolia
        sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' .env.base-sepolia
        sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' .env.base-sepolia
    else
        hata_yazdir ".env.base-sepolia dosyası bulunamadı!"
        exit 1
    fi
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
    
    # Environment'ı yükle
    adim_yazdir "Environment dosyaları yükleniyor..."
    source ./.env.base-sepolia
    basarili_yazdir "Base Sepolia environment'ı yüklendi"
    
    # Stake kontrolü
    echo ""
    bilgi_yazdir "Base Sepolia bakiye kontrol ediliyor..."
    
    stake_balance=$(boundless --rpc-url $rpc_url --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account stake-balance 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance <= 0" | bc -l 2>/dev/null || echo 1) )); then
        uyari_yazdir "USDC stake edilmemiş! 5 USDC stake etmek ister misiniz? (e/h): "
        read -r yanit
        if [[ $yanit == "e" || $yanit == "E" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5
            basarili_yazdir "5 USDC stake edildi"
        else
            bilgi_yazdir "USDC stake işlemi atlandı"
        fi
    else
        basarili_yazdir "USDC Stake mevcut: $stake_balance USDC"
    fi
    
elif [[ $network_secim == "2" ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read rpc_url
    
    # ENV dosyasını güncelle
    if [[ -f ".env.base" ]]; then
        cp .env.base .env.base.backup
        sed -i '/^export PRIVATE_KEY=/d' .env.base
        sed -i '/^export RPC_URL=/d' .env.base
        sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' .env.base
        sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' .env.base
    else
        hata_yazdir ".env.base dosyası bulunamadı!"
        exit 1
    fi
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
    
    # Environment'ı yükle
    adim_yazdir "Environment dosyaları yükleniyor..."
    source ./.env.base
    basarili_yazdir "Base Mainnet environment'ı yüklendi"
    
    # Stake kontrolü
    echo ""
    bilgi_yazdir "Base Mainnet bakiye kontrol ediliyor..."
    
    stake_balance=$(boundless --rpc-url $rpc_url --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account stake-balance 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance <= 0" | bc -l 2>/dev/null || echo 1) )); then
        uyari_yazdir "USDC stake edilmemiş! 5 USDC stake etmek ister misiniz? (e/h): "
        read -r yanit
        if [[ $yanit == "e" || $yanit == "E" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5
            basarili_yazdir "5 USDC stake edildi"
        else
            bilgi_yazdir "USDC stake işlemi atlandı"
        fi
    else
        basarili_yazdir "USDC Stake mevcut: $stake_balance USDC"
    fi
    
elif [[ $network_secim == "3" ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    # ENV dosyasını güncelle
    if [[ -f ".env.eth-sepolia" ]]; then
        cp .env.eth-sepolia .env.eth-sepolia.backup
        sed -i '/^export PRIVATE_KEY=/d' .env.eth-sepolia
        sed -i '/^export RPC_URL=/d' .env.eth-sepolia
        sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' .env.eth-sepolia
        sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' .env.eth-sepolia
    else
        hata_yazdir ".env.eth-sepolia dosyası bulunamadı!"
        exit 1
    fi
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
    
    # Environment'ı yükle
    adim_yazdir "Environment dosyaları yükleniyor..."
    source ./.env.eth-sepolia
    basarili_yazdir "Ethereum Sepolia environment'ı yüklendi"
    
    # Stake kontrolü
    echo ""
    bilgi_yazdir "Ethereum Sepolia bakiye kontrol ediliyor..."
    
    stake_balance=$(boundless --rpc-url $rpc_url --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account stake-balance 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance <= 0" | bc -l 2>/dev/null || echo 1) )); then
        uyari_yazdir "USDC stake edilmemiş! 5 USDC stake etmek ister misiniz? (e/h): "
        read -r yanit
        if [[ $yanit == "e" || $yanit == "E" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit-stake 5
            basarili_yazdir "5 USDC stake edildi"
        else
            bilgi_yazdir "USDC stake işlemi atlandı"
        fi
    else
        basarili_yazdir "USDC Stake mevcut: $stake_balance USDC"
    fi
    
else
    hata_yazdir "Geçersiz seçim! Lütfen 1, 2 veya 3 seçin."
    exit 1
fi

# 6. Node'u başlat
adim_yazdir "Node başlatılıyor..."

if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı! Setup.sh başarılı çalıştığından emin olun."
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

# Sadece just broker kullan
bilgi_yazdir "Node başlatılıyor..."
just broker

echo ""
echo "========================================="
echo "       KURULUM TAMAMLANDI!"
echo "========================================="
echo ""
echo "Yararlı komutlar:"
echo "• Logları kontrol et: docker compose logs -f broker"
echo "• Stake bakiyesi: boundless account stake-balance"
echo "• Node'u durdur: docker compose down"
echo ""
echo "GPU Konfigürasyonu:"
echo "• Tespit edilen GPU: $gpu_model"
echo "• GPU Sayısı: $gpu_count"
echo ""
case $network_secim in
    "1")
        echo "Base Sepolia ağında mining başladı!"
        ;;
    "2")
        echo "Base Mainnet ağında mining başladı!"
        ;;
    "3")
        echo "Ethereum Sepolia ağında mining başladı!"
        ;;
esac
echo ""
echo "Node'unuz şimdi mining yapıyor! Logları kontrol edin."

