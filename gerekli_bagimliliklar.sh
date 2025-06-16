#!/bin/bash

# RISC Zero Geliştirme Ortamı Kurulum Scripti
# Bu script Rust, RISC Zero toolchain ve ilgili araçları kurar

set -e  # Herhangi bir hatada çık

echo "RISC Zero Geliştirme Ortamı Kurulumu Başlatılıyor..."

# Durum mesajları yazdırma fonksiyonu
print_status() {
    echo "[DURUM] $1"
}

# Başarı mesajları yazdırma fonksiyonu
print_success() {
    echo "[BASARILI] $1"
}

# Hata mesajları yazdırma fonksiyonu
print_error() {
    echo "[HATA] $1"
}

# apt komutları için root kontrolü
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    else
        SUDO="sudo"
    fi
}

print_status "rustup kuruluyor..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
print_success "Rustup başarıyla kuruldu"

print_status "rustup güncelleniyor..."
rustup update
print_success "Rustup güncellendi"

print_status "Sistem paket yöneticisi ile Rust toolchain kuruluyor..."
check_sudo

# APT güncelleme hatalarını yönet
print_status "APT depo durumu kontrol ediliyor..."
apt_output=$($SUDO apt update 2>&1) || apt_failed=true

if [[ "$apt_failed" == "true" ]] || echo "$apt_output" | grep -q "NO_PUBKEY\|not signed\|401\|403\|404"; then
    print_error "APT güncelleme hatası algılandı, sorunlu depolar düzeltiliyor..."
    
    # Tailscale ile ilgili tüm dosyaları temizle
    print_status "Tailscale depo dosyaları temizleniyor..."
    $SUDO rm -f /etc/apt/sources.list.d/tailscale* 2>/dev/null || true
    $SUDO rm -f /etc/apt/trusted.gpg.d/tailscale* 2>/dev/null || true
    $SUDO rm -f /usr/share/keyrings/tailscale* 2>/dev/null || true
    
    # Diğer sorunlu depoları temizle
    print_status "Diğer sorunlu depolar temizleniyor..."
    $SUDO rm -f /etc/apt/sources.list.d/nvidia-* 2>/dev/null || true
    $SUDO rm -f /etc/apt/sources.list.d/google-* 2>/dev/null || true  
    $SUDO rm -f /etc/apt/sources.list.d/wine* 2>/dev/null || true
    $SUDO rm -f /etc/apt/sources.list.d/chrome* 2>/dev/null || true
    
    # APT önbelleğini temizle
    print_status "APT önbelleği temizleniyor..."
    $SUDO apt clean
    $SUDO apt autoclean
    
    # Depo listelerini temizle ve yeniden oluştur
    $SUDO rm -rf /var/lib/apt/lists/*
    
    print_status "APT depoları yeniden güncelleniyor..."
    if ! $SUDO apt update; then
        print_error "Hala sorun var, temel depo ile devam ediliyor..."
        # En temel Ubuntu depolarıyla devam et
        echo "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -sc) main restricted universe multiverse" | $SUDO tee /etc/apt/sources.list.d/ubuntu-main.list
        $SUDO apt update
    fi
fi

# Cargo kurulumunu dene, hata alırsa alternatif yöntem kullan
print_status "Cargo kuruluyor..."
if ! $SUDO apt install -y cargo 2>/dev/null; then
    print_status "APT ile cargo kurulamadı, rustup ile kurulan cargo kullanılacak..."
    print_success "Rustup ile kurulan cargo kullanılacak"
else
    print_success "Cargo apt ile kuruldu"
fi

print_status "Cargo kurulumu doğrulanıyor..."
cargo --version
print_success "Cargo doğrulaması tamamlandı"

print_status "rzup kuruluyor..."
curl -L https://risczero.com/install | bash
source ~/.bashrc
print_success "rzup kuruldu"

print_status "rzup kurulumu doğrulanıyor..."
# rzup PATH'ini ekle
export PATH="$HOME/.risc0/bin:/root/.risc0/bin:$PATH"
echo 'export PATH="$HOME/.risc0/bin:/root/.risc0/bin:$PATH"' >> ~/.bashrc

if command -v rzup &> /dev/null; then
    rzup --version
    print_success "rzup doğrulaması tamamlandı"
else
    print_error "rzup PATH'te bulunamadı, farklı konumlar deneniyor..."
    
    # Muhtemel rzup konumlarını kontrol et
    possible_paths=(
        "$HOME/.risc0/bin"
        "/root/.risc0/bin" 
        "$HOME/.rzup/bin"
        "/root/.rzup/bin"
        "$HOME/.local/bin"
        "/usr/local/bin"
    )
    
    rzup_found=false
    for path in "${possible_paths[@]}"; do
        if [ -f "$path/rzup" ]; then
            print_status "rzup bulundu: $path/rzup"
            export PATH="$path:$PATH"
            echo "export PATH=\"$path:\$PATH\"" >> ~/.bashrc
            rzup_found=true
            break
        fi
    done
    
    if [ "$rzup_found" = true ]; then
        rzup --version
        print_success "rzup doğrulaması tamamlandı"
    else
        print_error "rzup kurulumu başarısız olmuş olabilir"
        print_status "rzup'ı manuel olarak yeniden kurmayı deneyin:"
        print_status "curl -L https://risczero.com/install | bash"
        exit 1
    fi
fi

print_status "RISC Zero Rust Toolchain kuruluyor..."
rzup install rust
print_success "RISC Zero Rust toolchain kuruldu"

print_status "cargo-risczero kuruluyor..."
cargo install cargo-risczero
print_success "cargo-risczero cargo ile kuruldu"

print_status "cargo-risczero rzup ile kuruluyor..."
rzup install cargo-risczero
print_success "cargo-risczero rzup ile kuruldu"

print_status "rustup tekrar güncelleniyor..."
rustup update
print_success "Rustup güncellendi"

print_status "Bento-client kuruluyor..."
cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli
print_success "Bento-client kuruldu"

print_status ".bashrc dosyasında PATH güncelleniyor..."
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
print_success "PATH güncellendi"

print_status "Bento-client kurulumu doğrulanıyor..."
if command -v bento_cli &> /dev/null; then
    bento_cli --version
    print_success "Bento-client doğrulaması tamamlandı"
else
    print_error "bento_cli PATH'te bulunamadı"
    export PATH="$HOME/.cargo/bin:$PATH"
    if command -v bento_cli &> /dev/null; then
        bento_cli --version
        print_success "PATH güncellemesi sonrası Bento-client doğrulaması tamamlandı"
    else
        print_error "bento_cli kurulumu başarısız olmuş olabilir"
    fi
fi

print_status "Boundless CLI kuruluyor..."
cargo install --locked boundless-cli
print_success "Boundless CLI kuruldu"

print_status "Boundless CLI için PATH güncelleniyor..."
export PATH=$PATH:/root/.cargo/bin:$HOME/.cargo/bin
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
print_success "Boundless CLI için PATH güncellendi"

print_status "Boundless CLI kurulumu doğrulanıyor..."
if command -v boundless &> /dev/null; then
    boundless -h
    print_success "Boundless CLI doğrulaması tamamlandı"
else
    print_error "boundless komutu PATH'te bulunamadı"
    export PATH="$HOME/.cargo/bin:$PATH"
    if command -v boundless &> /dev/null; then
        boundless -h
        print_success "PATH güncellemesi sonrası Boundless CLI doğrulaması tamamlandı"
    else
        print_error "Boundless CLI kurulumu başarısız olmuş olabilir"
    fi
fi

print_success "RISC Zero Geliştirme Ortamı Kurulumu Tamamlandı!"
echo ""
echo "Sonraki Adımlar:"
echo "1. Terminalinizi yeniden başlatın veya şu komutu çalıştırın: source ~/.bashrc"
echo "2. Tüm araçların çalıştığını doğrulayın:"
echo "   - cargo --version"
echo "   - rzup --version"
echo "   - bento_cli --version"
echo "   - boundless -h"
echo ""
echo "Artık RISC Zero ile geliştirme yapmaya hazırsınız!"
