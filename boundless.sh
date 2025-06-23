# Broker.toml ayarları - dosyanın varlığını kontrol et
if [[ -f "broker.toml" ]]; then
    sed -i "s/max_concurrent_proofs = .*/max_concurrent_proofs = $max_proofs/" broker.toml
    sed -i "s/peak_prove_khz = .*/peak_prove_khz = $peak_khz/" broker.toml
    
    # Testnet için optimize edilmiş ayarlar
    sed -i "s/mcycle_price = .*/mcycle_price = \"0.0000002\"/" broker.toml
    sed -i "s/max_mcycle_limit = .*/max_mcycle_limit = $max_mcycle_limit/" broker.toml
    sed -i "s/min_deadline = .*/min_deadline = 150/" broker.toml
    
    # En önemli ayar: lockin_priority_gas (varsayılan olarak yüksek başlat)
    if grep -q "^#lockin_priority_gas" broker.toml; then
        sed -i "s/^#lockin_priority_gas = .*/lockin_priority_gas = 800000/" broker.toml
    elif grep -q "^lockin_priority_gas" broker.toml; then
        sed -i "s/^lockin_priority_gas = .*/lockin_priority_gas = 800000/" broker.toml
    else
        echo "lockin_priority_gas = 800000" >> broker.toml
    fi
    
    basarili_yazdir "broker.toml ayarları güncellendi"
else
    hata_yazdir "broker.toml dosyası bulunamadı!"
    exit 1
fi

# mcycle_price'ı düşük tut (testnet için kar önemli değil)
sed -i "s/mcycle_price = .*/mcycle_price =#!/bin/bash

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

# GPU ön kontrolü
gpu_on_kontrol() {
    bilgi_yazdir "GPU durumu kontrol ediliyor..."
    
    if lspci | grep -i -E "nvidia|amd" &> /dev/null; then
        bilgi_yazdir "GPU donanımı tespit edildi"
        
        if ! command -v nvidia-smi &> /dev/null; then
            echo ""
            uyari_yazdir "GPU bulundu ama driver yüklü değil!"
            echo ""
            echo "Ne yapmak istersiniz?"
            echo "1) Otomatik driver kurulumu yap (sistem yeniden başlatılacak)"
            echo "2) Driver olmadan GPU kontrolünü atla"
            echo "3) Çık"
            echo ""
            read -p "Seçiminiz (1/2/3): " gpu_secim
            
            case $gpu_secim in
                1)
                    install_nvidia_drivers
                    echo ""
                    basarili_yazdir "Driver kurulumu tamamlandı!"
                    uyari_yazdir "Sistem yeniden başlatılmalı"
                    echo ""
                    echo "Reboot sonrası şu komutu çalıştırın:"
                    echo "sudo ./boundless.sh"
                    echo ""
                    echo "Şimdi reboot atmak ister misiniz? (y/n)"
                    read -p "Yanıt: " reboot_yanit
                    if [[ $reboot_yanit == "y" || $reboot_yanit == "Y" ]]; then
                        reboot
                    else
                        exit 0
                    fi
                    ;;
                2)
                    uyari_yazdir "Driver kontrolü atlanıyor..."
                    export GPU_MODE="no_driver"
                    ;;
                3)
                    bilgi_yazdir "Script sonlandırılıyor"
                    exit 0
                    ;;
                *)
                    hata_yazdir "Geçersiz seçim"
                    exit 1
                    ;;
            esac
        else
            if nvidia-smi &> /dev/null; then
                basarili_yazdir "GPU ve driver hazır!"
                export GPU_MODE="gpu"
            else
                uyari_yazdir "GPU driver yüklü ama çalışmıyor. Reboot gerekebilir"
                echo "Reboot atmak ister misiniz? (y/n)"
                read -p "Yanıt: " reboot_yanit
                if [[ $reboot_yanit == "y" || $reboot_yanit == "Y" ]]; then
                    reboot
                else
                    hata_yazdir "GPU driver çalışmıyor, reboot gerekli!"
                    exit 1
                fi
            fi
        fi
    else
        hata_yazdir "GPU donanımı bulunamadı!"
        echo "Boundless mining için GPU gereklidir"
        exit 1
    fi
}

# İlk GPU kontrolü
gpu_on_kontrol

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

# GPU sayısını tespit et ve VRAM'e göre segment size belirle
gpu_sayisi_tespit() {
    local gpu_count=0
    
    if command -v nvidia-smi &> /dev/null; then
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    fi
    echo $gpu_count
}

# GPU VRAM tespiti ve segment size belirleme
detect_gpu_vram() {
    bilgi_yazdir "GPU VRAM tespiti yapılıyor..."
    
    GPU_MEMORY=()
    for i in $(seq 0 $((GPU_COUNT - 1))); do
        MEM=$(nvidia-smi -i $i --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
        if [[ -z "$MEM" ]]; then
            hata_yazdir "GPU $i VRAM tespit edilemedi"
            exit 1
        fi
        GPU_MEMORY+=($MEM)
        bilgi_yazdir "GPU $i: ${MEM}MB VRAM"
    done
    
    # Minimum VRAM'e göre segment size belirle
    MIN_VRAM=$(printf '%s\n' "${GPU_MEMORY[@]}" | sort -n | head -1)
    
    if [[ $MIN_VRAM -ge 40000 ]]; then
        SEGMENT_SIZE=22
    elif [[ $MIN_VRAM -ge 20000 ]]; then
        SEGMENT_SIZE=21
    elif [[ $MIN_VRAM -ge 16000 ]]; then
        SEGMENT_SIZE=20
    elif [[ $MIN_VRAM -ge 12000 ]]; then
        SEGMENT_SIZE=19
    elif [[ $MIN_VRAM -ge 8000 ]]; then
        SEGMENT_SIZE=18
    else
        SEGMENT_SIZE=17
    fi
    
    bilgi_yazdir "Minimum VRAM: ${MIN_VRAM}MB - SEGMENT_SIZE=$SEGMENT_SIZE olarak ayarlandı"
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
    cat > .env.base-sepolia << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
export VERIFIER_ADDRESS=0x0b144e07a0826182b6b59788c34b32bfa86fb711
export BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export ORDER_STREAM_URL="https://base-sepolia.beboundless.xyz"
export SEGMENT_SIZE=$SEGMENT_SIZE
EOF
    
    # Broker dosyası için de aynı işlem
    cat > .env.broker.base-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
SEGMENT_SIZE=$SEGMENT_SIZE
EOF
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
    
    # Dosyalar oluşturulduktan sonra stake ve deposit kontrolü
    check_and_stake "Base Sepolia" ".env.base-sepolia"
}

# Base Mainnet ayarları
base_mainnet_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Environment dosyalarını güncelle/oluştur
    cat > .env.base << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
export VERIFIER_ADDRESS=0x0b144e07a0826182b6b59788c34b32bfa86fb711
export BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export ORDER_STREAM_URL="https://base-mainnet.beboundless.xyz"
export SEGMENT_SIZE=$SEGMENT_SIZE
EOF
    
    # Broker dosyası için de aynı işlem
    cat > .env.broker.base << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
SEGMENT_SIZE=$SEGMENT_SIZE
EOF
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
    
    # Dosyalar oluşturulduktan sonra stake ve deposit kontrolü
    check_and_stake "Base Mainnet" ".env.base"
}

# Ethereum Sepolia ayarları
ethereum_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Environment dosyalarını güncelle/oluştur
    cat > .env.eth-sepolia << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
export VERIFIER_ADDRESS=0x925d8331ddc0a1F0d96E68CF073DFE1d92b69187
export BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
export SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
export ORDER_STREAM_URL="https://eth-sepolia.beboundless.xyz/"
export SEGMENT_SIZE=$SEGMENT_SIZE
EOF
    
    # Broker dosyası için de aynı işlem
    cat > .env.broker.eth-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
SEGMENT_SIZE=$SEGMENT_SIZE
EOF
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
    
    # Dosyalar oluşturulduktan sonra stake ve deposit kontrolü
    check_and_stake "Ethereum Sepolia" ".env.eth-sepolia"
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

# Multi-GPU için compose.yml yapılandırması
configure_compose_multi_gpu() {
    bilgi_yazdir "Compose.yml yapılandırılıyor..."
    
    # Setup script'ini çalıştır
    bash ./scripts/setup.sh
    
    # Multi-GPU için özel ayarlar gerekiyorsa
    if [ $GPU_COUNT -gt 1 ]; then
        bilgi_yazdir "$GPU_COUNT GPU için compose.yml optimize edildi"
    fi
    
    basarili_yazdir "compose.yml hazır"
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

# Compose.yml oluştur
configure_compose_multi_gpu

basarili_yazdir "Setup scripti tamamlandı"

# GPU sayısını ve modelini tespit et
GPU_COUNT=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)

if [ $GPU_COUNT -eq 0 ]; then
    hata_yazdir "GPU tespit edilemedi!"
    echo "Boundless mining için GPU gereklidir"
    echo "Lütfen GPU driver kurulumu yapın ve sistemi yeniden başlatın"
    exit 1
else
    bilgi_yazdir "$GPU_COUNT adet '$gpu_model' GPU tespit edildi"
    
    # GPU VRAM tespiti ve segment size belirleme
    detect_gpu_vram
    
    # GPU'ya göre broker ayarlarını optimize et
    adim_yazdir "Broker ayarları GPU modeli ve sayısına göre optimize ediliyor..."
fi

# Broker template dosyasını kontrol et ve oluştur
if [[ ! -f "broker-template.toml" ]]; then
    bilgi_yazdir "broker-template.toml bulunamadı, oluşturuluyor..."
    cat > broker-template.toml << 'EOF'
max_concurrent_proofs = 2
peak_prove_khz = 100
mcycle_price = "0.0000005"
max_mcycle_limit = 8000
min_deadline = 300
#lockin_priority_gas = 0
EOF
fi

# Template'i broker.toml'a kopyala
cp broker-template.toml broker.toml

# Dosyanın oluşturulduğunu kontrol et
if [[ ! -f "broker.toml" ]]; then
    hata_yazdir "broker.toml oluşturulamadı!"
    exit 1
fi

bilgi_yazdir "broker.toml oluşturuldu"

# GPU VRAM'e göre ayarlar
case $SEGMENT_SIZE in
    22)
        bilgi_yazdir "40GB+ VRAM tespit edildi - Ultra yüksek performans ayarları"
        max_proofs=3  # Güvenli değer
        peak_khz=300  # Benchmark sonucundan biraz düşük ayarlanacak
        max_mcycle_limit=20000  # 4090 için uygun
        ;;
    21)
        bilgi_yazdir "20-40GB VRAM tespit edildi - Çok yüksek performans ayarları"
        max_proofs=2
        peak_khz=250
        max_mcycle_limit=15000
        ;;
    20)
        bilgi_yazdir "16-20GB VRAM tespit edildi - Yüksek performans ayarları"
        max_proofs=2
        peak_khz=200
        max_mcycle_limit=12000
        ;;
    19)
        bilgi_yazdir "12-16GB VRAM tespit edildi - Orta-yüksek performans ayarları"
        max_proofs=2
        peak_khz=150
        max_mcycle_limit=10000
        ;;
    18)
        bilgi_yazdir "8-12GB VRAM tespit edildi - Orta performans ayarları"
        max_proofs=2
        peak_khz=100
        max_mcycle_limit=8000
        ;;
    *)
        bilgi_yazdir "8GB altı VRAM tespit edildi - Temel performans ayarları"
        max_proofs=1
        peak_khz=80
        max_mcycle_limit=5000
        ;;
esac

# Multi-GPU için ayarlamaları artır
if [ $GPU_COUNT -gt 1 ]; then
    # Multi-GPU için max_concurrent_proofs artırılmaz, güvenli tut
    bilgi_yazdir "Multi-GPU tespit edildi, peak_khz ölçeklendi"
    peak_khz=$((peak_khz * GPU_COUNT))
fi

# Broker.toml ayarları
sed -i "s/max_concurrent_proofs = .*/max_concurrent_proofs = $max_proofs/" broker.toml
sed -i "s/peak_prove_khz = .*/peak_prove_khz = $peak_khz/" broker.toml

basarili_yazdir "Broker ayarları optimize edildi:"
bilgi_yazdir "  GPU Model: $gpu_model"
bilgi_yazdir "  GPU Sayısı: $GPU_COUNT"
bilgi_yazdir "  GPU VRAM: ${MIN_VRAM}MB"
bilgi_yazdir "  Segment Size: $SEGMENT_SIZE"
echo ""
bilgi_yazdir "Broker Parametreleri:"
bilgi_yazdir "  lockin_priority_gas: 800000 (Order kapma için kritik!)"
bilgi_yazdir "  mcycle_price: 0.0000002 (Testnet için düşük)"
bilgi_yazdir "  max_concurrent_proofs: $max_proofs (Güvenli değer)"
bilgi_yazdir "  peak_prove_khz: $peak_khz (Benchmark sonrası güncellenmeli)"
bilgi_yazdir "  max_mcycle_limit: $max_mcycle_limit"
bilgi_yazdir "  min_deadline: 150"
echo ""
uyari_yazdir "ÖNEMLİ: Kurulum sonrası benchmark yapıp peak_prove_khz değerini güncelleyin!"
uyari_yazdir "Order alamazsanız lockin_priority_gas değerini artırın!"

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
    echo -n "Ethereum Sepolia RPC URL'nizi girin:
