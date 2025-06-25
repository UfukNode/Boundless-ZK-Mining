#!/bin/bash

# Boundless ZK Mining Otomatik Kurulum
# Hata yönetimi ile güvenli kurulum

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Sabit değişkenler
INSTALL_DIR="$HOME/boundless"
LOG_FILE="/var/log/boundless_setup.log"
ERROR_LOG="/var/log/boundless_error.log"

# Hata yakalama
cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        hata_yazdir "Kurulum başarısız! Exit code: $exit_code"
        echo "[ERROR] $(date) - Script failed with exit code: $exit_code" >> "$ERROR_LOG"
        echo "Hata logları: $ERROR_LOG" 
    fi
}

trap cleanup_on_exit EXIT

adim_yazdir() {
    echo -e "${BLUE}[ADIM]${NC} $1"
    echo "[INFO] $(date) - $1" >> "$LOG_FILE"
}

basarili_yazdir() {
    echo -e "${GREEN}[BASARILI]${NC} $1"
    echo "[SUCCESS] $(date) - $1" >> "$LOG_FILE"
}

uyari_yazdir() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
    echo "[WARNING] $(date) - $1" >> "$LOG_FILE"
}

hata_yazdir() {
    echo -e "${RED}[HATA]${NC} $1" >&2
    echo "[ERROR] $(date) - $1" >> "$ERROR_LOG"
}

bilgi_yazdir() {
    echo -e "${CYAN}[BILGI]${NC} $1"
    echo "[INFO] $(date) - $1" >> "$LOG_FILE"
}

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}  Bu Script UFUKDEGEN Tarafından Hazırlanmıştır  ${NC}"
echo -e "${PURPLE}=================================================${NC}"
echo ""

# Log dosyalarını oluştur
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" "$ERROR_LOG"

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   hata_yazdir "Bu script root yetkisi ile çalıştırılmalıdır!"
   echo "Lütfen 'sudo ./boundless.sh' şeklinde çalıştırın"
   exit 1
fi

# Sistem PostgreSQL'ini durdur (port çakışmasını önle)
stop_system_postgresql() {
    adim_yazdir "Sistem PostgreSQL'i kontrol ediliyor..."
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        uyari_yazdir "Sistem PostgreSQL'i durduruluyor (port çakışmasını önlemek için)..."
        systemctl stop postgresql 2>/dev/null || true
        systemctl disable postgresql 2>/dev/null || true
    fi
    
    # Port 5432'yi kullanan process'leri durdur
    if lsof -i :5432 >/dev/null 2>&1; then
        uyari_yazdir "Port 5432'yi kullanan process'ler durduruluyor..."
        pkill -f postgres 2>/dev/null || true
        sleep 2
    fi
    
    basarili_yazdir "PostgreSQL port çakışması önlendi"
}

# DPKG durumunu kontrol et
check_dpkg_status() {
    if dpkg --audit 2>&1 | grep -q "dpkg was interrupted"; then
        hata_yazdir "dpkg kesintiye uğradı - manuel müdahale gerekli"
        echo "Lütfen şu komutu çalıştırın: dpkg --configure -a"
        exit 1
    fi
}

# GPU tespit fonksiyonları
gpu_sayisi_tespit() {
    local gpu_count=0
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi 2>&1 | grep -q "Failed to initialize NVML"; then
            uyari_yazdir "NVIDIA driver sorunu tespit edildi"
            return 0
        fi
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    fi
    echo $gpu_count
}

gpu_model_tespit() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "Unknown"
    else
        echo "Unknown"
    fi
}

# Environment yükleme fonksiyonu
environment_yukle() {
    adim_yazdir "Environment'lar yükleniyor..."
    
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

# Otomatik stake ve deposit
otomatik_stake_deposit() {
    local env_file=$1
    local network_name=$2
    
    echo ""
    bilgi_yazdir "$network_name için otomatik stake ve deposit işlemleri..."
    
    # Environment yükle
    source "$env_file" 2>/dev/null || {
        uyari_yazdir "Environment dosyası yüklenemedi: $env_file"
        return 1
    }
    
    # Boundless komutunu kontrol et
    if ! command -v boundless &> /dev/null; then
        uyari_yazdir "boundless komutu bulunamadı, environment yeniden yükleniyor..."
        environment_yukle
    fi
    
    # USDC Stake kontrolü
    bilgi_yazdir "USDC stake bakiyesi kontrol ediliyor..."
    stake_balance=$(boundless account stake-balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1 || echo "0")
    
    if (( $(echo "$stake_balance < 5" | bc -l 2>/dev/null || echo "1") == 1 )); then
        adim_yazdir "5 USDC otomatik stake ediliyor..."
        if boundless account deposit-stake 5 2>/dev/null; then
            basarili_yazdir "5 USDC başarıyla stake edildi"
        else
            uyari_yazdir "USDC stake başarısız - cüzdan bakiyenizi kontrol edin"
        fi
    else
        basarili_yazdir "✓ USDC Stake OK: $stake_balance USDC"
    fi
    
    # ETH Deposit kontrolü
    bilgi_yazdir "ETH deposit bakiyesi kontrol ediliyor..."
    eth_balance=$(boundless account balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1 || echo "0")
    
    if (( $(echo "$eth_balance < 0.001" | bc -l 2>/dev/null || echo "1") == 1 )); then
        adim_yazdir "0.001 ETH otomatik deposit ediliyor..."
        if boundless account deposit 0.001 2>/dev/null; then
            basarili_yazdir "0.001 ETH başarıyla deposit edildi"
        else
            uyari_yazdir "ETH deposit başarısız - cüzdan bakiyenizi kontrol edin"
        fi
    else
        basarili_yazdir "✓ ETH Deposit OK: $eth_balance ETH"
    fi
    
    basarili_yazdir "Stake ve deposit kontrolleri tamamlandı"
}

# Network ayarlama fonksiyonları
base_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    cat > "$INSTALL_DIR/.env.base-sepolia" << EOF
export BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
export RPC_URL="$rpc_url"
EOF

    chmod 600 "$INSTALL_DIR/.env.base-sepolia"
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
}

base_mainnet_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    cat > "$INSTALL_DIR/.env.base" << EOF
export BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
export RPC_URL="$rpc_url"
EOF

    chmod 600 "$INSTALL_DIR/.env.base"
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
}

ethereum_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    cat > "$INSTALL_DIR/.env.eth-sepolia" << EOF
export BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
export SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
export RPC_URL="$rpc_url"
EOF

    chmod 600 "$INSTALL_DIR/.env.eth-sepolia"
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
}

# Broker.toml oluşturma (sabit ayarlar)
create_broker_config() {
    adim_yazdir "Broker.toml dosyası oluşturuluyor..."
    
    cat > "$INSTALL_DIR/broker.toml" << 'EOF'
# Sabit Broker Ayarları
peak_prove_khz = 300
max_concurrent_proofs = 2
max_mcycle_limit = 25000
locking_priority_gas = 0
mcycle_price = "0.00000000000000015"
min_deadline = 350
EOF

    chmod 644 "$INSTALL_DIR/broker.toml"
    basarili_yazdir "Broker.toml dosyası oluşturuldu"
    
    bilgi_yazdir "Broker Ayarları:"
    bilgi_yazdir "  Peak Prove kHz: 300"
    bilgi_yazdir "  Max Concurrent Proofs: 2"
    bilgi_yazdir "  Max Mcycle Limit: 25000"
    bilgi_yazdir "  Locking Priority Gas: 0"
    bilgi_yazdir "  Mcycle Price: 0.00000000000000015"
    bilgi_yazdir "  Min Deadline: 350"
}

# Ana kurulum başlangıcı
adim_yazdir "Kurulum başlatılıyor..."

# Sistem PostgreSQL'ini durdur
stop_system_postgresql

# 1. Sistem güncelleme
adim_yazdir "Sistem güncelleniyor..."
check_dpkg_status
{
    apt update -y
    apt upgrade -y
} >> "$LOG_FILE" 2>&1
basarili_yazdir "Sistem güncellemeleri tamamlandı"

# 2. Gerekli paketler
adim_yazdir "Gerekli paketler kuruluyor..."
{
    apt install -y build-essential clang gcc make cmake pkg-config autoconf automake ninja-build
    apt install -y curl wget git tar unzip lz4 jq htop tmux nano ncdu iptables nvme-cli bsdmainutils
    apt install -y libssl-dev libleveldb-dev libclang-dev libgbm1 bc postgresql-client
} >> "$LOG_FILE" 2>&1
basarili_yazdir "Gerekli paketler kuruldu"

# 3. Bağımlılıklar
adim_yazdir "Gerekli bağımlılıklar kuruluyor..."
bash <(curl -s https://raw.githubusercontent.com/UfukNode/Boundless-ZK-Mining/refs/heads/main/gerekli_bagimliliklar.sh) >> "$LOG_FILE" 2>&1
basarili_yazdir "Bağımlılıklar kuruldu"

# 4. Repository klonlama
adim_yazdir "Boundless repository klonlanıyor..."
if [[ -d "$INSTALL_DIR" ]]; then
    uyari_yazdir "Mevcut dizin bulundu, güncelleniyor..."
    cd "$INSTALL_DIR"
    git pull origin release-0.10 >> "$LOG_FILE" 2>&1
else
    {
        git clone https://github.com/boundless-xyz/boundless "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        git checkout release-0.10
    } >> "$LOG_FILE" 2>&1
fi
basarili_yazdir "Repository hazırlandı"

# 5. Setup script
adim_yazdir "Setup scripti çalıştırılıyor..."
bash ./scripts/setup.sh >> "$LOG_FILE" 2>&1
basarili_yazdir "Setup scripti tamamlandı"

# 6. GPU tespit
gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)
bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"

# 7. İlk just broker komutu (sistem hazırlığı)
adim_yazdir "Sistem bileşenleri yükleniyor..."

if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı!"
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

# İlk just broker çalıştır
just broker >> "$LOG_FILE" 2>&1 &
broker_pid=$!

# 30 saniye bekle, sonra durdur
sleep 30
just broker down >> "$LOG_FILE" 2>&1
wait $broker_pid 2>/dev/null || true

basarili_yazdir "Sistem bileşenleri hazırlandı"

# 8. Broker.toml oluştur
create_broker_config

# 9. Network seçimi
adim_yazdir "Network yapılandırması..."

echo ""
echo -e "${PURPLE}Hangi ağda prover çalıştırmak istiyorsunuz:${NC}"
echo "1. Base Sepolia (Test ağı)"
echo "2. Base Mainnet"
echo "3. Ethereum Sepolia"
echo ""
read -p "Seçiminizi girin (1/2/3): " network_secim

# Kullanıcı bilgilerini al
echo ""
echo "Lütfen aşağıdaki bilgileri girin:"
echo ""

echo -n "Private Key'inizi girin: "
read -s private_key
echo ""

while [[ -z "$private_key" ]]; do
    hata_yazdir "Private key boş olamaz!"
    echo -n "Private Key'inizi tekrar girin: "
    read -s private_key
    echo ""
done

# Private key doğrulama
if [[ ! "$private_key" =~ ^[0-9a-fA-F]{64}$ ]]; then
    hata_yazdir "Geçersiz private key formatı! 64 hex karakter olmalı."
    exit 1
fi

bilgi_yazdir "Private key alındı"

# Network ayarları
case $network_secim in
    1)
        echo -n "Base Sepolia RPC URL'nizi girin: "
        read rpc_url
        base_sepolia_ayarla "$private_key" "$rpc_url"
        env_file="$INSTALL_DIR/.env.base-sepolia"
        network_name="Base Sepolia"
        ;;
    2)
        echo -n "Base Mainnet RPC URL'nizi girin: "
        read rpc_url
        base_mainnet_ayarla "$private_key" "$rpc_url"
        env_file="$INSTALL_DIR/.env.base"
        network_name="Base Mainnet"
        ;;
    3)
        echo -n "Ethereum Sepolia RPC URL'nizi girin: "
        read rpc_url
        ethereum_sepolia_ayarla "$private_key" "$rpc_url"
        env_file="$INSTALL_DIR/.env.eth-sepolia"
        network_name="Ethereum Sepolia"
        ;;
    *)
        hata_yazdir "Geçersiz seçim!"
        exit 1
        ;;
esac

# 10. Environment yükle
environment_yukle

# 11. Otomatik stake ve deposit
otomatik_stake_deposit "$env_file" "$network_name"

# 12. Final node başlatma
adim_yazdir "Node başlatılıyor..."

case $network_secim in
    1)
        bilgi_yazdir "Base Sepolia environment'ı yükleniyor ve node başlatılıyor..."
        source "$INSTALL_DIR/.env.base-sepolia"
        ;;
    2)
        bilgi_yazdir "Base Mainnet environment'ı yükleniyor ve node başlatılıyor..."
        source "$INSTALL_DIR/.env.base"
        ;;
    3)
        bilgi_yazdir "Ethereum Sepolia environment'ı yükleniyor ve node başlatılıyor..."
        source "$INSTALL_DIR/.env.eth-sepolia"
        ;;
esac

# Final broker başlatma
just broker

echo ""
echo "========================================="
echo "       KURULUM TAMAMLANDI!"
echo "========================================="
echo ""
echo "Yararlı komutlar:"
echo "• Logları kontrol et: docker compose logs -f broker"
echo "• Stake bakiyesi: boundless account stake-balance"
echo ""
echo "Node Kontrolü:"
case $network_secim in
    1)
        echo "• Node'u durdur: just broker down"
        echo "• Node'u başlat: source $INSTALL_DIR/.env.base-sepolia && just broker"
        ;;
    2)
        echo "• Node'u durdur: just broker down"
        echo "• Node'u başlat: source $INSTALL_DIR/.env.base && just broker"
        ;;
    3)
        echo "• Node'u durdur: just broker down"
        echo "• Node'u başlat: source $INSTALL_DIR/.env.eth-sepolia && just broker"
        ;;
esac
echo ""
echo "GPU Konfigürasyonu:"
echo "• Tespit edilen GPU: $gpu_model"
echo "• GPU Sayısı: $gpu_count"
echo ""
echo "$network_name ağında mining başladı!"
echo ""
echo "Node'unuz şimdi mining yapıyor! Logları kontrol edin."
echo ""
echo "Log dosyaları:"
echo "• Kurulum log: $LOG_FILE"
echo "• Hata log: $ERROR_LOG"
