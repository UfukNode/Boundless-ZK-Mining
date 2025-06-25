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

# GPU Benchmark fonksiyonu
gpu_benchmark_calistir() {
    echo ""
    echo -e "${PURPLE}=========================================${NC}"
    echo -e "${PURPLE}       GPU BENCHMARK BAŞLATILIYOR        ${NC}"
    echo -e "${PURPLE}=========================================${NC}"
    echo ""
    
    adim_yazdir "GPU performans testi başlatılıyor..."
    
    # GPU bilgilerini göster
    bilgi_yazdir "GPU Bilgileri:"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total,utilization.gpu,temperature.gpu \
            --format=csv,noheader,nounits | while read line; do
            echo "  • $line"
        done
    fi
    
    # Bento CLI'nin kurulu olduğunu kontrol et
    if ! command -v bento_cli &> /dev/null; then
        uyari_yazdir "bento_cli bulunamadı, kurulum yapılıyor..."
        cargo install --git https://github.com/boundless-xyz/boundless.git bento_cli
    fi
    
    # Benchmark için çalışma dizinini oluştur
    mkdir -p benchmark_results
    cd benchmark_results
    
    # Benchmark parametrelerini belirle
    local iteration_counts=(1024 2048 4096)
    local best_khz=0
    local best_iteration=2048
    
    echo ""
    bilgi_yazdir "Farklı iterasyon sayıları ile test yapılacak: ${iteration_counts[@]}"
    echo ""
    
    # Her iterasyon sayısı için test yap
    for iterations in "${iteration_counts[@]}"; do
        adim_yazdir "Test başlatılıyor: $iterations iterasyon..."
        
        # Test sonuçlarını kaydet
        local log_file="benchmark_${iterations}_$(date +%Y%m%d_%H%M%S).log"
        
        # Benchmark komutunu çalıştır
        RUST_LOG=info bento_cli -c $iterations > "$log_file" 2>&1 &
        local pid=$!
        
        # İlerleme göstergesi
        local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local spin_idx=0
        
        while kill -0 $pid 2>/dev/null; do
            printf "\r  ${spinner[$spin_idx]} Test devam ediyor... "
            spin_idx=$(( (spin_idx + 1) % ${#spinner[@]} ))
            sleep 0.1
        done
        
        wait $pid
        local exit_code=$?
        printf "\r                                          \r"
        
        if [[ $exit_code -eq 0 ]]; then
            # Sonuçları parse et
            local khz=$(grep -i "hz\|khz" "$log_file" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
            local cycles=$(grep -i "cycles" "$log_file" | grep -oE '[0-9]+' | tail -1)
            
            if [[ ! -z "$khz" ]]; then
                # Hz ise kHz'e çevir
                if (( $(echo "$khz > 1000" | bc -l 2>/dev/null || echo "0") == 1 )); then
                    khz=$(echo "scale=0; $khz / 1000" | bc)
                fi
                
                basarili_yazdir "$iterations iterasyon testi tamamlandı:"
                echo "    • Performans: $khz kHz"
                echo "    • Toplam Cycles: $cycles"
                
                # En iyi sonucu güncelle
                if (( $(echo "$khz > $best_khz" | bc -l 2>/dev/null || echo "0") == 1 )); then
                    best_khz=$khz
                    best_iteration=$iterations
                fi
            else
                uyari_yazdir "$iterations iterasyon testinde sonuç alınamadı"
            fi
        else
            hata_yazdir "$iterations iterasyon testi başarısız oldu"
        fi
        
        echo ""
    done
    
    # Benchmark raporu oluştur
    adim_yazdir "Benchmark raporu oluşturuluyor..."
    
    local report_file="benchmark_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" << EOF
=== BOUNDLESS GPU BENCHMARK RAPORU ===
Tarih: $(date)
Sistem: $(uname -a)
GPU: $gpu_model
GPU Sayısı: $gpu_count

TEST SONUÇLARI:
EOF
    
    # Tüm test sonuçlarını rapora ekle
    for log in benchmark_*.log; do
        if [[ -f "$log" ]]; then
            local iter=$(echo "$log" | grep -oE '[0-9]+' | head -1)
            local perf=$(grep -i "hz\|khz" "$log" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
            if [[ ! -z "$perf" ]]; then
                if (( $(echo "$perf > 1000" | bc -l 2>/dev/null || echo "0") == 1 )); then
                    perf=$(echo "scale=0; $perf / 1000" | bc)
                fi
                echo "• $iter iterasyon: $perf kHz" >> "$report_file"
            fi
        fi
    done
    
    # Önerilen ayarları ekle
    local recommended_khz=$(echo "scale=0; $best_khz * 80 / 100" | bc)
    
    cat >> "$report_file" << EOF

EN İYİ SONUÇ:
• Performans: $best_khz kHz
• İterasyon: $best_iteration

ÖNERİLEN AYARLAR:
• peak_prove_khz: $recommended_khz (güvenli değer - %80)
• İdeal iterasyon sayısı: $best_iteration

NOTLAR:
- peak_prove_khz değeri, ölçülen maksimum değerin %80'i olarak ayarlanmıştır
- Bu değer güvenli bir marj sağlar ve stabil performans sunar
- Sistem yükü arttığında bu değeri düşürmeyi düşünebilirsiniz
EOF
    
    # Raporu göster
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    cat "$report_file"
    echo -e "${GREEN}=========================================${NC}"
    
    # Ana dizine geri dön
    cd ..
    
    # Global değişkenleri güncelle (broker.toml için)
    export BENCHMARK_PEAK_KHZ=$recommended_khz
    export BENCHMARK_BEST_KHZ=$best_khz
    
    basarili_yazdir "Benchmark testi tamamlandı!"
    bilgi_yazdir "Detaylı rapor: benchmark_results/$report_file"
    
    return 0
}

# Otomatik stake ve deposit işlemleri
otomatik_stake_deposit() {
    local env_file=$1
    local network_name=$2
    
    echo ""
    bilgi_yazdir "$network_name için otomatik stake ve deposit işlemleri başlatılıyor..."
    
    # Environment dosyasını yükle
    adim_yazdir "Environment dosyası yükleniyor..."
    source "$env_file"
    source ~/.bashrc 2>/dev/null || true
    
    # Boundless komutunun çalıştığından emin ol
    if ! command -v boundless &> /dev/null; then
        environment_yukle
    fi
    
    # USDC Stake kontrolü ve otomatik stake
    bilgi_yazdir "USDC stake bakiyesi kontrol ediliyor..."
    stake_balance=$(boundless account stake-balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    if [[ -z "$stake_balance" ]] || (( $(echo "$stake_balance < 5" | bc -l 2>/dev/null || echo "1") == 1 )); then
        adim_yazdir "Yetersiz USDC stake tespit edildi. 5 USDC otomatik stake ediliyor..."
        if boundless account deposit-stake 5 2>/dev/null; then
            basarili_yazdir "5 USDC başarıyla stake edildi"
        else
            uyari_yazdir "USDC stake işleminde sorun oldu. Lütfen cüzdanınızda yeterli USDC olduğundan emin olun."
        fi
    else
        basarili_yazdir "✓ USDC Stake OK: $stake_balance USDC"
    fi
    
    # ETH Deposit kontrolü ve otomatik deposit
    bilgi_yazdir "ETH deposit bakiyesi kontrol ediliyor..."
    eth_balance=$(boundless account balance 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    
    if [[ -z "$eth_balance" ]] || (( $(echo "$eth_balance < 0.001" | bc -l 2>/dev/null || echo "1") == 1 )); then
        adim_yazdir "Yetersiz ETH deposit tespit edildi. 0.001 ETH otomatik deposit ediliyor..."
        if boundless account deposit 0.001 2>/dev/null; then
            basarili_yazdir "0.001 ETH başarıyla deposit edildi"
        else
            uyari_yazdir "ETH deposit işleminde sorun oldu. Lütfen cüzdanınızda yeterli ETH olduğundan emin olun."
        fi
    else
        basarili_yazdir "✓ ETH Deposit OK: $eth_balance ETH"
    fi
    
    echo ""
    basarili_yazdir "Stake ve deposit kontrolleri tamamlandı"
}

# Base Sepolia ayarları
base_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Ana .env.base-sepolia dosyasını oluştur
    cat > .env.base-sepolia << EOF
export BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
export RPC_URL="$rpc_url"
EOF

    # Broker .env dosyasını oluştur
    cat > .env.broker.base-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x6B7ABa661041164b8dB98E30AE1454d2e9D5f14b
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-sepolia.beboundless.xyz
EOF
    
    basarili_yazdir "Base Sepolia ağı yapılandırıldı"
}

# Base Mainnet ayarları
base_mainnet_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Ana .env.base dosyasını oluştur
    cat > .env.base << EOF
export BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
export SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
export RPC_URL="$rpc_url"
EOF

    # Broker .env dosyasını oluştur
    cat > .env.broker.base << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x26759dbB201aFbA361Bec78E097Aa3942B0b4AB8
SET_VERIFIER_ADDRESS=0x8C5a8b5cC272Fe2b74D18843CF9C3aCBc952a760
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://base-mainnet.beboundless.xyz
EOF
    
    basarili_yazdir "Base Mainnet ağı yapılandırıldı"
}

# Ethereum Sepolia ayarları
ethereum_sepolia_ayarla() {
    local private_key=$1
    local rpc_url=$2
    
    # Ana .env.eth-sepolia dosyasını oluştur
    cat > .env.eth-sepolia << EOF
export BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
export SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
export PRIVATE_KEY=$private_key
export ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
export RPC_URL="$rpc_url"
EOF

    # Broker .env dosyasını oluştur
    cat > .env.broker.eth-sepolia << EOF
PRIVATE_KEY=$private_key
BOUNDLESS_MARKET_ADDRESS=0x13337C76fE2d1750246B68781ecEe164643b98Ec
SET_VERIFIER_ADDRESS=0x7aAB646f23D1392d4522CFaB0b7FB5eaf6821d64
RPC_URL=$rpc_url
ORDER_STREAM_URL=https://eth-sepolia.beboundless.xyz/
EOF
    
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

# 3. Gerekli bağımlılıklar scripti çalıştır
adim_yazdir "Gerekli bağımlılıklar kuruluyor... (Bu işlem uzun sürebilir)"
bash <(curl -s https://raw.githubusercontent.com/UfukNode/Boundless-ZK-Mining/refs/heads/main/gerekli_bagimliliklar.sh)
basarili_yazdir "Bağımlılıklar kuruldu"

# Çalışma dizinini kontrol et ve ayarla
adim_yazdir "Çalışma dizini kontrol ediliyor..."
current_dir=$(pwd)
if [[ "$current_dir" == *"/boundless"* ]]; then
    bilgi_yazdir "Zaten boundless dizini içindesiniz, ana dizine dönülüyor..."
    cd ~
fi

# 4. Boundless reposunu klonla veya güncelle
adim_yazdir "Boundless repository kontrol ediliyor..."

if [[ -d "boundless" ]]; then
    bilgi_yazdir "Boundless klasörü zaten mevcut, güncelleniyor..."
    cd boundless
    
    # Mevcut değişiklikleri temizle
    git reset --hard
    git clean -fd
    
    # En son değişiklikleri al
    git fetch origin
    git checkout release-0.10
    git pull origin release-0.10
    
    basarili_yazdir "Repository güncellendi"
else
    adim_yazdir "Boundless repository klonlanıyor..."
    git clone https://github.com/boundless-xyz/boundless
    cd boundless
    git checkout release-0.10
    basarili_yazdir "Repository klonlandı ve release-0.10 dalına geçildi"
fi

adim_yazdir "Setup scripti çalıştırılıyor..."
bash ./scripts/setup.sh
basarili_yazdir "Setup scripti tamamlandı"

# GPU sayısını ve modelini tespit et
gpu_count=$(gpu_sayisi_tespit)
gpu_model=$(gpu_model_tespit)
bilgi_yazdir "$gpu_count adet '$gpu_model' GPU tespit edildi"

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

# Compose.yml optimizasyonu
optimize_compose_yml() {
    adim_yazdir "compose.yml dosyası sistem özelliklerine göre optimize ediliyor..."
    
    if [[ ! -f "compose.yml" ]]; then
        uyari_yazdir "compose.yml dosyası bulunamadı, optimizasyon atlanıyor..."
        return
    fi
    
    # Sistem RAM'ini tespit et (GB cinsinden)
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    # Sistem CPU core sayısını tespit et
    total_cpu_cores=$(nproc)
    
    bilgi_yazdir "Sistem özellikleri tespit edildi:"
    bilgi_yazdir "  Total RAM: ${total_ram_gb}GB"
    bilgi_yazdir "  Total CPU Cores: $total_cpu_cores"
    bilgi_yazdir "  GPU Sayısı: $gpu_count"
    
    # Backup al
    cp compose.yml compose.yml.backup
    
    # RAM ve CPU optimizasyonu (sistemin %70'ini kullan)
    if [[ $total_ram_gb -ge 32 ]]; then
        # 32GB+ RAM için yüksek performans ayarları
        exec_agent_ram="8G"
        gpu_agent_ram="8G"
        exec_agent_cpu=$((total_cpu_cores / 2))
        gpu_agent_cpu=$((total_cpu_cores / 3))
    elif [[ $total_ram_gb -ge 16 ]]; then
        # 16-32GB RAM için orta performans ayarları
        exec_agent_ram="6G"
        gpu_agent_ram="6G"
        exec_agent_cpu=$((total_cpu_cores / 3))
        gpu_agent_cpu=$((total_cpu_cores / 4))
    else
        # 16GB altı RAM için düşük performans ayarları
        exec_agent_ram="4G"
        gpu_agent_ram="4G"
        exec_agent_cpu=2
        gpu_agent_cpu=2
    fi
    
    # GPU sayısına göre ayarlama yap
    if [[ $gpu_count -gt 1 ]]; then
        # Multi-GPU için CPU/RAM'i GPU'lara böl
        gpu_agent_cpu=$((gpu_agent_cpu / gpu_count))
        if [[ $gpu_agent_cpu -lt 2 ]]; then
            gpu_agent_cpu=2
        fi
    fi
    
    bilgi_yazdir "Optimizasyon ayarları:"
    bilgi_yazdir "  x-exec-agent-common RAM: $exec_agent_ram"
    bilgi_yazdir "  x-exec-agent-common CPU: $exec_agent_cpu"
    bilgi_yazdir "  gpu_prove_agent RAM: $gpu_agent_ram"
    bilgi_yazdir "  gpu_prove_agent CPU: $gpu_agent_cpu"
    
    # x-exec-agent-common optimizasyonu
    if grep -q "x-exec-agent-common:" compose.yml; then
        # RAM limitini güncelle
        sed -i "/x-exec-agent-common:/,/entrypoint:/ s/mem_limit: [0-9]*G/mem_limit: $exec_agent_ram/" compose.yml
        
        # CPU limitini güncelle
        sed -i "/x-exec-agent-common:/,/entrypoint:/ s/cpus: [0-9]*/cpus: $exec_agent_cpu/" compose.yml
        
        bilgi_yazdir "x-exec-agent-common optimize edildi"
    fi
    
    # gpu_prove_agent optimizasyonu (tüm GPU agent'ları için)
    for ((i=0; i<gpu_count; i++)); do
        if grep -q "gpu_prove_agent$i:" compose.yml; then
            # RAM limitini güncelle
            sed -i "/gpu_prove_agent$i:/,/capabilities:/ s/mem_limit: [0-9]*G/mem_limit: $gpu_agent_ram/" compose.yml
            
            # CPU limitini güncelle  
            sed -i "/gpu_prove_agent$i:/,/capabilities:/ s/cpus: [0-9]*/cpus: $gpu_agent_cpu/" compose.yml
            
            bilgi_yazdir "gpu_prove_agent$i optimize edildi"
        fi
    done
    
    # SEGMENT_SIZE optimizasyonu (GPU VRAM'e göre)
    if [[ $gpu_count -gt 0 ]]; then
        # GPU VRAM'ini tespit etmeye çalış
        if command -v nvidia-smi &> /dev/null; then
            gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
            if [[ ! -z "$gpu_vram" ]] && [[ "$gpu_vram" =~ ^[0-9]+$ ]]; then
                gpu_vram_gb=$((gpu_vram / 1024))
                bilgi_yazdir "GPU VRAM tespit edildi: ${gpu_vram_gb}GB"
                
                # VRAM'e göre SEGMENT_SIZE ayarla
                if [[ $gpu_vram_gb -ge 20 ]]; then
                    segment_size=21  # 20GB+ için varsayılan
                elif [[ $gpu_vram_gb -ge 12 ]]; then
                    segment_size=20  # 12-20GB için
                elif [[ $gpu_vram_gb -ge 8 ]]; then
                    segment_size=19  # 8-12GB için
                else
                    segment_size=18  # 8GB altı için
                fi
                
                # SEGMENT_SIZE'ı güncelle
                sed -i "s/SEGMENT_SIZE:-21/SEGMENT_SIZE:-$segment_size/g" compose.yml
                bilgi_yazdir "SEGMENT_SIZE $segment_size olarak ayarlandı"
            fi
        fi
    fi
    
    basarili_yazdir "compose.yml optimizasyonu tamamlandı"
    bilgi_yazdir "Backup dosyası: compose.yml.backup"
}

# Compose.yml optimizasyonunu çalıştır
optimize_compose_yml

# GPU BENCHMARK TESTİ - PostgreSQL'den önce çalıştır
if [[ $gpu_count -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}GPU benchmark testi yapmak ister misiniz?${NC}"
    echo "Bu test GPU performansınızı ölçer ve optimal ayarları belirler."
    echo "(Test 5-10 dakika sürebilir)"
    echo ""
    read -p "Benchmark yapılsın mı? (e/E/h/H): " benchmark_secim
    
    if [[ "$benchmark_secim" =~ ^[eE]$ ]]; then
        gpu_benchmark_calistir
        
        # Benchmark sonuçlarını kullan
        if [[ ! -z "$BENCHMARK_PEAK_KHZ" ]]; then
            optimal_peak_khz=$BENCHMARK_PEAK_KHZ
            bilgi_yazdir "Benchmark sonucu peak_prove_khz değeri: $optimal_peak_khz kHz olarak ayarlanacak"
        fi
    else
        bilgi_yazdir "Benchmark atlandı, varsayılan değerler kullanılacak"
    fi
else
    bilgi_yazdir "GPU tespit edilmedi, benchmark atlanıyor"
fi

# 6. PostgreSQL kurulumu ve broker.toml optimizasyonu
adim_yazdir "PostgreSQL kuruluyor..."
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

# GPU'ya göre broker ayarlarını optimize et
adim_yazdir "Broker ayarları optimize ediliyor..."

# Sabit ayarlar
optimal_peak_khz=300
max_concurrent_proofs=2
max_mcycle_limit=25000
locking_priority_gas=0
mcycle_price="0.00000000000000015"
min_deadline=350

# Multi-GPU için ayarlamaları YAPMA - her GPU için 2 proof yeterli
# if [ $gpu_count -gt 1 ]; then
#     max_concurrent_proofs=$((max_concurrent_proofs * gpu_count))
# fi

# broker.toml dosyasını güncelle (eğer varsa)
if [[ -f "broker.toml" ]]; then
    bilgi_yazdir "Broker.toml dosyası güncelleniyor..."
    
    # Önce mevcut ayarları temizle
    sed -i '/^peak_prove_khz/d' broker.toml
    sed -i '/^max_concurrent_proofs/d' broker.toml
    sed -i '/^max_mcycle_limit/d' broker.toml
    sed -i '/^locking_priority_gas/d' broker.toml
    sed -i '/^mcycle_price/d' broker.toml
    sed -i '/^min_deadline/d' broker.toml

    # Yeni ayarları ekle
    echo "" >> broker.toml
    echo "# Optimized Settings" >> broker.toml
    echo "peak_prove_khz = $optimal_peak_khz" >> broker.toml
    echo "max_concurrent_proofs = $max_concurrent_proofs" >> broker.toml
    echo "max_mcycle_limit = $max_mcycle_limit" >> broker.toml
    echo "locking_priority_gas = $locking_priority_gas" >> broker.toml
    echo "mcycle_price = \"$mcycle_price\"" >> broker.toml
    echo "min_deadline = $min_deadline" >> broker.toml
    
    basarili_yazdir "Broker.toml optimizasyonu tamamlandı"
else
    bilgi_yazdir "broker.toml dosyası henüz oluşturulmadı, ayarlar daha sonra uygulanacak"
fi

bilgi_yazdir "Optimizasyon Ayarları:"
bilgi_yazdir "  Peak Prove kHz: $optimal_peak_khz"
bilgi_yazdir "  Max Concurrent Proofs: $max_concurrent_proofs"
bilgi_yazdir "  Max Mcycle Limit: $max_mcycle_limit"
bilgi_yazdir "  Locking Priority Gas: $locking_priority_gas"
bilgi_yazdir "  Mcycle Price: $mcycle_price"
bilgi_yazdir "  Min Deadline: $min_deadline"

# 7. Network seçimi ve .env dosyalarını ayarla
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
    broker_env_file=".env.broker.base-sepolia"
    network_name="Base Sepolia"
    
elif [[ $network_secim == "2" ]]; then
    echo -n "Base Mainnet RPC URL'nizi girin: "
    read rpc_url
    
    base_mainnet_ayarla "$private_key" "$rpc_url"
    env_file=".env.base"
    broker_env_file=".env.broker.base"
    network_name="Base Mainnet"
    
elif [[ $network_secim == "3" ]]; then
    echo -n "Ethereum Sepolia RPC URL'nizi girin: "
    read rpc_url
    
    ethereum_sepolia_ayarla "$private_key" "$rpc_url"
    env_file=".env.eth-sepolia"
    broker_env_file=".env.broker.eth-sepolia"
    network_name="Ethereum Sepolia"
    
else
    hata_yazdir "Geçersiz seçim! Lütfen 1, 2 veya 3 seçin."
    exit 1
fi

# 8. Environment'ları yükle
environment_yukle

# 9. Network seçimine göre environment'ı source et
adim_yazdir "Environment dosyaları yükleniyor..."
source "$env_file"
basarili_yazdir "$network_name environment'ı yüklendi"

# 10. Otomatik stake ve deposit işlemleri
otomatik_stake_deposit "$env_file" "$network_name"

# 11. Node'u başlat
adim_yazdir "Node başlatılıyor..."

case $network_secim in
    "1")
        bilgi_yazdir "Base Sepolia environment'ı yükleniyor ve node başlatılıyor..."
        source .env.base-sepolia
        just broker
        ;;
    "2")
        bilgi_yazdir "Base Mainnet environment'ı yükleniyor ve node başlatılıyor..."
        source .env.base
        just broker
        ;;
    "3")
        bilgi_yazdir "Ethereum Sepolia environment'ı yükleniyor ve node başlatılıyor..."
        source .env.eth-sepolia
        just broker
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
        echo "• Node'u durdur: just broker down"
        echo "• Node'u başlat: source .env.base-sepolia && just broker"
        ;;
    "2")
        echo "• Node'u durdur: just broker down"
        echo "• Node'u başlat: source .env.base && just broker"
        ;;
    "3")
        echo "• Node'u durdur: just broker down"
        echo "• Node'u başlat: source .env.eth-sepolia && just broker"
        ;;
esac
echo ""
echo "GPU Konfigürasyonu:"
echo "• Tespit edilen GPU: $gpu_model"
echo "• GPU Sayısı: $gpu_count"
echo "• Peak Prove kHz: $optimal_peak_khz"
echo "• Maksimum eşzamanlı proof: $max_concurrent_proofs"
echo "• Max Mcycle Limit: $max_mcycle_limit"
echo ""

# Benchmark yapıldıysa rapor bilgisini göster
if [[ -f "benchmark_results/benchmark_report_"* ]]; then
    echo "Benchmark Raporu:"
    echo "• Detaylı rapor: $(ls -t benchmark_results/benchmark_report_* | head -1)"
    echo ""
fi

echo "$network_name ağında mining başladı!"
echo ""
echo "Node'unuz şimdi mining yapıyor! Logları kontrol edin."
