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

# Ağ seçimi
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
        ;;
    2)
        NETWORK="base-sepolia"
        ENV_FILE=".env.base-sepolia"
        ;;
    3)
        NETWORK="base"
        ENV_FILE=".env.base"
        ;;
    *)
        hata_yazdir "Geçersiz seçim!"
        exit 1
        ;;
esac

basarili_yazdir "Seçilen ağ: $NETWORK"

# RPC adresi al
echo ""
read -p "RPC adresinizi girin: " RPC_URL

# Private key al
echo ""
read -s -p "Private key'inizi girin: " PRIVATE_KEY
echo ""

# USDC bakiyesini kontrol et
echo ""
bilgi_yazdir "USDC bakiyesi kontrol ediliyor..."

# Cüzdan adresini al (eğer cast yüklüyse)
if command -v cast &> /dev/null; then
    WALLET_ADDRESS=$(echo $PRIVATE_KEY | xargs -I {} cast wallet address {} 2>/dev/null || echo "")
    if [[ -n "$WALLET_ADDRESS" ]]; then
        echo "Cüzdan adresi: $WALLET_ADDRESS"
        
        # USDC kontrat adresleri
        case $NETWORK in
            "eth-sepolia")
                USDC_CONTRACT="0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
                ;;
            "base-sepolia")
                USDC_CONTRACT="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
                ;;
            "base")
                USDC_CONTRACT="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
                ;;
        esac
        
        # Bakiye sorgulama
        BALANCE=$(cast call $USDC_CONTRACT "balanceOf(address)(uint256)" $WALLET_ADDRESS --rpc-url $RPC_URL 2>/dev/null || echo "0")
        
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

# Environment'ı yükle
source $ENV_FILE

# Rust ve diğer environment'ları yükle
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi

if [[ -f "$HOME/.rzup/env" ]]; then
    source "$HOME/.rzup/env"
fi

if [[ -f "/root/.risc0/env" ]]; then
    source "/root/.risc0/env"
fi

export PATH="$HOME/.cargo/bin:$PATH"
export PATH="/root/.risc0/bin:$PATH"

# Stake kontrolü ve yatırma
adim_yazdir "Stake durumu kontrol ediliyor..."

# Ağa göre parametreleri belirle
case $NETWORK in
    "eth-sepolia")
        CHAIN_ID="11155111"
        MARKET_ADDRESS="0x13337C76fE2d1750246B68781ecEe164643b98Ec"
        VERIFIER_ADDRESS="0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64"
        ;;
    "base-sepolia")
        CHAIN_ID="84532"
        MARKET_ADDRESS="0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b"
        VERIFIER_ADDRESS="0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760"
        ;;
    "base")
        CHAIN_ID="8453"
        MARKET_ADDRESS="0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8"
        VERIFIER_ADDRESS="0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760"
        ;;
esac

# Boundless CLI kontrolü
if ! command -v boundless &> /dev/null; then
    uyari_yazdir "Boundless CLI bulunamadı, yükleniyor..."
    cargo install --locked boundless-cli
    export PATH=$PATH:/root/.cargo/bin
    source ~/.bashrc
fi

# USDC Stake kontrolü
stake_balance=$(boundless --rpc-url $RPC_URL --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --boundless-market-address $MARKET_ADDRESS --set-verifier-address $VERIFIER_ADDRESS account stake-balance 2>/dev/null | grep -o '[0-9.]*' | head -1)

if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance <= 0" | bc -l 2>/dev/null || echo 1) )); then
    uyari_yazdir "USDC stake edilmemiş! 5 USDC stake etmek ister misiniz? (e/h): "
    read -r yanit
    if [[ $yanit == "e" || $yanit == "E" ]]; then
        boundless --rpc-url $RPC_URL --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --boundless-market-address $MARKET_ADDRESS --set-verifier-address $VERIFIER_ADDRESS account deposit-stake 5
        basarili_yazdir "5 USDC stake edildi"
    else
        bilgi_yazdir "USDC stake işlemi atlandı"
    fi
else
    basarili_yazdir "USDC Stake mevcut: $stake_balance USDC"
fi

# broker.toml dosyasını oluştur
adim_yazdir "Broker yapılandırması ayarlanıyor..."

# GPU modeline göre ayarları belirle
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

# Node'u başlat
echo ""
adim_yazdir "Node başlatılıyor..."

if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı! Setup.sh başarılı çalıştığından emin olun."
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

# Seçime göre node'u otomatik başlat
case $NETWORK_CHOICE in
    1)
        bilgi_yazdir "Ethereum Sepolia node'u başlatılıyor..."
        just broker
        echo "Ethereum Sepolia ağında mining başladı!"
        ;;
    2)
        bilgi_yazdir "Base Sepolia node'u başlatılıyor..."
        just broker
        echo "Base Sepolia ağında mining başladı!"
        ;;
    3)
        bilgi_yazdir "Base Mainnet node'u başlatılıyor..."
        just broker
        echo "Base Mainnet ağında mining başladı!"
        ;;
esac

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
echo "  Model: $gpu_model"
echo "  Adet: $gpu_count"
echo ""
echo -e "${YELLOW}İyi provlamalar!${NC}"
