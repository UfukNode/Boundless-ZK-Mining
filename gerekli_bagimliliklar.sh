#!/bin/bash

# Boundless Prover Türkçe Kurulum Scripti

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== Boundless Prover Kurulum Scripti ===${NC}"
echo ""

# GPU modelini tespit et
GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
echo -e "${GREEN}Tespit edilen GPU: $GPU_MODEL${NC}"

# Önce just broker çalıştır
echo -e "${YELLOW}İlk kurulum başlatılıyor...${NC}"
just broker &
BROKER_PID=$!

# Kurulumun tamamlanması için bekle
echo "Kurulum tamamlanıyor, lütfen bekleyin..."
sleep 30

# Broker'ı durdur
kill $BROKER_PID 2>/dev/null
just down

echo -e "${GREEN}İlk kurulum tamamlandı${NC}"

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
        echo -e "${RED}Geçersiz seçim!${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Seçilen ağ: $NETWORK${NC}"

# RPC adresi al
echo ""
read -p "RPC adresinizi girin: " RPC_URL

# Private key al
echo ""
read -s -p "Private key'inizi girin: " PRIVATE_KEY
echo ""

# ENV dosyasını güncelle
echo -e "${YELLOW}Yapılandırma dosyası güncelleniyor...${NC}"

# Mevcut dosyayı yedekle
cp $ENV_FILE ${ENV_FILE}.backup

# PRIVATE_KEY ve RPC_URL satırlarını güncelle
sed -i '/^export PRIVATE_KEY=/d' $ENV_FILE
sed -i '/^export RPC_URL=/d' $ENV_FILE

# SET_VERIFIER_ADDRESS'ten sonra PRIVATE_KEY ekle
sed -i '/^export SET_VERIFIER_ADDRESS=/a export PRIVATE_KEY='$PRIVATE_KEY'' $ENV_FILE

# ORDER_STREAM_URL'den sonra RPC_URL ekle
sed -i '/^export ORDER_STREAM_URL=/a export RPC_URL="'$RPC_URL'"' $ENV_FILE

# Environment'ı yükle
source $ENV_FILE

# USDC bakiyesini kontrol et
echo ""
echo -e "${BLUE}USDC bakiyesi kontrol ediliyor...${NC}"

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
            echo -e "${RED}Dikkat: USDC bakiyeniz yetersiz!${NC}"
            echo "Stake işlemi yapabilmek için USDC'ye ihtiyacınız var."
            echo ""
            read -p "Devam etmek istiyor musunuz? (e/h): " CONTINUE
            if [ "$CONTINUE" != "e" ]; then
                exit 1
            fi
        else
            echo -e "${GREEN}USDC bakiyesi mevcut${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Cast yüklü değil, bakiye kontrolü atlanıyor${NC}"
fi

# broker.toml dosyasını oluştur
echo ""
echo -e "${YELLOW}Broker yapılandırması ayarlanıyor...${NC}"

# GPU modeline göre ayarları belirle
if [[ $GPU_MODEL == *"3090"* ]]; then
    cat > broker.toml << 'EOF'
[market]
mcycle_price = "0.0000005"
peak_prove_khz = 150
max_mcycle_limit = 8000
min_deadline = 300
max_concurrent_proofs = 2
lockin_priority_gas = 800
EOF
    echo -e "${GREEN}RTX 3090 için ayarlar yapılandırıldı${NC}"
elif [[ $GPU_MODEL == *"4090"* ]]; then
    cat > broker.toml << 'EOF'
[market]
mcycle_price = "0.0000005"
peak_prove_khz = 150
max_mcycle_limit = 10000
min_deadline = 300
max_concurrent_proofs = 3
lockin_priority_gas = 800
EOF
    echo -e "${GREEN}RTX 4090 için ayarlar yapılandırıldı${NC}"
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
    echo -e "${YELLOW}Varsayılan ayarlar kullanıldı${NC}"
fi

# Node'u başlat
echo ""
echo -e "${BLUE}Node başlatılıyor...${NC}"
just broker

echo ""
echo -e "${GREEN}Kurulum tamamlandı!${NC}"
echo ""
echo "Logları görüntülemek için:"
echo "  just broker logs"
echo ""
echo "Broker loglarını görüntülemek için:"
echo "  docker compose logs -f broker"
echo ""
echo -e "${YELLOW}İyi provlamalar!${NC}"
