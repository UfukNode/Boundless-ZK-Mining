#!/bin/bash

set -euo pipefail

echo -e "\e[35m===== Boundless Ortam Komutları Çalıştırılıyor - Hazırlayan: UfukDegen =====\e[0m"

# Rustup kurulumu
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Rustup güncelleme
rustup update

# Rust toolchain kurulumu
sudo apt update && sudo apt install -y cargo

# Cargo versiyon kontrolü
cargo --version

# rzup kurulumu
curl -L https://risczero.com/install | bash
source ~/.bashrc || true

# rzup versiyon kontrolü
rzup --version

# RISC Zero Rust toolchain kurulumu
rzup install rust

# cargo-risczero kurulumu
cargo install cargo-risczero || true
rzup install cargo-risczero || true

# Rust güncelleme tekrar
rustup update

# Bento-client kurulumu
cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc || true

# Bento versiyon kontrolü
bento_cli --version

# Boundless CLI kurulumu
cargo install --locked boundless-cli
export PATH="$PATH:$HOME/.cargo/bin"
source ~/.bashrc || true

# Boundless CLI kontrolü
boundless -h
