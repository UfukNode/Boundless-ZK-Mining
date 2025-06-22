#!/bin/bash

# Boundless ZK Mining Otomatik Kurulum

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Fix stdin
exec < /dev/tty

adim_yazdir() {
    echo -e "${BLUE}[ADIM]${NC} $1"
}

basarili_yazdir() {
    echo -e "${GREEN}[BASARILI]${NC} $1"
}

hata_yazdir() {
    echo -e "${RED}[HATA]${NC} $1"
}

bilgi_yazdir() {
    echo -e "${CYAN}[BILGI]${NC} $1"
}

# GPU tespit fonksiyonları
gpu_sayisi_tespit() {
    local gpu_count=0
    if command -v nvidia-smi &> /dev/null; then
        gpu_count=$(nvidia-smi -L 2>/dev/null | wc -l)
    fi
    echo $gpu_count
}

gpu_model_tespit() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1
    else
        echo "Unknown"
    fi
}

echo -e "${PURPLE}=================================================${NC}"
echo -e "${PURPLE}  Bu Script UFUKDEGEN TARAFINDAN HAZIRLANMIŞTIR  ${NC}"
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
apt install -y libssl-dev libleveldb-dev libclang-dev libgbm1
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

# GPU tespit
gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)
bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"

# GPU optimizasyonu
adim_yazdir "Broker ayarları GPU modeli ve sayısına göre optimize ediliyor..."

if [[ ! -f "broker-template.toml" ]]; then
    cat > broker-template.toml << 'EOF'
max_concurrent_proofs = 2
peak_prove_khz = 100
EOF
fi

cp broker-template.toml broker.toml

if [[ $gpu_model == *"3060"* ]] || [[ $gpu_model == *"4060"* ]]; then
    max_proofs=2
    peak_khz=80
elif [[ $gpu_model == *"3090"* ]]; then
    max_proofs=4
    peak_khz=200
elif [[ $gpu_model == *"4090"* ]]; then
    max_proofs=6
    peak_khz=300
elif [[ $gpu_model == *"3080"* ]]; then
    max_proofs=3
    peak_khz=150
else
    max_proofs=2
    peak_khz=100
fi

if [ $gpu_count -gt 1 ]; then
    max_proofs=$((max_proofs * gpu_count))
    peak_khz=$((peak_khz * gpu_count))
fi

sed -i "s/max_concurrent_proofs = .*/max_concurrent_proofs = $max_proofs/" broker.toml
sed -i "s/peak_prove_khz = .*/peak_prove_khz = $peak_khz/" broker.toml

basarili_yazdir "Broker ayarları optimize edildi:"
bilgi_yazdir "  GPU Model: $gpu_model"
bilgi_yazdir "  GPU Sayısı: $gpu_count"
bilgi_yazdir "  Max Concurrent Proofs: $max_proofs"
bilgi_yazdir "  Peak Prove kHz: $peak_khz"

# 5. Interactive input
adim_yazdir "Network yapılandırması başlatılıyor..."

echo ""
echo -e "${PURPLE}Hangi ağda prover çalıştırmak istiyorsunuz:${NC}"
echo "1. Base Sepolia (Test ağı)"
echo "2. Base Mainnet"
echo "3. Ethereum Sepolia"
echo ""

# Network seçimi
echo -n "Seçiminizi girin (1/2/3): "
read network_choice < /dev/tty

echo ""
echo -n "Private Key'inizi girin: "
read private_key < /dev/tty

# Network'e göre işlem
if [[ $network_choice == "1" ]]; then
    echo -n "Base Sepolia RPC URL'nizi girin: "
    read rpc_url < /dev/tty
    
    cat > .env.base-sepolia << EOF
export PRIVATE_KEY="$private_key"
export RPC_URL="$rpc_url"
EOF
    
    cat > .env.broker.base-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
EOF
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
    
    echo ""
    echo -n "Cüzdanınızda Base Sepolia test USDC'si var mı? (y/n): "
    read usdc_check < /dev/tty
    
    if [[ $usdc_check == "y" ]]; then
        adim_yazdir "Base Sepolia'ya stake ediliyor..."
        boundless --rpc-url $rpc_url --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5
        basarili_yazdir "5 USDC stake edildi"
        
        echo -n "Base Sepolia'da ETH var mı? (y/n): "
        read eth_check < /dev/tty
        
        if [[ $eth_check == "y" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit 0.0001
            basarili_yazdir "ETH deposit edildi"
        fi
    else
        hata_yazdir "Önce token alın: https://faucet.base-sepolia.com"
        exit 1
    fi
    
elif [[ $network_choice == "2" ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read rpc_url < /dev/tty
    
    cat > .env.base << EOF
export PRIVATE_KEY="$private_key"
export RPC_URL="$rpc_url"
EOF
    
    cat > .env.broker.base << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
EOF
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
    
    echo ""
    echo -n "Cüzdanınızda Base Mainnet USDC'si var mı? (y/n): "
    read usdc_check < /dev/tty
    
    if [[ $usdc_check == "y" ]]; then
        adim_yazdir "Base Mainnet'e stake ediliyor..."
        boundless --rpc-url $rpc_url --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5
        basarili_yazdir "5 USDC stake edildi"
        
        echo -n "Base Mainnet'te ETH var mı? (y/n): "
        read eth_check < /dev/tty
        
        if [[ $eth_check == "y" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit 0.0001
            basarili_yazdir "ETH deposit edildi"
        fi
    else
        hata_yazdir "Önce USDC alın"
        exit 1
    fi
    
elif [[ $network_choice == "3" ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read rpc_url < /dev/tty
    
    cat > .env.eth-sepolia << EOF
export PRIVATE_KEY="$private_key"
export RPC_URL="$rpc_url"
EOF
    
    cat > .env.broker.eth-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
EOF
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
    
    echo ""
    echo -n "Cüzdanınızda Ethereum Sepolia test USDC'si var mı? (y/n): "
    read usdc_check < /dev/tty
    
    if [[ $usdc_check == "y" ]]; then
        adim_yazdir "Ethereum Sepolia'ya stake ediliyor..."
        boundless --rpc-url $rpc_url --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit-stake 5
        basarili_yazdir "5 USDC stake edildi"
        
        echo -n "Ethereum Sepolia'da ETH var mı? (y/n): "
        read eth_check < /dev/tty
        
        if [[ $eth_check == "y" ]]; then
            boundless --rpc-url $rpc_url --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit 0.0001
            basarili_yazdir "ETH deposit edildi"
        fi
    else
        hata_yazdir "Önce token alın: https://faucet.sepolia.dev"
        exit 1
    fi
else
    hata_yazdir "Geçersiz seçim!"
    exit 1
fi

# 6. Node başlat
adim_yazdir "Node başlatılıyor..."

if [[ ! -f "compose.yml" ]] || ! command -v just &> /dev/null; then
    hata_yazdir "compose.yml veya just komutu bulunamadı!"
    exit 1
fi

if [[ $network_choice == "1" ]]; then
    just broker
elif [[ $network_choice == "2" ]]; then
    just broker up ./.env.broker.base
elif [[ $network_choice == "3" ]]; then
    just broker up ./.env.broker.eth-sepolia
fi

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
echo "Yararlı komutlar:"
echo "• Logları kontrol et: docker compose logs -f broker"
echo "• Stake bakiyesi: boundless account stake-balance"
echo "• Node'u durdur: docker compose down"
echo ""
echo "Node'unuz mining yapıyor!"
