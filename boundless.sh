#!/bin/bash

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

# Environment'ları yükle
environment_yukle() {
    adim_yazdir "Environment'lar yükleniyor..."
    
    # Sistem environment'ları
    source ~/.bashrc 2>/dev/null || true
    
    # Rust environment
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
        bilgi_yazdir "Rust environment yüklendi"
    fi
    
    # RISC Zero environment
    if [[ -f "$HOME/.rzup/env" ]]; then
        source "$HOME/.rzup/env"
        bilgi_yazdir "RISC Zero environment yüklendi"
    fi
    
    if [[ -f "/root/.risc0/env" ]]; then
        source "/root/.risc0/env"
        bilgi_yazdir "RISC Zero root environment yüklendi"
    fi
    
    # PATH güncelle
    export PATH="$HOME/.cargo/bin:$PATH"
    export PATH="/root/.risc0/bin:$PATH"
    
    basarili_yazdir "Environment'lar yüklendi"
}

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}  Bu Script UFUKDEGEN Tarafından Hazırlanmıştır  ${NC}"
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
git clone https://github.com/boundless-xyz/boundless
cd boundless
git checkout release-0.10
basarili_yazdir "Repository klonlandı ve release-0.10 dalına geçildi"

adim_yazdir "Setup scripti çalıştırılıyor..."
bash ./scripts/setup.sh
basarili_yazdir "Setup scripti tamamlandı"

# GPU sayısını ve modelini tespit et
gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)
bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"

# Önce just broker çalıştır
adim_yazdir "İlk kurulum başlatılıyor..."
just broker &
BROKER_PID=$!

echo "Kurulum tamamlanıyor, lütfen bekleyin..."
sleep 30

# Broker'ı durdur
kill $BROKER_PID 2>/dev/null
just down

basarili_yazdir "İlk kurulum tamamlandı"

# 5. Network seçimi
adim_yazdir "Network yapılandırması başlatılıyor..."

echo ""
echo -e "${PURPLE}Hangi ağda prover çalıştırmak istiyorsunuz:${NC}"
echo "1. Ethereum Sepolia"
echo "2. Base Sepolia (Test ağı)"
echo "3. Base Mainnet"
echo ""
read -p "Seçiminizi girin (1/2/3): " network_secim

echo ""
echo "Lütfen aşağıdaki bilgileri girin:"
echo ""

# RPC al
case $network_secim in
    "1")
        echo -n "Ethereum Sepolia RPC URL'nizi girin: "
        read rpc_url
        ENV_FILE=".env.eth-sepolia"
        NETWORK="eth-sepolia"
        USDC_CONTRACT="0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
        ;;
    "2")
        echo -n "Base Sepolia RPC URL'nizi girin: "
        read rpc_url
        ENV_FILE=".env.base-sepolia"
        NETWORK="base-sepolia"
        USDC_CONTRACT="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
        ;;
    "3")
        echo -n "Base Mainnet RPC URL'nizi girin: "
        read rpc_url
        ENV_FILE=".env.base"
        NETWORK="base"
        USDC_CONTRACT="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        ;;
    *)
        hata_yazdir "Geçersiz seçim! Lütfen 1, 2 veya 3 seçin."
        exit 1
        ;;
esac

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

# USDC bakiyesini kontrol et
echo ""
bilgi_yazdir "USDC bakiyesi kontrol ediliyor..."

# Cüzdan adresini al (eğer cast yüklüyse)
if command -v cast &> /dev/null; then
    WALLET_ADDRESS=$(echo $private_key | xargs -I {} cast wallet address {} 2>/dev/null || echo "")
    if [[ -n "$WALLET_ADDRESS" ]]; then
        echo "Cüzdan adresi: $WALLET_ADDRESS"
        
        # Bakiye sorgulama
        BALANCE=$(cast call $USDC_CONTRACT "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $rpc_url 2>/dev/null || echo "0")
        
        if [ "$BALANCE" == "0" ]; then
            uyari_yazdir "Dikkat: USDC bakiyeniz yetersiz!"
            echo "Stake işlemi yapabilmek için USDC'ye ihtiyacınız var."
            if [[ $NETWORK != "base" ]]; then
                echo "Test ağları için Circle Faucet'tan USDC alabilirsiniz: https://faucet.circle.com/"
            fi
            echo ""
            read -p "Devam etmek istiyor musunuz? (e/h): " CONTINUE
            if [ "$CONTINUE" != "e" ]; then
                exit 1
            fi
        else
            basarili_yazdir "USDC bakiyesi mevcut"
        fi
    fi
else
    uyari_yazdir "Cast yüklü değil, bakiye kontrolü atlanıyor"
fi

# ENV dosyasını güncelle
adim_yazdir "Yapılandırma dosyası güncelleniyor..."

if [[ -f "$ENV_FILE" ]]; then
    # Mevcut dosyayı backup al
    cp $ENV_FILE ${ENV_FILE}.backup
    
    # Önce mevcut PRIVATE_KEY ve RPC_URL satırlarını sil
    sed -i '/^export PRIVATE_KEY=/d' $ENV_FILE
    sed -i '/^export RPC_URL=/d' $ENV_FILE
    
    # PRIVATE_KEY'i SET_VERIFIER_ADDRESS'ten sonra ekle
    sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' $ENV_FILE
    
    # RPC_URL'i ORDER_STREAM_URL'den sonra ekle  
    sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' $ENV_FILE
else
    hata_yazdir "$ENV_FILE dosyası bulunamadı!"
    exit 1
fi

basarili_yazdir "$NETWORK ağı yapılandırıldı"

# Environment'ı yükle
source $ENV_FILE
environment_yukle()

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

# GPU modeline göre ayarlar
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

# Sadece just broker çalıştır
bilgi_yazdir "$NETWORK node'u başlatılıyor..."
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
        echo "Ethereum Sepolia ağında mining başladı!"
        ;;
    "2")
        echo "Base Sepolia ağında mining başladı!"
        ;;
    "3")
        echo "Base Mainnet ağında mining başladı!"
        ;;
esac
echo ""
echo "Node'unuz şimdi mining yapıyor! Logları kontrol edin."
