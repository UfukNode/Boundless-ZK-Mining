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
    # CPU modu için varsayılan ayarlar
    max_proofs=1
    peak_khz=50
else
    bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"
    
    # GPU'ya göre broker ayarlarını optimize et
    adim_yazdir "Broker ayarları GPU modeli ve sayısına göre optimize ediliyor..."
fi

# Broker template dosyasını kontrol et ve oluştur
if [[ ! -f "broker-template.toml" ]]; then
    bilgi_yazdir "broker-template.toml bulunamadı, oluşturuluyor..."
    cat > broker-template.toml << 'EOF'
max_concurrent_proofs = 2
peak_prove_khz = 100
EOF
fi

cp broker-template.toml broker.toml

# GPU yoksa veya tespit edilemediyse CPU ayarları
if [ $gpu_count -eq 0 ]; then
    # CPU için minimal ayarlar
    max_proofs=1
    peak_khz=50
else
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
