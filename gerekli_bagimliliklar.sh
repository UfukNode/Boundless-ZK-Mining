#!/bin/bash

# Boundless Prover Türkçe Kurulum Scripti

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
basarili_yazdir "Repository hazır"

# 5. Setup scripti çalıştır
adim_yazdir "Setup scripti çalıştırılıyor..."
bash ./scripts/setup.sh
basarili_yazdir "Setup scripti tamamlandı"

# GPU modelini tespit et
GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1 2>/dev/null || echo "Unknown")
GPU_COUNT=$(nvidia-smi -L 2>/dev/null | wc -l || echo 0)
bilgi_yazdir "Tespit edilen GPU: $GPU_MODEL (Adet: $GPU_COUNT)"

# 6. İlk kurulum için just broker çalıştır
adim_yazdir "İlk kurulum başlatılıyor..."
just broker &
BROKER_PID=$!

echo "Kurulum tamamlanıyor, lütfen bekleyin..."
sleep 30

# Broker'ı durdur
kill $BROKER_PID 2>/dev/null
just down

basarili_yazdir "İlk kurulum tamamlandı"

# 7. Network seçimi
echo ""
echo -e "${BLUE}Hangi ağda çalıştırmak istiyorsunuz?${NC}"
echo "1) eth-sepolia"
echo "2) base-sepolia" 
echo "3) base (mainnet)"
read -p "Seçiminiz (1-3): " NETWORK_CHOICE

case $NETWORK_CHOICE in
    1)
        NETWORK="eth-sepolia"
        ENV_FILE=".env.eth-sepolia"
        USDC_CONTRACT="0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
        ;;
    2)
        NETWORK="base-sepolia"
        ENV_FILE=".env.base-sepolia"
        USDC_CONTRACT="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
        ;;
    3)
        NETWORK="base"
        ENV_FILE=".env.base"
        USDC_CONTRACT="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
        ;;
    *)
        hata_yazdir "Geçersiz seçim!"
        exit 1
        ;;
esac

basarili_yazdir "Seçilen ağ: $NETWORK"

# 8. RPC adresi al
echo ""
read -p "RPC adresinizi girin: " RPC_URL

# 9. Private key al
echo ""
read -s -p "Private key'inizi girin: " PRIVATE_KEY
echo ""

# 10. USDC bakiyesini kontrol et
echo ""
bilgi_yazdir "USDC bakiyesi kontrol ediliyor..."

# Cüzdan adresini al (eğer cast yüklüyse)
if command -v cast &> /dev/null; then
    WALLET_ADDRESS=$(echo $PRIVATE_KEY | xargs -I {} cast wallet address {} 2>/dev/null || echo "")
    if [[ -n "$WALLET_ADDRESS" ]]; then
        echo "Cüzdan adresi: $WALLET_ADDRESS"
        
        # Bakiye sorgulama
        BALANCE=$(cast call $USDC_CONTRACT "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $RPC_URL 2>/dev/null || echo "0")
        
        if [ "$BALANCE" == "0" ]; then
            uyari_yazdir "USDC bakiyeniz yetersiz! Stake işlemi için USDC gerekli."
            echo "Test ağları için Circle Faucet'tan USDC alabilirsiniz: https://faucet.circle.com/"
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

# 11. ENV dosyasını güncelle
adim_yazdir "Yapılandırma dosyası güncelleniyor..."

# Mevcut dosyayı yedekle
if [[ -f "$ENV_FILE" ]]; then
    cp $ENV_FILE ${ENV_FILE}.backup
    
    # PRIVATE_KEY ve RPC_URL satırlarını güncelle
    sed -i '/^export PRIVATE_KEY=/d' $ENV_FILE
    sed -i '/^export RPC_URL=/d' $ENV_FILE
    
    # SET_VERIFIER_ADDRESS'ten sonra PRIVATE_KEY ekle
    sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$PRIVATE_KEY'' $ENV_FILE
    
    # ORDER_STREAM_URL'den sonra RPC_URL ekle
    sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$RPC_URL'"' $ENV_FILE
else
    hata_yazdir "$ENV_FILE dosyası bulunamadı!"
    exit 1
fi

basarili_yazdir "Yapılandırma dosyası güncellendi"

# 12. Environment'ı yükle
source $ENV_FILE
basarili_yazdir "Environment yüklendi"

# 13. broker.toml dosyasını oluştur
adim_yazdir "Broker yapılandırması ayarlanıyor..."

# GPU modeline göre ayarları belirle
if [[ $GPU_MODEL == *"3090"* ]]; then
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
elif [[ $GPU_MODEL == *"4090"* ]]; then
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
    # Varsayılan ayarlar
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

# 14. Node'u başlat
echo ""
adim_yazdir "Node başlatılıyor..."
just broker

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}       KURULUM TAMAMLANDI!               ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Yararlı komutlar:"
echo "  Logları görüntüle: just broker logs"
echo "  Broker logları: docker compose logs -f broker"
echo "  Stake bakiyesi: boundless account stake-balance"
echo "  Node'u durdur: just broker down"
echo ""
echo "GPU Bilgileri:"
echo "  Model: $GPU_MODEL"
echo "  Adet: $GPU_COUNT"
echo ""
echo -e "${YELLOW}İyi provlamalar!${NC}"
