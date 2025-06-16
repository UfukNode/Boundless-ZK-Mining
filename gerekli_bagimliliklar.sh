#!/bin/bash

set -euo pipefail

echo -e "\e[35m===== Gerekli Bağımlılıklar Yüklenmeye Başlandı - Hazırlayan: UfukDegen =====\e[0m"

# 1. Rustup kurulumu
echo -e "\e[36m>>> [1/12] Rustup kuruluyor...\e[0m"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# 2. Rustup güncelleme
echo -e "\e[36m>>> [2/12] Rustup güncelleniyor...\e[0m"
rustup update

# 3. Gerekli paketler kuruluyor (cargo)
echo -e "\e[36m>>> [3/12] Gerekli sistem paketleri kuruluyor (cargo)...\e[0m"
sudo apt update && sudo apt install -y cargo

# 4. Cargo versiyon kontrolü
echo -e "\e[36m>>> [4/12] Cargo sürümü:\e[0m"
cargo --version

# 5. rzup kurulumu
echo -e "\e[36m>>> [5/12] rzup kuruluyor...\e[0m"
curl -L https://risczero.com/install | bash
source ~/.bashrc || true
source ~/.profile || true

# 6. rzup versiyon kontrolü
echo -e "\e[36m>>> [6/12] rzup sürümü:\e[0m"
rzup --version

# 7. RISC Zero Rust Toolchain kurulumu
echo -e "\e[36m>>> [7/12] RISC Zero Rust toolchain kuruluyor...\e[0m"
rzup install rust

# 8. cargo-risczero kurulumu
echo -e "\e[36m>>> [8/12] cargo-risczero kuruluyor...\e[0m"
cargo install cargo-risczero || true
rzup install cargo-risczero || true

# 9. Rust tekrar güncelleniyor
echo -e "\e[36m>>> [9/12] Rust tekrar güncelleniyor...\e[0m"
rustup update

# 10. Bento client kurulumu
echo -e "\e[36m>>> [10/12] Bento client kuruluyor...\e[0m"
cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.profile
source ~/.bashrc || true
source ~/.profile || true

# 11. Bento versiyon kontrolü
echo -e "\e[36m>>> [11/12] Bento sürümü:\e[0m"
bento_cli --version

# 12. Boundless CLI kurulumu
echo -e "\e[36m>>> [12/12] Boundless CLI kuruluyor...\e[0m"
cargo install --locked boundless-cli
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.profile
source ~/.bashrc || true
source ~/.profile || true

# .bashrc dosyasındaki PS1 hatasını engelle
echo -e "\e[36m>>> .bashrc içinde PS1 hatası kontrol ediliyor...\e[0m"
if grep -q "^PS1=" ~/.bashrc; then
  sed -i 's/^PS1=/[ -z "${PS1-}" ] || PS1=/' ~/.bashrc
  echo -e "\e[32m✔ PS1 unbound hatası için düzeltme uygulandı.\e[0m"
fi

# Doğrulama
echo -e "\e[36m>>> Boundless CLI kontrol ediliyor...\e[0m"
if boundless -h &> /dev/null; then
  echo -e "\e[32m✔ Tüm bağımlılıklar başarıyla kuruldu. Artık Boundless node kurulumuna geçebilirsiniz.\e[0m"
else
  echo -e "\e[31m✖ Boundless CLI kurulamadı. Tekrar deneyin.\e[0m"
fi
