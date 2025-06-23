#!/bin/bash

set -e

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

# NVIDIA driver kurulumu
install_nvidia_drivers() {
    bilgi_yazdir "NVIDIA driver kurulumu başlatılıyor..."

    ubuntu_version=$(lsb_release -rs)

    apt-get install -y software-properties-common
    add-apt-repository -y ppa:graphics-drivers/ppa
    apt-get update -y

    apt-get install -y ubuntu-drivers-common
    ubuntu-drivers autoinstall

    # CUDA toolkit kur (opsiyonel ama önerilir)
    if ! command -v nvcc &> /dev/null; then
        bilgi_yazdir "CUDA toolkit kuruluyor..."
        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.1-1_all.deb
        dpkg -i cuda-keyring_1.1-1_all.deb
        apt-get update -y
        apt-get -y install cuda-toolkit-12-3
        rm -f cuda-keyring_1.1-1_all.deb
    fi

    # nvidia-container-toolkit kur (Docker için gerekli)
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
    apt-get update -y
    apt-get install -y nvidia-container-toolkit
    systemctl restart docker

    basarili_yazdir "NVIDIA driver kurulumu tamamlandı"
    bilgi_yazdir "Driver'ın aktif olması için sistem yeniden başlatılmalı"
}

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
            echo "2) Driver olmadan CPU modunda devam et"
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
                    read -p "Şimdi reboot atmak ister misiniz? (y/n): " reboot_yanit
                    if [[ $reboot_yanit == "y" || $reboot_yanit == "Y" ]]; then
                        reboot
                    else
                        exit 0
                    fi
                    ;;
                2)
                    uyari_yazdir "CPU modunda devam ediliyor..."
                    export GPU_MODE="cpu"
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
                read -p "Reboot atmak ister misiniz? (y/n): " reboot_yanit
                if [[ $reboot_yanit == "y" || $reboot_yanit == "Y" ]]; then
                    reboot
                else
                    export GPU_MODE="cpu"
                fi
            fi
        fi
    else
        bilgi_yazdir "GPU donanımı bulunamadı, CPU modunda devam edilecek"
        export GPU_MODE="cpu"
    fi
}

gpu_sayisi_tespit() {
    local gpu_count=0

    if [[ "$GPU_MODE" == "cpu" ]]; then
        echo 0
        return
    fi

    if command -v nvidia-smi &> /dev/null; then
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    fi
    echo $gpu_count
}

gpu_model_tespit() {
    if command -v nvidia-smi &> /dev/null; then
        local model=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -z "$model" ]] || [[ "$model" == *"Failed"* ]]; then
            model=$(lspci | grep -i vga | grep -i nvidia | sed 's/.*: //' | head -1)
            [[ -z "$model" ]] && model="Unknown"
        fi
        echo "$model"
    else
        echo "Unknown"
    fi
}

environment_yukle() {
    adim_yazdir "Environment'lar yükleniyor..."

    source ~/.bashrc 2>/dev/null || true

    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
        bilgi_yazdir "Rust environment yüklendi"
    fi

    if [[ -f "$HOME/.rzup/env" ]]; then
        source "$HOME/.rzup/env"
        bilgi_yazdir "RISC Zero environment yüklendi"
    fi

    if [[ -f "/root/.risc0/env" ]]; then
        source "/root/.risc0/env"
        bilgi_yazdir "RISC Zero root environment yüklendi"
    fi

    export PATH="$HOME/.cargo/bin:$PATH"
    export PATH="/root/.risc0/bin:$PATH"

    basarili_yazdir "Environment'lar yüklendi"
}

check_and_stake() {
    local network_name=$1
    local env_file=$2

    echo ""
    bilgi_yazdir "$network_name bakiye kontrolü yapılıyor..."

    adim_yazdir "Environment yükleniyor: $env_file"
    source $env_file

    bilgi_yazdir "USDC stake bakiyesi kontrol ediliyor..."
    stake_balance=$(boundless account stake-balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)

    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance < 5" | bc -l 2>/dev/null || echo "1") == 1 )); then
        read -p "USDC stake yetersiz veya yok! 5 USDC stake etmek ister misiniz? (y/n): " yanit
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

    bilgi_yazdir "ETH deposit bakiyesi kontrol ediliyor..."
    eth_balance=$(boundless account balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)

    if [[ -z "$eth_balance" ]] || (( $(echo "$eth_balance < 0.001" | bc -l 2>/dev/null || echo "1") == 1 )); then
        read -p "ETH deposit yetersiz veya yok! 0.001 ETH deposit etmek ister misiniz? (y/n): " yanit
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

base_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2

    if [[ $gpu_model == *"4090"* ]]; then
        SEGMENT_SIZE=22
    else
        SEGMENT_SIZE=21
    fi
    export SEGMENT_SIZE

    cat > .env.base-sepolia << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
export VERIFIER_ADDRESS=0x0b144e07a0826182b6b59788c34b32bfa86fb711
export BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export ORDER_STREAM_URL="https://base-sepolia.beboundless.xyz"
export SEGMENT_SIZE=$SEGMENT_SIZE
EOF

    cat > .env.broker.base-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
SEGMENT_SIZE=$SEGMENT_SIZE
EOF

    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
    bilgi_yazdir "Segment Size: $SEGMENT_SIZE"

    check_and_stake "Base Sepolia" ".env.base-sepolia"
}

base_mainnet_ayarla() {
    local private_key=$1
    local rpc_url=$2

    if [[ $gpu_model == *"4090"* ]]; then
        SEGMENT_SIZE=22
    else
        SEGMENT_SIZE=21
    fi
    export SEGMENT_SIZE

    cat > .env.base << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
export VERIFIER_ADDRESS=0x0b144e07a0826182b6b59788c34b32bfa86fb711
export BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export ORDER_STREAM_URL="https://base-mainnet.beboundless.xyz"
export SEGMENT_SIZE=$SEGMENT_SIZE
EOF

    cat > .env.broker.base << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
SEGMENT_SIZE=$SEGMENT_SIZE
EOF

    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
    bilgi_yazdir "Segment Size: $SEGMENT_SIZE"

    check_and_stake "Base Mainnet" ".env.base"
}

ethereum_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2

    if [[ $gpu_model == *"4090"* ]]; then
        SEGMENT_SIZE=22
    else
        SEGMENT_SIZE=21
    fi
    export SEGMENT_SIZE

    cat > .env.eth-sepolia << EOF
export PRIVATE_KEY=$private_key
export RPC_URL="$rpc_url"
export VERIFIER_ADDRESS=0x925d8331ddc0a1F0d96E68CF073DFE1d92b69187
export BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
export SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
export ORDER_STREAM_URL="https://eth-sepolia.beboundless.xyz/"
export SEGMENT_SIZE=$SEGMENT_SIZE
EOF

    cat > .env.broker.eth-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
SEGMENT_SIZE=$SEGMENT_SIZE
EOF

    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
    bilgi_yazdir "Segment Size: $SEGMENT_SIZE"

    check_and_stake "Ethereum Sepolia" ".env.eth-sepolia"
}

check_openssl() {
    adim_yazdir "OpenSSL ve bağımlılıkları kontrol ediliyor..."

    if ! command -v pkg-config &> /dev/null; then
        uyari_yazdir "pkg-config bulunamadı, kuruluyor..."
        apt update -y
        apt install -y pkg-config
    fi

    if ! pkg-config --exists openssl; then
        uyari_yazdir "OpenSSL development paketleri bulunamadı, kuruluyor..."
        apt update -y
        apt install -y libssl-dev openssl || {
            uyari_yazdir "libssl-dev kurulamadı, alternatif paketler deneniyor..."
            apt install -y libssl1.1 libssl1.1-dev || apt install -y libssl3 libssl-dev
        }
    fi

    export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:$PKG_CONFIG_PATH
    export OPENSSL_DIR=/usr
    export OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu
    export OPENSSL_INCLUDE_DIR=/usr/include/openssl

    if command -v openssl &> /dev/null; then
        openssl_version=$(openssl version)
        basarili_yazdir "OpenSSL kurulu: $openssl_version"
    fi

    if pkg-config --libs openssl &> /dev/null; then
        basarili_yazdir "OpenSSL pkg-config doğrulaması başarılı"
    else
        hata_yazdir "OpenSSL pkg-config ile bulunamadı!"
        exit 1
    fi
}

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}  Bu Script UFUKDEGEN Tarafından Hazırlanmıştır  ${NC}"
echo -e "${PURPLE}=================================================${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   hata_yazdir "Bu script root yetkisi ile çalıştırılmalıdır!"
   echo "Lütfen 'sudo ./boundless.sh' şeklinde çalıştırın"
   exit 1
fi

gpu_on_kontrol

bilgi_yazdir "Sistem kontrolleri yapılıyor..."

if ! dpkg --configure -a 2>/dev/null; then
    uyari_yazdir "dpkg veritabanı sorunları düzeltiliyor..."
    dpkg --configure -a
fi

if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    uyari_yazdir "APT lock dosyaları temizleniyor..."
    killall apt apt-get 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/dpkg/lock*
    dpkg --configure -a
fi

apt-get update -y 2>/dev/null || {
    uyari_yazdir "APT güncelleme hatası, düzeltiliyor..."
    rm -rf /var/lib/apt/lists/*
    apt-get update -y
}

if ! apt-get check >/dev/null 2>&1; then
    uyari_yazdir "Bozuk paketler tespit edildi, otomatik düzeltiliyor..."
    apt-get install -f -y
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get update -y
fi

basarili_yazdir "Sistem kontrolleri tamamlandı"

gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)

adim_yazdir "Sistem güncelleniyor..."
apt update -y && apt upgrade -y
basarili_yazdir "Sistem güncellemeleri tamamlandı"

adim_yazdir "Gerekli paketler kuruluyor..."
apt install -y build-essential clang gcc make cmake pkg-config autoconf automake ninja-build
apt install -y curl wget git tar unzip lz4 jq htop tmux nano ncdu iptables nvme-cli bsdmainutils
apt install -y libssl-dev libleveldb-dev libclang-dev libgbm1 bc
basarili_yazdir "Gerekli paketler kuruldu"

check_openssl

adim_yazdir "Gerekli bağımlılıklar kuruluyor... (Bu işlem uzun sürebilir)"
if ! bash <(curl -s https://raw.githubusercontent.com/UfukNode/Boundless-ZK-Mining/refs/heads/main/gerekli_bagimliliklar.sh); then
    hata_yazdir "Bağımlılık scripti başarısız oldu!"
    exit 1
fi
basarili_yazdir "Bağımlılıklar kuruldu"

adim_yazdir "Boundless repository klonlanıyor..."
git clone https://github.com/boundless-xyz/boundless
cd boundless
git checkout release-0.10
basarili_yazdir "Repository klonlandı ve release-0.10 dalına geçildi"

adim_yazdir "Setup scripti çalıştırılıyor..."
if [ -d "target" ]; then
    bilgi_yazdir "Eski build dosyaları temizleniyor..."
    cargo clean 2>/dev/null || true
fi
bash ./scripts/setup.sh
basarili_yazdir "Setup scripti tamamlandı"

if [ $gpu_count -eq 0 ]; then
    uyari_yazdir "GPU kullanılamıyor, CPU modunda çalışacak"
    bilgi_yazdir "Performans düşük olabilir"
    max_proofs=1
    peak_khz=50
else
    bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"
    adim_yazdir "Broker ayarları GPU modeli ve sayısına göre optimize ediliyor..."
fi

if [[ ! -f "broker-template.toml" ]]; then
    bilgi_yazdir "broker-template.toml bulunamadı, oluşturuluyor..."
    cat > broker-template.toml << 'EOF'
mcycle_price = "0.0000005"
peak_prove_khz = 100
max_mcycle_limit = 8000
min_deadline = 300
max_concurrent_proofs = 2
lockin_priority_gas = 800
EOF
fi

cp broker-template.toml broker.toml

if [ $gpu_count -eq 0 ]; then
    max_proofs=1
    peak_khz=50
    max_mcycle_limit=5000
else
    if [[ $gpu_model == *"3060"* ]] || [[ $gpu_model == *"4060"* ]]; then
        bilgi_yazdir "RTX 3060/4060 tespit edildi - Temel performans ayarları uygulanıyor"
        max_proofs=2
        peak_khz=80
        max_mcycle_limit=8000
    elif [[ $gpu_model == *"3090"* ]]; then
        bilgi_yazdir "RTX 3090 tespit edildi - Yüksek performans ayarları uygulanıyor"
        max_proofs=3
        peak_khz=200
        max_mcycle_limit=12000
    elif [[ $gpu_model == *"4090"* ]]; then
        bilgi_yazdir "RTX 4090 tespit edildi - Ultra yüksek performans ayarları uygulanıyor"
        max_proofs=4
        peak_khz=300
        max_mcycle_limit=15000
    elif [[ $gpu_model == *"3080"* ]]; then
        bilgi_yazdir "RTX 3080 serisi tespit edildi - Optimum performans ayarları uygulanıyor"
        max_proofs=3
        peak_khz=150
        max_mcycle_limit=10000
    elif [[ $gpu_model == *"307"* ]] || [[ $gpu_model == *"306"* ]]; then
        bilgi_yazdir "RTX 3070/3060 serisi tespit edildi - Dengeli performans ayarları uygulanıyor"
        max_proofs=2
        peak_khz=100
        max_mcycle_limit=8000
    else
        bilgi_yazdir "Standart GPU tespit edildi - Varsayılan ayarlar uygulanıyor"
        max_proofs=2
        peak_khz=100
        max_mcycle_limit=8000
    fi

    if [ $gpu_count -gt 1 ]; then
        peak_khz=$((peak_khz * gpu_count))
        bilgi_yazdir "Multi-GPU tespit edildi, peak_khz ölçeklendi: $peak_khz"
    fi
fi

sed -i "s/max_concurrent_proofs = .*/max_concurrent_proofs = $max_proofs/" broker.toml
sed -i "s/peak_prove_khz = .*/peak_prove_khz = $peak_khz/" broker.toml
sed -i "s/max_mcycle_limit = .*/max_mcycle_limit = $max_mcycle_limit/" broker.toml

basarili_yazdir "Broker ayarları optimize edildi:"
bilgi_yazdir "  GPU Model: $gpu_model"
bilgi_yazdir "  GPU Sayısı: $gpu_count"
bilgi_yazdir "  Max Concurrent Proofs: $max_proofs"
bilgi_yazdir "  Peak Prove kHz: $peak_khz"
bilgi_yazdir "  Max Mcycle Limit: $max_mcycle_limit"
bilgi_yazdir "  Lockin Priority Gas: 800"

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

echo -n "Private Key'inizi girin: "
read -s private_key
private_key=$(echo "$private_key" | xargs)
echo ""

while [[ -z "$private_key" ]]; do
    hata_yazdir "Private key boş olamaz!"
    echo -n "Private Key'inizi tekrar girin: "
    read -s private_key
    private_key=$(echo "$private_key" | xargs)
    echo ""
done

bilgi_yazdir "Private key alındı"

if [[ $network_secim == "1" ]]; then
    read -p "Base Sepolia RPC URL'nizi girin: " rpc_url
    rpc_url=$(echo "$rpc_url" | xargs)
    base_sepolia_ayarla "$private_key" "$rpc_url"
elif [[ $network_secim == "2" ]]; then
    read -p "Base Mainnet RPC URL'nizi girin: " rpc_url
    rpc_url=$(echo "$rpc_url" | xargs)
    base_mainnet_ayarla "$private_key" "$rpc_url"
elif [[ $network_secim == "3" ]]; then
    read -p "Ethereum Sepolia RPC URL'nizi girin: " rpc_url
    rpc_url=$(echo "$rpc_url" | xargs)
    ethereum_sepolia_ayarla "$private_key" "$rpc_url"
else
    hata_yazdir "Geçersiz seçim! Lütfen 1, 2 veya 3 seçin."
    exit 1
fi

adim_yazdir "Node başlatılıyor..."

if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı! Setup.sh başarılı çalıştığından emin olun."
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

case $network_secim in
    "1")
        bilgi_yazdir "Base Sepolia environment yükleniyor..."
        source ./.env.base-sepolia
        basarili_yazdir "Base Sepolia environment yüklendi"
        bilgi_yazdir "Base Sepolia node'u başlatılıyor..."
        just broker up ./.env.broker.base-sepolia
        ;;
    "2")
        bilgi_yazdir "Base Mainnet environment yükleniyor..."
        source ./.env.base
        basarili_yazdir "Base Mainnet environment yüklendi"
        bilgi_yazdir "Base Mainnet node'u başlatılıyor..."
        just broker up ./.env.broker.base
        ;;
    "3")
        bilgi_yazdir "Ethereum Sepolia environment yükleniyor..."
        source ./.env.eth-sepolia
        basarili_yazdir "Ethereum Sepolia environment yüklendi"
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
echo "• Broker ayarlarını düzenle: nano broker.toml"
echo ""
echo "GPU Konfigürasyonu:"
echo "• Tespit edilen GPU: $gpu_model"
echo "• GPU Sayısı: $gpu_count"
echo "• Segment Size: $SEGMENT_SIZE"
echo ""
echo "Broker Ayarları:"
echo "• Max Concurrent Proofs: $max_proofs"
echo "• Peak Prove kHz: $peak_khz"
echo "• Max Mcycle Limit: $max_mcycle_limit"
echo "• Mcycle Price: 0.0000005"
echo "• Min Deadline: 300"
echo "• Lockin Priority Gas: 800"
echo ""
uyari_yazdir "ÖNEMLİ: Benchmark yaparak peak_prove_khz değerini optimize edin!"
echo "1. Explorer'dan Order ID alın: https://explorer.beboundless.xyz/orders"
echo "2. boundless proving benchmark --request-ids ORDER_ID"
echo "3. Sonucu broker.toml dosyasına yazın"
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
