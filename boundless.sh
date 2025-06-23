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

# İlk olarak sistemdeki sorunları düzelt
bilgi_yazdir "Sistem kontrolleri yapılıyor..."

# Broken packages düzeltme
if ! dpkg --configure -a 2>/dev/null; then
    uyari_yazdir "dpkg veritabanı sorunları düzeltiliyor..."
    dpkg --configure -a
fi

# APT lock dosyalarını kontrol et ve temizle
if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    uyari_yazdir "APT lock dosyaları temizleniyor..."
    killall apt apt-get 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/dpkg/lock*
    dpkg --configure -a
fi

# Broken dependencies düzelt
apt-get update 2>/dev/null || {
    uyari_yazdir "APT güncelleme hatası, düzeltiliyor..."
    rm -rf /var/lib/apt/lists/*
    apt-get update
}

# Broken packages varsa düzelt
if ! apt-get check >/dev/null 2>&1; then
    uyari_yazdir "Bozuk paketler tespit edildi, otomatik düzeltiliyor..."
    apt-get install -f -y
    apt-get autoremove -y
    apt-get autoclean
    apt-get update
fi

basarili_yazdir "Sistem kontrolleri tamamlandı"

# GPU sayısını tespit et
gpu_sayisi_tespit() {
    local gpu_count=0
    # Önce nvidia-smi'yi kontrol et
    if command -v nvidia-smi &> /dev/null; then
        # NVML hatası alıyorsak driver yükle
        if nvidia-smi 2>&1 | grep -q "Failed to initialize NVML"; then
            uyari_yazdir "NVIDIA driver sorunu tespit edildi, düzeltiliyor..."
            install_nvidia_drivers
        fi
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    else
        # nvidia-smi yoksa lspci ile kontrol et
        if lspci | grep -i nvidia &> /dev/null; then
            uyari_yazdir "NVIDIA GPU tespit edildi ama driver yüklü değil"
            install_nvidia_drivers
            gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
        fi
    fi
    echo $gpu_count
}

# NVIDIA driver kurulumu
install_nvidia_drivers() {
    bilgi_yazdir "NVIDIA driver kurulumu başlatılıyor..."
    
    # Ubuntu versiyonunu kontrol et
    ubuntu_version=$(lsb_release -rs)
    
    # Driver repository ekle
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:graphics-drivers/ppa
    apt-get update
    
    # Önerilen driver'ı kur
    apt-get install -y ubuntu-drivers-common
    ubuntu-drivers autoinstall
    
    # CUDA toolkit kur (opsiyonel ama önerilir)
    if ! command -v nvcc &> /dev/null; then
        bilgi_yazdir "CUDA toolkit kuruluyor..."
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb
        dpkg -i cuda-keyring_1.1-1_all.deb
        apt-get update
        apt-get -y install cuda-toolkit-12-3
        rm -f cuda-keyring_1.1-1_all.deb
    fi
    
    # nvidia-container-toolkit kur (Docker için gerekli)
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
    apt-get update
    apt-get install -y nvidia-container-toolkit
    systemctl restart docker
    
    basarili_yazdir "NVIDIA driver kurulumu tamamlandı"
    bilgi_yazdir "Driver'ın aktif olması için sistem yeniden başlatılmalı"
}

# GPU modelini tespit et
gpu_model_tespit() {
    if command -v nvidia-smi &> /dev/null; then
        local model=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -z "$model" ]] || [[ "$model" == *"Failed"* ]]; then
            # nvidia-smi başarısızsa lspci'dan almayı dene
            model=$(lspci | grep -i vga | grep -i nvidia | sed 's/.*: //' | head -1)
            [[ -z "$model" ]] && model="Unknown"
        fi
        echo "$model"
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
    local network_name=$1
    local env_file=$2
    
    echo ""
    bilgi_yazdir "$network_name bakiye kontrolü yapılıyor..."
    
    # Environment dosyasını source et
    adim_yazdir "Environment yükleniyor: $env_file"
    source $env_file
    
    # USDC Stake kontrolü
    bilgi_yazdir "USDC stake bakiyesi kontrol ediliyor..."
    stake_balance=$(boundless account stake-balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance < 5" | bc -l 2>/dev/null || echo "1") == 1 )); then
        uyari_yazdir "USDC stake yetersiz veya yok! 5 USDC stake etmek ister misiniz? (y/n): "
        read -r yanit
        if [[ $yanit == "y" || $yanit == "Y" ]]; then
            adim_yazdir "5 USDC stake ediliyor..."
            if boundless account deposit-stake 5; then
                basarili_yazdir "5 USDC stake edildi"
            else
                hata_yazdir "Stake işlemi başarısız! USDC bakiyenizi kontrol edin"
            fi
        else
            bilgi_yazdir "USDC stake işlemi atlandı"
        fi
    else
        basarili_yazdir "✓ USDC Stake OK: $stake_balance USDC"
    fi
    
    # ETH Deposit kontrolü
    bilgi_yazdir "ETH deposit bakiyesi kontrol ediliyor..."
    eth_balance=$(boundless account balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    if [[ -z "$eth_balance" ]] || (( $(echo "$eth_balance < 0.001" | bc -l 2>/dev/null || echo "1") == 1 )); then
        uyari_yazdir "ETH deposit yetersiz veya yok! 0.001 ETH deposit etmek ister misiniz? (y/n): "
        read -r yanit
        if [[ $yanit == "y" || $yanit == "Y" ]]; then
            adim_yazdir "0.001 ETH deposit ediliyor..."
            if boundless account deposit 0.001; then
                basarili_yazdir "0.001 ETH deposit edildi"
            else
                hata_yazdir "Deposit işlemi başarısız! ETH bakiyenizi kontrol edin"
            fi
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
        cat > .env.base-sepolia << 'ENVEOF'
export PRIVATE_KEY=PRIVATE_KEY_PLACEHOLDER
export RPC_URL="RPC_URL_PLACEHOLDER"
ENVEOF
        sed -i "s/PRIVATE_KEY_PLACEHOLDER/$private_key/" .env.base-sepolia
        sed -i "s/RPC_URL_PLACEHOLDER/$rpc_url/" .env.base-sepolia
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
        cat > .env.broker.base-sepolia << 'BROKEREOF'
PRIVATE_KEY=PRIVATE_KEY_PLACEHOLDER
BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=RPC_URL_PLACEHOLDER
ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
BROKEREOF
        sed -i "s/PRIVATE_KEY_PLACEHOLDER/$private_key/" .env.broker.base-sepolia
        sed -i "s/RPC_URL_PLACEHOLDER/$rpc_url/" .env.broker.base-sepolia
    fi
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
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
        cat > .env.base << 'BASEEOF'
export PRIVATE_KEY=PRIVATE_KEY_PLACEHOLDER
export RPC_URL="RPC_URL_PLACEHOLDER"
BASEEOF
        sed -i "s/PRIVATE_KEY_PLACEHOLDER/$private_key/" .env.base
        sed -i "s/RPC_URL_PLACEHOLDER/$rpc_url/" .env.base
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
        cat > .env.broker.base << 'BASEMAINEOF'
PRIVATE_KEY=PRIVATE_KEY_PLACEHOLDER
BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=RPC_URL_PLACEHOLDER
ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
BASEMAINEOF
        sed -i "s/PRIVATE_KEY_PLACEHOLDER/$private_key/" .env.broker.base
        sed -i "s/RPC_URL_PLACEHOLDER/$rpc_url/" .env.broker.base
    fi
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
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
        cat > .env.eth-sepolia << 'ETHEOF'
export PRIVATE_KEY=PRIVATE_KEY_PLACEHOLDER
export RPC_URL="RPC_URL_PLACEHOLDER"
ETHEOF
        sed -i "s/PRIVATE_KEY_PLACEHOLDER/$private_key/" .env.eth-sepolia
        sed -i "s/RPC_URL_PLACEHOLDER/$rpc_url/" .env.eth-sepolia
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
        cat > .env.broker.eth-sepolia << 'ETHSEPOLIAEOF'
PRIVATE_KEY=PRIVATE_KEY_PLACEHOLDER
BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
RPC_URL=RPC_URL_PLACEHOLDER
ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
ETHSEPOLIAEOF
        sed -i "s/PRIVATE_KEY_PLACEHOLDER/$private_key/" .env.broker.eth-sepolia
        sed -i "s/RPC_URL_PLACEHOLDER/$rpc_url/" .env.broker.eth-sepolia
    fi
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
}

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
        apt install -y libssl-dev openssl || {
            # Eğer hata alırsak alternatif yöntem
            uyari_yazdir "libssl-dev kurulamadı, alternatif paketler deneniyor..."
            apt install -y libssl1.1 libssl1.1-dev || apt install -y libssl3 libssl-dev
        }
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

if [ $gpu_count -eq 0 ]; then
    uyari_yazdir "GPU tespit edilemedi! CPU modunda çalışacak"
    bilgi_yazdir "Performans düşük olabilir."
    echo ""
    echo -e "${YELLOW}GPU'nuz varsa lütfen sistemi yeniden başlatın ve script'i tekrar çalıştırın:${NC}"
    echo -e "${CYAN}sudo reboot${NC}"
    echo ""
    echo "CPU modunda devam etmek istiyor musunuz? (y/n)"
    read -p "Yanıt: " cpu_devam
    if [[ $cpu_devam != "y" && $cpu_devam != "Y" ]]; then
        bilgi_yazdir "Script sonlandırılıyor. Reboot sonrası tekrar deneyin."
        exit 0
    fi
else
    bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"
fi

# 5. Just broker komutunu çalıştır (temel bileşenleri yüklemek için)
if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı! Setup.sh başarılı çalıştığından emin olun."
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

adim_yazdir "'just broker' komutu çalıştırılıyor..."
just broker
basarili_yazdir "'just broker' komutu başarıyla çalıştırıldı!"

# Yükleme tamamlandıktan sonra durdur
adim_yazdir "Temel yükleme tamamlandı, broker durduruluyor..."
just broker down
basarili_yazdir "Broker başarıyla durduruldu"

# PostgreSQL kurulumu ve benchmark testi
adim_yazdir "PostgreSQL kuruluyor ve benchmark testi yapılıyor..."

# PostgreSQL kurulumu
apt update
apt install -y postgresql postgresql-client

# PostgreSQL versiyonunu kontrol et
if command -v psql &> /dev/null; then
    psql_version=$(psql --version)
    bilgi_yazdir "PostgreSQL kuruldu: $psql_version"
else
    hata_yazdir "PostgreSQL kurulumu başarısız!"
    exit 1
fi

# Benchmark testi yap - environment yüklenmeden önce genel test
bilgi_yazdir "Proving benchmark testi başlatılıyor..."
bilgi_yazdir "Bu işlem birkaç dakika sürebilir, lütfen bekleyiniz..."

# Test için örnek request ID'leri kullan (bu genellikle standart test ID'leridir)
test_request_ids="1,2,3"

# Benchmark testini çalıştır ve sonucu yakala
benchmark_result=$(boundless proving benchmark --request-ids $test_request_ids 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | tail -1)

if [[ -z "$benchmark_result" ]] || [[ "$benchmark_result" == "0" ]]; then
    uyari_yazdir "Benchmark testi başarısız veya sonuç alınamadı"
    bilgi_yazdir "GPU modeline göre varsayılan değerler kullanılacak"
    
    # GPU modeline göre varsayılan peak_khz değerleri
    if [[ $gpu_model == *"4090"* ]]; then
        optimal_peak_khz=280
    elif [[ $gpu_model == *"3090"* ]]; then
        optimal_peak_khz=180
    elif [[ $gpu_model == *"4080"* ]] || [[ $gpu_model == *"3080"* ]]; then
        optimal_peak_khz=130
    elif [[ $gpu_model == *"4070"* ]] || [[ $gpu_model == *"3070"* ]]; then
        optimal_peak_khz=80
    elif [[ $gpu_model == *"4060"* ]] || [[ $gpu_model == *"3060"* ]]; then
        optimal_peak_khz=60
    else
        optimal_peak_khz=50
    fi
else
    # Benchmark sonucundan 20 düşük değer al
    optimal_peak_khz=$((benchmark_result - 20))
    
    # Minimum değer kontrolü
    if [[ $optimal_peak_khz -lt 10 ]]; then
        optimal_peak_khz=10
    fi
    
    basarili_yazdir "Benchmark testi tamamlandı: $benchmark_result kHz"
    bilgi_yazdir "Optimal peak_prove_khz değeri: $optimal_peak_khz kHz"
fi

# GPU modeline göre broker.toml ayarları
adim_yazdir "Broker.toml dosyası GPU modeline göre optimize ediliyor..."

# GPU modeline göre max_mcycle_limit ve max_concurrent_proofs ayarları
if [[ $gpu_model == *"4090"* ]]; then
    max_concurrent_proofs=6
    max_mcycle_limit=15000
    locking_priority_gas=800000
    mcycle_price="0.0000002"
    min_deadline=200
elif [[ $gpu_model == *"3090"* ]]; then
    max_concurrent_proofs=4
    max_mcycle_limit=12000
    locking_priority_gas=800000
    mcycle_price="0.0000002"
    min_deadline=200
elif [[ $gpu_model == *"4080"* ]] || [[ $gpu_model == *"3080"* ]]; then
    max_concurrent_proofs=3
    max_mcycle_limit=11000
    locking_priority_gas=800000
    mcycle_price="0.0000002"
    min_deadline=250
elif [[ $gpu_model == *"4070"* ]] || [[ $gpu_model == *"3070"* ]]; then
    max_concurrent_proofs=2
    max_mcycle_limit=10000
    locking_priority_gas=800000
    mcycle_price="0.0000002"
    min_deadline=300
else
    # Düşük seviye GPU'lar veya CPU
    max_concurrent_proofs=1
    max_mcycle_limit=10000
    locking_priority_gas=800000
    mcycle_price="0.0000002"
    min_deadline=400
fi

# Multi-GPU için ayarlamaları artır
if [ $gpu_count -gt 1 ]; then
    max_concurrent_proofs=$((max_concurrent_proofs * gpu_count))
fi

# broker.toml dosyasını güncelle (eğer varsa)
if [[ -f "broker.toml" ]]; then
    bilgi_yazdir "Broker.toml dosyası güncelleniyor..."
    
    # Önce mevcut ayarları temizle (# ile başlayanları da)
    sed -i '/^#*peak_prove_khz/d' broker.toml
    sed -i '/^#*max_concurrent_proofs/d' broker.toml
    sed -i '/^#*max_mcycle_limit/d' broker.toml
    sed -i '/^#*locking_priority_gas/d' broker.toml
    sed -i '/^#*mcycle_price/d' broker.toml
    sed -i '/^#*min_deadline/d' broker.toml

    # Yeni optimized ayarları ekle - echo ile daha güvenli
    echo "" >> broker.toml
    echo "# GPU Optimized Settings" >> broker.toml
    echo "peak_prove_khz = $optimal_peak_khz" >> broker.toml
    echo "max_concurrent_proofs = $max_concurrent_proofs" >> broker.toml
    echo "max_mcycle_limit = $max_mcycle_limit" >> broker.toml
    echo "locking_priority_gas = $locking_priority_gas" >> broker.toml
    echo "mcycle_price = \"$mcycle_price\"" >> broker.toml
    echo "min_deadline = $min_deadline" >> broker.toml
    
    basarili_yazdir "Broker.toml GPU optimizasyonu tamamlandı"
else
    bilgi_yazdir "broker.toml dosyası henüz oluşturulmadı, ayarlar daha sonra uygulanacak"
fi

bilgi_yazdir "GPU Optimizasyon Ayarları:"
bilgi_yazdir "  GPU Model: $gpu_model"
bilgi_yazdir "  GPU Sayısı: $gpu_count"
bilgi_yazdir "  Peak Prove kHz: $optimal_peak_khz"
bilgi_yazdir "  Max Concurrent Proofs: $max_concurrent_proofs"
bilgi_yazdir "  Max Mcycle Limit: $max_mcycle_limit"
bilgi_yazdir "  Locking Priority Gas: $locking_priority_gas"
bilgi_yazdir "  Mcycle Price: $mcycle_price"
bilgi_yazdir "  Min Deadline: $min_deadline"

# 6. Şimdi network seçimi ve .env dosyalarını ayarla
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
    selected_env=".env.base-sepolia"
    selected_broker_env=".env.broker.base-sepolia"
    network_name="Base Sepolia"
    
elif [[ $network_secim == "2" ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read rpc_url
    
    base_mainnet_ayarla "$private_key" "$rpc_url"
    selected_env=".env.base"
    selected_broker_env=".env.broker.base"
    network_name="Base Mainnet"
    
elif [[ $network_secim == "3" ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    ethereum_sepolia_ayarla "$private_key" "$rpc_url"
    selected_env=".env.eth-sepolia"
    selected_broker_env=".env.broker.eth-sepolia"
    network_name="Ethereum Sepolia"
    
else
    hata_yazdir "Geçersiz seçim! Lütfen 1, 2 veya 3 seçin."
    exit 1
fi

# 7. Network seçimine göre environment'ları yükle
adim_yazdir "Environment dosyaları yükleniyor..."

# Önce genel environment'ları yükle
environment_yukle

# Network seçimine göre doğru environment'ı source et
case $network_secim in
    "1")
        bilgi_yazdir "Base Sepolia environment'ı yükleniyor..."
        source ./.env.base-sepolia
        basarili_yazdir "Base Sepolia environment'ı yüklendi"
        ;;
    "2")
        bilgi_yazdir "Base Mainnet environment'ı yükleniyor..."
        source ./.env.base
        basarili_yazdir "Base Mainnet environment'ı yüklendi"
        ;;
    "3")
        bilgi_yazdir "Ethereum Sepolia environment'ı yükleniyor..."
        source ./.env.eth-sepolia
        basarili_yazdir "Ethereum Sepolia environment'ı yüklendi"
        ;;
esac

# 8. Network seçimine göre stake ve deposit kontrolü
case $network_secim in
    "1")
        check_and_stake "Base Sepolia" ".env.base-sepolia"
        ;;
    "2")
        check_and_stake "Base Mainnet" ".env.base"
        ;;
    "3")
        check_and_stake "Ethereum Sepolia" ".env.eth-sepolia"
        ;;
esac

# 9. Node'u başlat - Network seçimine göre
adim_yazdir "Node başlatılıyor..."

case $network_secim in
    "1")
        bilgi_yazdir "Base Sepolia node'u başlatılıyor..."
        just broker up ./.env.broker.base-sepolia
        network_display="Base Sepolia"
        ;;
    "2")
        bilgi_yazdir "Base Mainnet node'u başlatılıyor..."
        just broker up ./.env.broker.base
        network_display="Base Mainnet"
        ;;
    "3")
        bilgi_yazdir "Ethereum Sepolia node'u başlatılıyor..."
        just broker up ./.env.broker.eth-sepolia
        network_display="Ethereum Sepolia"
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
echo ""
echo "Node Kontrolü:"
case $network_secim in
    "1")
        echo "• Node'u durdur: just broker down ./.env.broker.base-sepolia"
        echo "• Node'u başlat: just broker up ./.env.broker.base-sepolia"
        ;;
    "2")
        echo "• Node'u durdur: just broker down ./.env.broker.base"
        echo "• Node'u başlat: just broker up ./.env.broker.base"
        ;;
    "3")
        echo "• Node'u durdur: just broker down ./.env.broker.eth-sepolia"
        echo "• Node'u başlat: just broker up ./.env.broker.eth-sepolia"
        ;;
esac
echo ""
echo "GPU Konfigürasyonu:"
echo "• Tespit edilen GPU: $gpu_model"
echo "• GPU Sayısı: $gpu_count"
echo "• Optimal Peak Prove kHz: $optimal_peak_khz"
echo "• Maksimum eşzamanlı proof: $max_concurrent_proofs"
echo "• Max Mcycle Limit: $max_mcycle_limit"
echo ""
echo "$network_display ağında mining başladı!"
echo ""
echo "Node'unuz şimdi mining yapıyor! Logları kontrol edin."
