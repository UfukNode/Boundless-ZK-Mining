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
print_status "APT depo listesi güncelleniyor..."
if ! $SUDO apt update 2>/dev/null; then
    print_error "APT güncelleme hatası algılandı, sorunlu depolar düzeltiliyor..."
    
    # Tailscale depo anahtarı sorununu çöz
    if $SUDO apt update 2>&1 | grep -q "tailscale"; then
        print_status "Tailscale depo anahtarı düzeltiliyor..."
        $SUDO rm -f /etc/apt/sources.list.d/tailscale.list
        $SUDO apt-key del $(apt-key list 2>/dev/null | grep -A1 "Tailscale" | head -1 | awk '{print $2}' | tr -d '/') 2>/dev/null || true
    fi
    
    # NVIDIA depo sorunlarını çöz
    if $SUDO apt update 2>&1 | grep -q "nvidia"; then
        print_status "NVIDIA depo sorunları düzeltiliyor..."
        $SUDO rm -f /etc/apt/sources.list.d/nvidia-* 2>/dev/null || true
    fi
    
    # Chrome depo sorunlarını çöz  
    if $SUDO apt update 2>&1 | grep -q "chrome\|google"; then
        print_status "Chrome/Google depo sorunları düzeltiliyor..."
        $SUDO rm -f /etc/apt/sources.list.d/google-* 2>/dev/null || true
    fi
    
    # Wine depo sorunlarını çöz
    if $SUDO apt update 2>&1 | grep -q "wine"; then
        print_status "Wine depo sorunları düzeltiliyor..."
        $SUDO rm -f /etc/apt/sources.list.d/wine* 2>/dev/null || true
    fi
    
    print_status "Sorunlu depolar temizlendi, tekrar güncelleniyor..."
    $SUDO apt update
fi

$SUDO apt install -y cargo
print_success "Cargo apt ile kuruldu"

print_status "Cargo kurulumu doğrulanıyor..."
cargo --version
print_success "Cargo doğrulaması tamamlandı"

print_status "rzup kuruluyor..."
curl -L https://risczero.com/install | bash
source ~/.bashrc
print_success "rzup kuruldu"

print_status "rzup kurulumu doğrulanıyor..."
if command -v rzup &> /dev/null; then
    rzup --version
    print_success "rzup doğrulaması tamamlandı"
else
    print_error "rzup PATH'te bulunamadı, tekrar sourcing deneniyor..."
    export PATH="$HOME/.rzup/bin:$PATH"
    if command -v rzup &> /dev/null; then
        rzup --version
        print_success "PATH güncellemesi sonrası rzup doğrulaması tamamlandı"
    else
        print_error "rzup kurulumu başarısız olmuş olabilir"
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
