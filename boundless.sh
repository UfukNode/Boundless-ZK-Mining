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

# Basitleştirilmiş stake ve deposit kontrol fonksiyonu
check_and_stake() {
    local private_key=$1
    local rpc_url=$2
    local chain_id=$3
    local market_address=$4
    local verifier_address=$5
    local network_name=$6
    
    echo ""
    bilgi_yazdir "$network_name bakiye kontrolü yapılıyor..."
    
    # USDC Stake kontrolü
    stake_balance=$(boundless --rpc-url $rpc_url --private-key $private_key --chain-id $chain_id --boundless-market-address $market_address --set-verifier-address $verifier_address account stake-balance 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance <= 0" | bc -l) )); then
        uyari_yazdir "USDC stake edilmemiş! 5 USDC stake edin? (y/n): "
        read -r yanit
        if [[ $yanit == "y" || $yanit == "Y" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id $chain_id --boundless-market-address $market_address --set-verifier-address $verifier_address account deposit-stake 5
            basarili_yazdir "5 USDC stake edildi"
        else
            bilgi_yazdir "USDC stake işlemi atlandı"
        fi
    else
        basarili_yazdir "✓ USDC Stake OK: $stake_balance USDC"
    fi
    
    # ETH Deposit kontrolü
    eth_balance=$(boundless --rpc-url $rpc_url --private-key $private_key --chain-id $chain_id --boundless-market-address $market_address --set-verifier-address $verifier_address account balance 2>/dev/null | grep -o '[0-9.]*' | head -1)
    
    if [[ -z "$eth_balance" ]] || (( $(echo "$eth_balance <= 0.00005" | bc -l) )); then
        uyari_yazdir "ETH deposit edilmemiş! 0.0001 ETH deposit edin? (y/n): "
        read -r yanit
        if [[ $yanit == "y" || $yanit == "Y" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id $chain_id --boundless-market-address $market_address --set-verifier-address $verifier_address account deposit 0.0001
            basarili_yazdir "0.0001 ETH deposit edildi"
        else
            bilgi_yazdir "ETH deposit işlemi atlandı"
        fi
    else
        basarili_yazdir "✓ ETH Deposit OK: $eth_balance ETH"
    fi
}

# Base Sepolia ayarları
base_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Environment dosyalarını güncelle/oluştur
    if [[ -f ".env.base-sepolia" ]]; then
        # Mevcut dosyayı backup al
        cp .env.base-sepolia .env.base-sepolia.backup
        
        # Önce mevcut PRIVATE_KEY ve RPC_URL satırlarını sil
        sed -i '/^export PRIVATE_KEY=/d' .env.base-sepolia
        sed -i '/^export RPC_URL=/d' .env.base-sepolia
        
        # PRIVATE_KEY'i SET_VERIFIER_ADDRESS'ten sonra ekle
        sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' .env.base-sepolia
        
        # RPC_URL'i ORDER_STREAM_URL'den sonra ekle  
        sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' .env.base-sepolia
    else
        # Dosya yoksa oluştur
        cat > .env.base-sepolia << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
EOF
    fi
    
    # Broker dosyası için de aynı işlem
    if [[ -f ".env.broker.base-sepolia" ]]; then
        cp .env.broker.base-sepolia .env.broker.base-sepolia.backup
        # Gerekli satırları güncelle veya ekle
        if grep -q "PRIVATE_KEY" .env.broker.base-sepolia; then
            sed -i "s|PRIVATE_KEY=.*|PRIVATE_KEY=$private_key|" .env.broker.base-sepolia
        else
            echo "PRIVATE_KEY=$private_key" >> .env.broker.base-sepolia
        fi
        
        if grep -q "RPC_URL" .env.broker.base-sepolia; then
            sed -i "s|RPC_URL=.*|RPC_URL=$rpc_url|" .env.broker.base-sepolia
        else
            echo "RPC_URL=$rpc_url" >> .env.broker.base-sepolia
        fi
        
        # Diğer gerekli ayarları kontrol et ve ekle
        if ! grep -q "BOUNDLESS_MARKET_ADDRESS" .env.broker.base-sepolia; then
            echo "BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b" >> .env.broker.base-sepolia
        fi
        
        if ! grep -q "SET_VERIFIER_ADDRESS" .env.broker.base-sepolia; then
            echo "SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760" >> .env.broker.base-sepolia
        fi
        
        if ! grep -q "ORDER_STREAM_URL" .env.broker.base-sepolia; then
            echo "ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz" >> .env.broker.base-sepolia
        fi
    else
        # Dosya yoksa oluştur
        cat > .env.broker.base-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
EOF
    fi
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
    
    # Basitleştirilmiş stake ve deposit kontrolü
    check_and_stake "$private_key" "$rpc_url" "84532" "0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b" "0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760" "Base Sepolia"
}

# Base Mainnet ayarları
base_mainnet_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Environment dosyalarını güncelle/oluştur
    if [[ -f ".env.base" ]]; then
        # Mevcut dosyayı backup al
        cp .env.base .env.base.backup
        
        # Önce mevcut PRIVATE_KEY ve RPC_URL satırlarını sil
        sed -i '/^export PRIVATE_KEY=/d' .env.base
        sed -i '/^export RPC_URL=/d' .env.base
        
        # PRIVATE_KEY'i SET_VERIFIER_ADDRESS'ten sonra ekle
        sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' .env.base
        
        # RPC_URL'i ORDER_STREAM_URL'den sonra ekle  
        sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' .env.base
    else
        # Dosya yoksa oluştur
        cat > .env.base << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
EOF
    fi
    
    # Broker dosyası için de aynı işlem
    if [[ -f ".env.broker.base" ]]; then
        cp .env.broker.base .env.broker.base.backup
        # Gerekli satırları güncelle veya ekle
        if grep -q "PRIVATE_KEY" .env.broker.base; then
            sed -i "s|PRIVATE_KEY=.*|PRIVATE_KEY=$private_key|" .env.broker.base
        else
            echo "PRIVATE_KEY=$private_key" >> .env.broker.base
        fi
        
        if grep -q "RPC_URL" .env.broker.base; then
            sed -i "s|RPC_URL=.*|RPC_URL=$rpc_url|" .env.broker.base
        else
            echo "RPC_URL=$rpc_url" >> .env.broker.base
        fi
        
        # Diğer gerekli ayarları kontrol et ve ekle
        if ! grep -q "BOUNDLESS_MARKET_ADDRESS" .env.broker.base; then
            echo "BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8" >> .env.broker.base
        fi
        
        if ! grep -q "SET_VERIFIER_ADDRESS" .env.broker.base; then
            echo "SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760" >> .env.broker.base
        fi
        
        if ! grep -q "ORDER_STREAM_URL" .env.broker.base; then
            echo "ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz" >> .env.broker.base
        fi
    else
        # Dosya yoksa oluştur
        cat > .env.broker.base << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
EOF
    fi
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
    
    # Basitleştirilmiş stake ve deposit kontrolü
    check_and_stake "$private_key" "$rpc_url" "8453" "0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8" "0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760" "Base Mainnet"
}

# Ethereum Sepolia ayarları
ethereum_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Environment dosyalarını güncelle/oluştur
    if [[ -f ".env.eth-sepolia" ]]; then
        # Mevcut dosyayı backup al
        cp .env.eth-sepolia .env.eth-sepolia.backup
        
        # Önce mevcut PRIVATE_KEY ve RPC_URL satırlarını sil
        sed -i '/^export PRIVATE_KEY=/d' .env.eth-sepolia
        sed -i '/^export RPC_URL=/d' .env.eth-sepolia
        
        # PRIVATE_KEY'i SET_VERIFIER_ADDRESS'ten sonra ekle
        sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$private_key'' .env.eth-sepolia
        
        # RPC_URL'i ORDER_STREAM_URL'den sonra ekle  
        sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$rpc_url'"' .env.eth-sepolia
    else
        # Dosya yoksa oluştur
        cat > .env.eth-sepolia << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
EOF
    fi
    
    # Broker dosyası için de aynı işlem
    if [[ -f ".env.broker.eth-sepolia" ]]; then
        cp .env.broker.eth-sepolia .env.broker.eth-sepolia.backup
        # Gerekli satırları güncelle veya ekle
        if grep -q "PRIVATE_KEY" .env.broker.eth-sepolia; then
            sed -i "s|PRIVATE_KEY=.*|PRIVATE_KEY=$private_key|" .env.broker.eth-sepolia
        else
            echo "PRIVATE_KEY=$private_key" >> .env.broker.eth-sepolia
        fi
        
        if grep -q "RPC_URL" .env.broker.eth-sepolia; then
            sed -i "s|RPC_URL=.*|RPC_URL=$rpc_url|" .env.broker.eth-sepolia
        else
            echo "RPC_URL=$rpc_url" >> .env.broker.eth-sepolia
        fi
        
        # Diğer gerekli ayarları kontrol et ve ekle
        if ! grep -q "BOUNDLESS_MARKET_ADDRESS" .env.broker.eth-sepolia; then
            echo "BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec" >> .env.broker.eth-sepolia
        fi
        
        if ! grep -q "SET_VERIFIER_ADDRESS" .env.broker.eth-sepolia; then
            echo "SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64" >> .env.broker.eth-sepolia
        fi
        
        if ! grep -q "ORDER_STREAM_URL" .env.broker.eth-sepolia; then
            echo "ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/" >> .env.broker.eth-sepolia
        fi
    else
        # Dosya yoksa oluştur
        cat > .env.broker.eth-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
EOF
    fi
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
    
    # Basitleştirilmiş stake ve deposit kontrolü
    check_and_stake "$private_key" "$rpc_url" "11155111" "0x13337C76fE2d1750246B68781ecEe164643b98Ec" "0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64" "Ethereum Sepolia"
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

# OpenSSL kontrolü ve kurulumu
check_openssl() {
    adim_yazdir "OpenSSL ve bağımlılıkları kontrol ediliyor..."
    
    # pkg-config kontrolü
    if ! command -v pkg-config &> /dev/null; then
        uyari_yazdir "pkg-config bulunamadı, kuruluyor..."
        apt update
        apt install -y pkg-config
    fi
    
    # OpenSSL dev paketleri kontrolü
    if ! pkg-config --exists openssl; then
        uyari_yazdir "OpenSSL development paketleri bulunamadı, kuruluyor..."
        apt update
        apt install -y libssl-dev openssl libssl1.1
    fi
    
    # Environment değişkenlerini ayarla
    export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:$PKG_CONFIG_PATH
    export OPENSSL_DIR=/usr
    export OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu
    export OPENSSL_INCLUDE_DIR=/usr/include/openssl
    
    # OpenSSL versiyonunu göster
    if command -v openssl &> /dev/null; then
        openssl_version=$(openssl version)
        basarili_yazdir "OpenSSL kurulu: $openssl_version"
    fi
    
    # pkg-config ile OpenSSL kontrolü
    if pkg-config --libs openssl &> /dev/null; then
        basarili_yazdir "OpenSSL pkg-config doğrulaması başarılı"
    else
        hata_yazdir "OpenSSL pkg-config ile bulunamadı!"
        exit 1
    fi
}

# OpenSSL kontrolünü çalıştır
check_openssl

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
# Cargo build cache'ini temizle (varsa eski hatalı build'leri temizler)
if [ -d "target" ]; then
    bilgi_yazdir "Eski build dosyaları temizleniyor..."
    cargo clean 2>/dev/null || true
fi
bash ./scripts/setup.sh
basarili_yazdir "Setup scripti tamamlandı"

# GPU sayısını ve modelini tespit et
gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)
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

# GPU modeline göre ayarlar
if [[ $gpu_model == *"3060"* ]] || [[ $gpu_model == *"4060"* ]]; then
    bilgi_yazdir "RTX 3060/4060 tespit edildi - Temel performans ayarları uygulanıyor"
    max_proofs=2
    peak_khz=80
elif [[ $gpu_model == *"3090"* ]]; then
    bilgi_yazdir "RTX 3090 tespit edildi - Yüksek performans ayarları uygulanıyor"
    max_proofs=4
    peak_khz=200
elif [[ $gpu_model == *"4090"* ]]; then
    bilgi_yazdir "RTX 4090 tespit edildi - Ultra yüksek performans ayarları uygulanıyor"
    max_proofs=6
    peak_khz=300
elif [[ $gpu_model == *"3080"* ]]; then
    bilgi_yazdir "RTX 3080 serisi tespit edildi - Optimum performans ayarları uygulanıyor"
    max_proofs=3
    peak_khz=150
elif [[ $gpu_model == *"307"* ]] || [[ $gpu_model == *"306"* ]]; then
    bilgi_yazdir "RTX 3070/3060 serisi tespit edildi - Dengeli performans ayarları uygulanıyor"
    max_proofs=2
    peak_khz=100
else
    bilgi_yazdir "Standart GPU tespit edildi - Varsayılan ayarlar uygulanıyor"
    max_proofs=2
    peak_khz=100
fi

# Multi-GPU için ayarlamaları artır
if [ $gpu_count -gt 1 ]; then
    max_proofs=$((max_proofs * gpu_count))
    peak_khz=$((peak_khz * gpu_count))
fi

# Broker.toml ayarları
sed -i "s/max_concurrent_proofs = .*/max_concurrent_proofs = $max_proofs/" broker.toml
sed -i "s/peak_prove_khz = .*/peak_prove_khz = $peak_khz/" broker.toml

basarili_yazdir "Broker ayarları optimize edildi:"
bilgi_yazdir "  GPU Model: $gpu_model"
bilgi_yazdir "  GPU Sayısı: $gpu_count"
bilgi_yazdir "  Max Concurrent Proofs: $max_proofs"
bilgi_yazdir "  Peak Prove kHz: $peak_khz"

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

# Network'e göre RPC al ve ayarları yap
if [[ $network_secim == "1" ]]; then
    echo -n "Base Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    base_sepolia_ayarla "$private_key" "$rpc_url"
    
    # Environment'ları yükle
    adim_yazdir "Environment dosyaları yükleniyor..."
    source ./.env.base-sepolia
    basarili_yazdir "Base Sepolia environment'ı yüklendi"
    
elif [[ $network_secim == "2" ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read rpc_url
    
    base_mainnet_ayarla "$private_key" "$rpc_url"
    
    # Environment'ları yükle
    adim_yazdir "Environment dosyaları yükleniyor..."
    source ./.env.base
    basarili_yazdir "Base Mainnet environment'ı yüklendi"
    
elif [[ $network_secim == "3" ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    ethereum_sepolia_ayarla "$private_key" "$rpc_url"
    
    # Environment'ları yükle
    adim_yazdir "Environment dosyaları yükleniyor..."
    source ./.env.eth-sepolia
    basarili_yazdir "Ethereum Sepolia environment'ı yüklendi"
    
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

# Network'e göre node başlat
case $network_secim in
    "1")
        bilgi_yazdir "Base Sepolia node'u başlatılıyor..."
        just broker up ./.env.broker.base-sepolia
        ;;
    "2")
        bilgi_yazdir "Base Mainnet node'u başlatılıyor..."
        just broker up ./.env.broker.base
        ;;
    "3")
        bilgi_yazdir "Ethereum Sepolia node'u başlatılıyor..."
        just broker up ./.env.broker.eth-sepolia
        ;;
esac

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
echo "• Maksimum eşzamanlı proof: $max_proofs"
echo "• Peak prove kHz: $peak_khz"
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
