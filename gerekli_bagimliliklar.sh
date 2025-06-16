#!/bin/bash

set -euo pipefail

echo -e "\e[35m===== Gerekli Bağımlılıklar Yüklenmeye Başlandı - Hazırlayan: UfukDegen =====\e[0m"

# 1. Rustup kurulumu
echo -e "\e[36m>>> [1/13] Rustup kuruluyor...\e[0m"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# 2. Rustup güncelleme
echo -e "\e[36m>>> [2/13] Rustup güncelleniyor...\e[0m"
rustup update

# 3. Gerekli sistem paketleri
echo -e "\e[36m>>> [3/13] Sistem paketleri kuruluyor (cargo)...\e[0m"
sudo apt update && sudo apt install -y cargo

# 4. Cargo versiyon kontrolü
echo -e "\e[36m>>> [4/13] Cargo sürümü:\e[0m"
cargo --version

# 5. rzup kurulumu
echo -e "\e[36m>>> [5/13] rzup kuruluyor...\e[0m"
curl -L https://risczero.com/install | bash

# 6. rzup path aktifleştirme
echo -e "\e[36m>>> [6/13] rzup ortam değişkenleri yükleniyor...\e[0m"
source ~/.bashrc || true
source ~/.profile || true

# 7. rzup versiyon kontrolü
echo -e "\e[36m>>> [7/13] rzup sürümü:\e[0m"
rzup --version

# 8. RISC Zero Rust toolchain kurulumu
echo -e "\e[36m>>> [8/13] RISC Zero toolchain kuruluyor...\e[0m"
rzup install rust

# 9. cargo-risczero kurulumu
echo -e "\e[36m>>> [9/13] cargo-risczero kuruluyor...\e[0m"
cargo install cargo-risczero || true
rzup install cargo-risczero || true

# 10. Rust tekrar güncelleniyor
echo -e "\e[36m>>> [10/13] Rust tekrar güncelleniyor...\e[0m"
rustup update

# 11. Bento client kurulumu
echo -e "\e[36m>>> [11/13] Bento client kuruluyor...\e[0m"
cargo install --git https://github.com/risc0/risc0 bento-client --bin bento_cli

# 12. Path ayarları
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.profile
source ~/.bashrc || true
source ~/.profile || true

# 13. Boundless CLI kurulumu
echo -e "\e[36m>>> [12/13] Boundless CLI kuruluyor...\e[0m"
cargo install --locked boundless-cli

# PS1 hatasını engelle (unbound variable fix)
echo -e "\e[36m>>> .bashrc içinde PS1 hatası kontrol ediliyor...\e[0m"
if grep -q "^PS1=" ~/.bashrc; then
  sed -i 's/^PS1=/[ -z "${PS1-}" ] || PS1=/' ~/.bashrc
  echo -e "\e[32m✔ PS1 unbound hatası için düzeltme uygulandı.\e[0m"
fi

# Doğrulama
echo -e "\e[36m>>> Boundless CLI kontrol ediliyor...\e[0m"
if command -v boundless &> /dev/null; then
  echo -e "\e[32m✔ Tüm bağımlılıklar başarıyla kuruldu. Artık Boundless node kurulumuna geçebilirsiniz.\e[0m"
else
  echo -e "\e[31m✖ Boundless CLI kurulamadı. Lütfen adımları kontrol edin.\e[0m"
fi
