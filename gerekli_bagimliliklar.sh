#!/bin/bash

set -euo pipefail

echo "[INFO] Boundless & RISC Zero kurulum scripti başlatılıyor..."

# Rustup kurulumu
if ! command -v rustup &> /dev/null; then
    echo "[INFO] Rustup kuruluyor..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "[INFO] Rustup zaten kurulu."
fi

# Rustup güncelleme
rustup update

# Rust toolchain ve cargo kurulumu
echo "[INFO] Cargo kuruluyor..."
sudo apt update
sudo apt install -y cargo

# Cargo doğrulama
cargo --version

# rzup kurulumu
echo "[INFO] RISC Zero rzup kuruluyor..."
curl -L https://risczero.com/install | bash
source ~/.bashrc

# rzup doğrulama
rzup --version

# RISC Zero Rust Toolchain kurulumu
rzup install rust

# cargo-risczero kurulumu
cargo install cargo-risczero || true
rzup install cargo-risczero

# Bento-client kurulumu
echo "[INFO] Bento client kuruluyor..."
cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli

# PATH ayarı
if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# Bento client doğrulama
bento_cli --version

# Boundless CLI kurulumu
echo "[INFO] Boundless CLI kuruluyor..."
cargo install --locked boundless-cli || true

# /root/.cargo/bin PATH ayarı (özellikle sudo kullananlar için)
if ! echo "$PATH" | grep -q "/root/.cargo/bin"; then
    export PATH=$PATH:/root/.cargo/bin
    echo 'export PATH=$PATH:/root/.cargo/bin' >> ~/.bashrc
    source ~/.bashrc
fi

# Boundless CLI doğrulama
boundless -h

echo "[SUCCESS] Kurulum tamamlandı!"
