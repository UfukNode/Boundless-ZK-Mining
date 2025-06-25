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

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}  Bu Script UFUKDEGEN Tarafından Hazırlanmıştır  ${NC}"
echo -e "${PURPLE}=================================================${NC}"
echo ""

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   hata_yazdir "Bu script root yetkisi ile çalıştırılmalıdır!"
   echo "Lütfen 'sudo ./boundless.sh' şeklinde çalıştırın"
   exit 1
fi

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

# Otomatik stake ve deposit işlemleri
otomatik_stake_deposit() {
    local env_file=$1
    local network_name=$2
    
    echo ""
    bilgi_yazdir "$network_name için stake ve deposit işlemleri başlatılıyor..."
    
    # Environment dosyasını yükle
    adim_yazdir "Environment dosyası yükleniyor..."
    source "$env_file"
    source ~/.bashrc
    basarili_yazdir "Environment dosyası yüklendi"
    
    # 10 USDC stake et
    adim_yazdir "10 USDC stake ediliyor..."
    if boundless account deposit-stake 10; then
        basarili_yazdir "10 USDC başarıyla stake edildi"
    else
        uyari_yazdir "USDC stake işleminde sorun oldu, devam ediliyor..."
    fi
    
    # 0.001 ETH deposit et
    adim_yazdir "0.001 ETH deposit ediliyor..."
    if boundless account deposit 0.001; then
        basarili_yazdir "0.001 ETH başarıyla deposit edildi"
    else
        uyari_yazdir "ETH deposit işleminde sorun oldu, devam ediliyor..."
    fi
    
    echo ""
    basarili_yazdir "Stake ve deposit işlemleri tamamlandı"
}

# Base Sepolia ayarları
base_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Ana .env.base-sepolia dosyasını güncelle/oluştur
    if [[ -f ".env.base-sepolia" ]]; then
        # Mevcut dosyayı backup al
        cp .env.base-sepolia .env.base-sepolia.backup
        
        # PRIVATE_KEY ve RPC_URL satırlarını güncelle
        if grep -q "^export PRIVATE_KEY=" .env.base-sepolia; then
            sed -i "s|^export PRIVATE_KEY=.*|export PRIVATE_KEY=$private_key|" .env.base-sepolia
        else
            echo "export PRIVATE_KEY=$private_key" >> .env.base-sepolia
        fi
        
        if grep -q "^export RPC_URL=" .env.base-sepolia; then
            sed -i "s|^export RPC_URL=.*|export RPC_URL=\"$rpc_url\"|" .env.base-sepolia
        else
            echo "export RPC_URL=\"$rpc_url\"" >> .env.base-sepolia
        fi
    else
        # Dosya yoksa mevcut içerikle birlikte oluştur
        cat > .env.base-sepolia << EOF
export BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
export RPC_URL="$rpc_url"
EOF
    fi
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
}

# Base Mainnet ayarları
base_mainnet_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Ana .env.base dosyasını güncelle/oluştur
    if [[ -f ".env.base" ]]; then
        # Mevcut dosyayı backup al
        cp .env.base .env.base.backup
        
        # PRIVATE_KEY ve RPC_URL satırlarını güncelle
        if grep -q "^export PRIVATE_KEY=" .env.base; then
            sed -i "s|^export PRIVATE_KEY=.*|export PRIVATE_KEY=$private_key|" .env.base
        else
            echo "export PRIVATE_KEY=$private_key" >> .env.base
        fi
        
        if grep -q "^export RPC_URL=" .env.base; then
            sed -i "s|^export RPC_URL=.*|export RPC_URL=\"$rpc_url\"|" .env.base
        else
            echo "export RPC_URL=\"$rpc_url\"" >> .env.base
        fi
    else
        # Dosya yoksa mevcut içerikle birlikte oluştur
        cat > .env.base << EOF
export BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
export RPC_URL="$rpc_url"
EOF
    fi
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
}

# Ethereum Sepolia ayarları
ethereum_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Ana .env.eth-sepolia dosyasını güncelle/oluştur
    if [[ -f ".env.eth-sepolia" ]]; then
        # Mevcut dosyayı backup al
        cp .env.eth-sepolia .env.eth-sepolia.backup
        
        # PRIVATE_KEY ve RPC_URL satırlarını güncelle
        if grep -q "^export PRIVATE_KEY=" .env.eth-sepolia; then
            sed -i "s|^export PRIVATE_KEY=.*|export PRIVATE_KEY=$private_key|" .env.eth-sepolia
        else
            echo "export PRIVATE_KEY=$private_key" >> .env.eth-sepolia
        fi
        
        if grep -q "^export RPC_URL=" .env.eth-sepolia; then
            sed -i "s|^export RPC_URL=.*|export RPC_URL=\"$rpc_url\"|" .env.eth-sepolia
        else
            echo "export RPC_URL=\"$rpc_url\"" >> .env.eth-sepolia
        fi
    else
        # Dosya yoksa mevcut içerikle birlikte oluştur
        cat > .env.eth-sepolia << EOF
export BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
export SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
export RPC_URL="$rpc_url"
EOF
    fi
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
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

# 5. İlk broker başlatma - dosyaları indirmek için
adim_yazdir "Docker imajları indiriliyor..."

if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı! Setup.sh başarılı çalıştığından emin olun."
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

# Geçici .env dosyası ile imajları indir
echo "export PRIVATE_KEY=temp" > .env.temp
echo "export RPC_URL=temp" >> .env.temp

bilgi_yazdir "Docker imajları indiriliyor... (Bu işlem birkaç dakika sürebilir)"
source .env.temp
timeout 120 just broker &
download_pid=$!

# İndirme işleminin tamamlanmasını bekle
sleep 60
bilgi_yazdir "Docker imajları indirildi, containers durduruluyor..."

# Containers'ı durdur
just broker down 2>/dev/null || true
kill $download_pid 2>/dev/null || true

# Geçici dosyayı sil
rm -f .env.temp

basarili_yazdir "Docker imajları hazır"

# 6. Network seçimi ve .env dosyalarını ayarla
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
    env_file=".env.base-sepolia"
    network_name="Base Sepolia"
    
elif [[ $network_secim == "2" ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read rpc_url
    
    base_mainnet_ayarla "$private_key" "$rpc_url"
    env_file=".env.base"
    network_name="Base Mainnet"
    
elif [[ $network_secim == "3" ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    ethereum_sepolia_ayarla "$private_key" "$rpc_url"
    env_file=".env.eth-sepolia"
    network_name="Ethereum Sepolia"
    
else
    hata_yazdir "Geçersiz seçim! Lütfen 1, 2 veya 3 seçin."
    exit 1
fi

# 7. Environment'ları yükle
environment_yukle

# 8. Otomatik stake ve deposit işlemleri
otomatik_stake_deposit "$env_file" "$network_name"

echo ""
echo "========================================="
echo "       KURULUM TAMAMLANDI!"
echo "========================================="
echo ""
echo "GPU Konfigürasyonu:"
echo "• Tespit edilen GPU: $gpu_model"
echo "• GPU Sayısı: $gpu_count"
echo "• Maksimum eşzamanlı proof: $max_proofs"
echo "• Peak prove kHz: $peak_khz"
echo ""
echo "Seçilen Ağ: $network_name"
echo "Environment Dosyası: $env_file"
echo ""

echo "Node'u başlatmak için:"
case $network_secim in
    "1")
        echo -e "${GREEN}source .env.base-sepolia && just broker${NC}"
        ;;
    "2")
        echo -e "${GREEN}source .env.base && just broker${NC}"
        ;;
    "3")
        echo -e "${GREEN}source .env.eth-sepolia && just broker${NC}"
        ;;
esac

echo ""
echo "Yararlı komutlar:"
echo "• Logları kontrol et: docker compose logs -f broker"
echo "• Stake bakiyesi: boundless account stake-balance"
echo "• Node'u durdur: just broker down"
echo ""
echo "Node'u başlatmak istiyor musunuz? (y/n)"
read -p "Yanıt: " start_node

if [[ $start_node == "y" || $start_node == "Y" ]]; then
    case $network_secim in
        "1")
            source .env.base-sepolia
            just broker
            ;;
        "2")
            source .env.base
            just broker
            ;;
        "3")
            source .env.eth-sepolia
            just broker
            ;;
    esac
fi
