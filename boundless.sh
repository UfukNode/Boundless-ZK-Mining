#!/bin/bash

# Boundless ZK Mining Otomatik Kurulum Scripti

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

# Sistem kontrolü
sistem_kontrol() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "${ID,,}" != "ubuntu" ]]; then
            hata_yazdir "Desteklenmeyen işletim sistemi: $NAME. Bu script Ubuntu için tasarlanmıştır."
            exit 1
        fi
        bilgi_yazdir "İşletim Sistemi: $PRETTY_NAME"
    else
        hata_yazdir "İşletim sistemi tespit edilemedi."
        exit 1
    fi
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

# Environment değişkenlerini güncelleme fonksiyonu
env_var_guncelle() {
    local file="$1"
    local var="$2"
    local value="$3"
    
    if grep -q "^${var}=" "$file"; then
        sed -i "s|^${var}=.*|${var}=${value}|" "$file"
    else
        echo "${var}=${value}" >> "$file"
    fi
}

# Multi-GPU için compose.yml ayarları
compose_coklu_gpu_ayarla() {
    local gpu_count="$1"
    local gpu_model="$2"
    
    if [ $gpu_count -le 1 ]; then
        bilgi_yazdir "Tek GPU tespit edildi"
        return 0
    fi
    
    adim_yazdir "$gpu_count GPU için compose.yml yapılandırılıyor..."
    
    cp compose.yml compose.yml.backup
    bilgi_yazdir "Yedek oluşturuldu: compose.yml.backup"
    
    # GPU modeline göre memory ve CPU ayarları
    local mem_limit="4G"
    local cpus="4"
    
    if [[ $gpu_model == *"3090"* ]]; then
        mem_limit="6G"
        cpus="6"
    elif [[ $gpu_model == *"4090"* ]]; then
        mem_limit="8G"
        cpus="8"
    elif [[ $gpu_model == *"3080"* ]]; then
        mem_limit="5G"
        cpus="5"
    fi
    
    local gpu_agent_end_line
    gpu_agent_end_line=$(grep -n "capabilities: \[gpu\]" compose.yml | head -1 | cut -d: -f1)
    
    if [[ -z "$gpu_agent_end_line" ]]; then
        uyari_yazdir "gpu_prove_agent0 bölümü bulunamadı, devam ediliyor"
        return 0
    fi
    
    # Mevcut GPU agent ayarlarını güncelle
    sed -i "s/mem_limit: 4G/mem_limit: $mem_limit/" compose.yml
    sed -i "s/cpus: 4/cpus: $cpus/" compose.yml
    
    local additional_agents=""
    for ((i=1; i<gpu_count; i++)); do
        additional_agents+="
  gpu_prove_agent$i:
    <<: *agent-common
    runtime: nvidia
    mem_limit: $mem_limit
    cpus: $cpus
    entrypoint: /app/agent -t prove

    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['$i']
              capabilities: [gpu]
"
    done
    
    {
        head -n "$gpu_agent_end_line" compose.yml
        echo "$additional_agents"
        tail -n +$((gpu_agent_end_line + 1)) compose.yml
    } > compose.yml.tmp && mv compose.yml.tmp compose.yml
    
    basarili_yazdir "$gpu_count GPU için agentlar eklendi"
}

echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}  Boundless ZK Mining Kurulum Scripti  ${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""

sistem_kontrol

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

bilgi_yazdir "Lütfen terminali yeniden başlatın ve scripti tekrar çalıştırın..."
echo ""
echo -e "${YELLOW}Terminalinizi yeniden başlattıktan sonra devam etmek için herhangi bir tuşa basın...${NC}"
read -n 1 -s

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

# Multi-GPU konfigürasyonu
compose_coklu_gpu_ayarla $gpu_count "$gpu_model"

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

# RTX 3090 özel ayarları
if [[ $gpu_model == *"3090"* ]]; then
    bilgi_yazdir "RTX 3090 tespit edildi - Yüksek performans ayarları uygulanıyor"
    if [ $gpu_count -eq 1 ]; then
        max_proofs=4
        peak_khz=200
    elif [ $gpu_count -eq 2 ]; then
        max_proofs=8
        peak_khz=400
    else
        max_proofs=$((gpu_count * 4))
        peak_khz=$((gpu_count * 200))
    fi
# RTX 4090 özel ayarları
elif [[ $gpu_model == *"4090"* ]]; then
    bilgi_yazdir "RTX 4090 tespit edildi - Ultra yüksek performans ayarları uygulanıyor"
    if [ $gpu_count -eq 1 ]; then
        max_proofs=6
        peak_khz=300
    elif [ $gpu_count -eq 2 ]; then
        max_proofs=12
        peak_khz=600
    else
        max_proofs=$((gpu_count * 6))
        peak_khz=$((gpu_count * 300))
    fi
# RTX 3080/3080 Ti özel ayarları
elif [[ $gpu_model == *"3080"* ]]; then
    bilgi_yazdir "RTX 3080 serisi tespit edildi - Optimum performans ayarları uygulanıyor"
    if [ $gpu_count -eq 1 ]; then
        max_proofs=3
        peak_khz=150
    elif [ $gpu_count -eq 2 ]; then
        max_proofs=6
        peak_khz=300
    else
        max_proofs=$((gpu_count * 3))
        peak_khz=$((gpu_count * 150))
    fi
# RTX 3070/3060 serisi ayarları
elif [[ $gpu_model == *"307"* ]] || [[ $gpu_model == *"306"* ]]; then
    bilgi_yazdir "RTX 3070/3060 serisi tespit edildi - Dengeli performans ayarları uygulanıyor"
    if [ $gpu_count -eq 1 ]; then
        max_proofs=2
        peak_khz=100
    elif [ $gpu_count -eq 2 ]; then
        max_proofs=4
        peak_khz=200
    else
        max_proofs=$((gpu_count * 2))
        peak_khz=$((gpu_count * 100))
    fi
# Diğer GPU'lar için standart ayarlar
else
    bilgi_yazdir "Standart GPU tespit edildi - Varsayılan ayarlar uygulanıyor"
    if [ $gpu_count -eq 1 ]; then
        max_proofs=2
        peak_khz=100
    elif [ $gpu_count -eq 2 ]; then
        max_proofs=4
        peak_khz=200
    elif [ $gpu_count -eq 3 ]; then
        max_proofs=6
        peak_khz=300
    else
        max_proofs=$((gpu_count * 2))
        peak_khz=$((gpu_count * 100))
    fi
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
echo -e "${PURPLE}Hangi ağlarda prover çalıştırmak istiyorsunuz:${NC}"
echo "1. Base Sepolia (Varsayılan - Test ağı)"
echo "2. Base Mainnet"
echo "3. Ethereum Sepolia"
echo ""
echo "Örnekler:"
echo "• Sadece Base Sepolia için: 1 veya ENTER"
echo "• Base Sepolia + Mainnet için: 1,2"
echo "• Hepsi için: 1,2,3"
echo ""
read -p "Seçiminizi girin (varsayılan: 1): " network_secim

# Varsayılan olarak Base Sepolia
if [[ -z "$network_secim" ]]; then
    network_secim="1"
fi

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

# Template dosyasını oluştur
if [[ ! -f ".env.broker-template" ]]; then
    cat > .env.broker-template << 'EOF'
PRIVATE_KEY=
BOUNDLESS_MARKET_ADDRESS=
SET_VERIFIER_ADDRESS=
RPC_URL=
ORDER_STREAM_URL=
EOF
fi

# Network yapılandırmaları
if [[ $network_secim == *"1"* ]]; then
    echo -n "Base Sepolia RPC URL'nizi girin: "
    read base_sepolia_rpc
    
    cp .env.broker-template .env.broker.base-sepolia
    
    env_var_guncelle ".env.broker.base-sepolia" "PRIVATE_KEY" "$private_key"
    env_var_guncelle ".env.broker.base-sepolia" "BOUNDLESS_MARKET_ADDRESS" "0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b"
    env_var_guncelle ".env.broker.base-sepolia" "SET_VERIFIER_ADDRESS" "0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760"
    env_var_guncelle ".env.broker.base-sepolia" "RPC_URL" "$base_sepolia_rpc"
    env_var_guncelle ".env.broker.base-sepolia" "ORDER_STREAM_URL" "https://base-sepolia.beboundless.xyz"
    
    cat > .env.base-sepolia << EOF
export PRIVATE_KEY="$private_key"
export RPC_URL="$base_sepolia_rpc"
EOF
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
fi

if [[ $network_secim == *"2"* ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read base_rpc
    
    cp .env.broker-template .env.broker.base
    
    env_var_guncelle ".env.broker.base" "PRIVATE_KEY" "$private_key"
    env_var_guncelle ".env.broker.base" "BOUNDLESS_MARKET_ADDRESS" "0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8"
    env_var_guncelle ".env.broker.base" "SET_VERIFIER_ADDRESS" "0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760"
    env_var_guncelle ".env.broker.base" "RPC_URL" "$base_rpc"
    env_var_guncelle ".env.broker.base" "ORDER_STREAM_URL" "https://base-mainnet.beboundless.xyz"
    
    cat > .env.base << EOF
export PRIVATE_KEY="$private_key"
export RPC_URL="$base_rpc"
EOF
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
fi

if [[ $network_secim == *"3"* ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read eth_sepolia_rpc
    
    cp .env.broker-template .env.broker.eth-sepolia
    
    env_var_guncelle ".env.broker.eth-sepolia" "PRIVATE_KEY" "$private_key"
    env_var_guncelle ".env.broker.eth-sepolia" "BOUNDLESS_MARKET_ADDRESS" "0x13337C76fE2d1750246B68781ecEe164643b98Ec"
    env_var_guncelle ".env.broker.eth-sepolia" "SET_VERIFIER_ADDRESS" "0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64"
    env_var_guncelle ".env.broker.eth-sepolia" "RPC_URL" "$eth_sepolia_rpc"
    env_var_guncelle ".env.broker.eth-sepolia" "ORDER_STREAM_URL" "https://eth-sepolia.beboundless.xyz/"
    
    cat > .env.eth-sepolia << EOF
export PRIVATE_KEY="$private_key"
export RPC_URL="$eth_sepolia_rpc"
EOF
    
    basarili_yazdir "Ethereum Sepolia ağı yapılandırıldı"
fi

# 6. Stake kontrolleri ve rehberi
echo ""
echo "========== STAKE İŞLEMLERİ =========="
echo ""

if [[ $network_secim == *"1"* ]]; then
    echo "Base Sepolia Ağı:"
    echo "Cüzdanınızda Base Sepolia test USDC'si var mı? (y/n)"
    read -p "Yanıt: " base_sepolia_usdc
    
    if [[ $base_sepolia_usdc == "y" || $base_sepolia_usdc == "Y" ]]; then
        echo "5 USDC stake etmek için şu komutu çalıştırın:"
        echo "boundless --rpc-url $base_sepolia_rpc --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5"
    else
        echo "Önce Base Sepolia test USDC alın:"
        echo "Faucet: https://faucet.base-sepolia.com"
        echo "Sonra stake komutu:"
        echo "boundless --rpc-url $base_sepolia_rpc --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5"
    fi
    echo ""
    
    echo "Base Sepolia'da 0.0001 ETH var mı? (y/n)"
    read -p "Yanıt: " base_sepolia_eth
    
    if [[ $base_sepolia_eth == "y" || $base_sepolia_eth == "Y" ]]; then
        echo "ETH deposit komutu:"
        echo "boundless --rpc-url $base_sepolia_rpc --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit 0.0001"
    else
        echo "Önce 0.0001 ETH alın, sonra deposit yapın"
        echo "ETH deposit komutu:"
        echo "boundless --rpc-url $base_sepolia_rpc --private-key $private_key --chain-id 84532 --boundless-market-address 0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit 0.0001"
    fi
    echo ""
fi

if [[ $network_secim == *"2"* ]]; then
    echo "Base Mainnet Ağı:"
    echo "Cüzdanınızda Base Mainnet USDC'si var mı? (y/n)"
    read -p "Yanıt: " base_mainnet_usdc
    
    if [[ $base_mainnet_usdc == "y" || $base_mainnet_usdc == "Y" ]]; then
        echo "5 USDC stake etmek için şu komutu çalıştırın:"
        echo "boundless --rpc-url $base_rpc --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5"
    else
        echo "Önce Base Mainnet USDC alın"
        echo "Sonra stake komutu:"
        echo "boundless --rpc-url $base_rpc --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit-stake 5"
    fi
    echo ""
    
    echo "Base Mainnet'te 0.0001 ETH var mı? (y/n)"
    read -p "Yanıt: " base_mainnet_eth
    
    if [[ $base_mainnet_eth == "y" || $base_mainnet_eth == "Y" ]]; then
        echo "ETH deposit komutu:"
        echo "boundless --rpc-url $base_rpc --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit 0.0001"
    else
        echo "Önce 0.0001 ETH alın, sonra deposit yapın"
        echo "ETH deposit komutu:"
        echo "boundless --rpc-url $base_rpc --private-key $private_key --chain-id 8453 --boundless-market-address 0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8 --set-verifier-address 0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760 account deposit 0.0001"
    fi
    echo ""
fi

if [[ $network_secim == *"3"* ]]; then
    echo "Ethereum Sepolia Ağı:"
    echo "Cüzdanınızda Ethereum Sepolia test USDC'si var mı? (y/n)"
    read -p "Yanıt: " eth_sepolia_usdc
    
    if [[ $eth_sepolia_usdc == "y" || $eth_sepolia_usdc == "Y" ]]; then
        echo "5 USDC stake etmek için şu komutu çalıştırın:"
        echo "boundless --rpc-url $eth_sepolia_rpc --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit-stake 5"
    else
        echo "Önce Ethereum Sepolia test USDC alın"
        echo "Faucet: https://faucet.sepolia.dev"
        echo "Sonra stake komutu:"
        echo "boundless --rpc-url $eth_sepolia_rpc --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit-stake 5"
    fi
    echo ""
    
    echo "Ethereum Sepolia'da 0.0001 ETH var mı? (y/n)"
    read -p "Yanıt: " eth_sepolia_eth
    
    if [[ $eth_sepolia_eth == "y" || $eth_sepolia_eth == "Y" ]]; then
        echo "ETH deposit komutu:"
        echo "boundless --rpc-url $eth_sepolia_rpc --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit 0.0001"
    else
        echo "Önce 0.0001 ETH alın, sonra deposit yapın"
        echo "ETH deposit komutu:"
        echo "boundless --rpc-url $eth_sepolia_rpc --private-key $private_key --chain-id 11155111 --boundless-market-address 0x13337C76fE2d1750246B68781ecEe164643b98Ec --set-verifier-address 0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64 account deposit 0.0001"
    fi
    echo ""
fi
fi

echo "Stake ve deposit işlemlerini yukarıdaki komutları kullanarak manuel olarak yapın."
echo "İşlemler tamamlandıktan sonra node'u başlatmak için:"
echo ""

# 7. Node başlatma rehberi
echo "========== NODE BAŞLATMA =========="
echo ""
echo "Önce compose.yml ve just komutunun varlığını kontrol edin:"

if [[ ! -f "compose.yml" ]]; then
    hata_yazdir "compose.yml dosyası bulunamadı! Setup.sh çalıştırıldığından emin olun."
    exit 1
fi

if ! command -v just &> /dev/null; then
    hata_yazdir "just komutu bulunamadı!"
    exit 1
fi

echo "Node başlatma komutları:"

if [[ $network_secim == *"1"* ]]; then
    echo "Base Sepolia için:"
    echo "just broker"
fi

if [[ $network_secim == *"2"* ]]; then
    echo "Base Mainnet için:"
    echo "just broker up ./.env.broker.base"
fi

if [[ $network_secim == *"3"* ]]; then
    echo "Ethereum Sepolia için:"
    echo "just broker up ./.env.broker.eth-sepolia"
fi

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
echo "1. Yukarıdaki stake/deposit komutlarını çalıştırın"
echo "2. Node başlatma komutunu çalıştırın"
echo "3. Logları kontrol edin"
echo ""
echo "Node'unuz şimdi mining yapmaya hazır!"
