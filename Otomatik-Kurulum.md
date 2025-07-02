# Boundless Script ile Otomatik Kurulum Rehberi:

## Başlamadan Önce Yapmanız Gerekenler:

1. Yeni bir cüzdan oluştur.  
   Base Sepolia ağına **5 USDC (test token)** ve **1-2 USD değerinde Sepolia ETH** gönder.

2. Aşağıdaki adımları takip ederek test tokenlarını al:

   - https://faucet.circle.com üzerinden test USDC al.  
   - Sepolia ETH’yi https://superbridge.app/base-sepolia ile Base Sepolia’ya bridge et.

3. Aşağıdaki siteden Base Sepolia RPC al:  
   → https://dashboard.blockpi.io bağlantıya git ve kayıt ol.
   → Ücretsiz kayıt ol ve "Base-Sepolia" endpoint’i oluştur.  

📌 Bu miktarlar ve işlemler tüm ağlar için geçerlidir.  
Base Mainnet, Ethereum Sepolia veya diğer desteklenen ağlarda da bu adımları benzer şekilde uygulayabilirsiniz.

---

## Vast.ai Üzerinden SSH Key Ekleme:

1. Bilgisayarınızda **Terminal** (veya PowerShell) açın.

2. Aşağıdaki komutu girin:

```bash
ssh-keygen
```

![456629831-d6da34b4-a93b-4db7-a755-5eeb644545ec](https://github.com/user-attachments/assets/9fa93642-343f-43d0-bd62-33e01303fbdd)


3. Gelen 3 soruya da sadece **Enter** diyerek geçin.

4. SSH anahtarınız oluşturulacak ve bulunduğu yolu gösterecektir. Bu yolu kopyalayın.

5. Terminale aşağıdaki komutu girerek public anahtarı görüntüleyin:

   ```bash
   cat ~/.ssh/id_rsa.pub
   ```
![456631922-a2da6842-94dd-42ef-9fe8-971474780f37](https://github.com/user-attachments/assets/4a532bab-83e9-4674-ad5c-4a9a5fdcb7ba)

6. [https://cloud.vast.ai/?ref\_id=222215](https://cloud.vast.ai/?ref_id=222215) adresine gidin → sol menüden **Keys** sekmesine tıklayın.

7. Sağ üstte `New` deyip kopyaladığınız satırı yapıştırarak kaydedin.


---

## Vast.ai Template Seçimi ve Sunucu Kiralama

Boundless node’unu çalıştırmak için uygun bir sunucu kiralamanız gerekir. Aşağıdaki adımları takip edin:

1. Vast paneline giriş yapın ve sol üstten **Templates** sekmesine tıklayın.

2. Açılan listeden **Ubuntu 22.04 VM** template’ini seçin.

![456634644-452408df-df90-481d-8999-abdec53de3e7](https://github.com/user-attachments/assets/25523cf4-4c98-4a3c-b740-6b411b00320c)

3. Üst menüden GPU seçimini yapın: **RTX 3090** veya **RTX 4090** önerilir.

   > Daha düşük sistemlerde de çalışabilir fakat performans düşer.

4. Depolamayı **150-200 GB SSD** aralığında ayarlayın. (NVMe önerilir)

5. Sol üstteki sıralama menüsünden **Price (inc)** seçeneğini işaretleyin.

   > Bu sayede fiyat/performans oranı en iyi olanlar üstte listelenir.

6. Uygun bir cihazı seçip **Rent** butonuna tıklayın.

![456635435-29c2df12-340e-4aa9-adf9-d684398945a8](https://github.com/user-attachments/assets/edba704c-dca1-4cef-9ff7-cb62c98acdff)

---

## Sunucuya Giriş

1. Vast panelinden sol menüdeki **Instances** kısmına gidin.

2. Cihazınızın üzerinde bulunan terminal butonuna tıklayın ve **SSH** ile başlayan komutu kopyalayın.

3. Terminal veya PowerShell'e yapıştırarak sunucunuza giriş yapın.

![456638486-dc14064a-63f0-43a9-b31e-81a2ca2a4bbd](https://github.com/user-attachments/assets/6e1d6649-c4a0-4e2e-99e5-2a8285307fc1)

---

## Kurulum:

### Scripti İndir:

```bash
wget https://raw.githubusercontent.com/UfukNode/Boundless-ZK-Mining/main/boundless.sh
```

### Scripti Çalıştır:

```bash
chmod +x boundless.sh
sudo ./boundless.sh
```

⌛️ Kurulum işlemi ortalama 45-50 dakika sürecektir. Lütfen Sabırlı olun.

Örnek Çıktı:

![456566176-e55f5a37-e7b5-480d-b9d7-961d888f5bcd](https://github.com/user-attachments/assets/6607eac0-27ef-4f68-92ad-bc52c1f1c129)

---

### Kurulum Süreci ve Giriş Bilgileri

Kurulum tamamlandıktan sonra sizden bazı bilgiler girmeniz istenecek:

- Hangi ağda prover olmak istediğinizi seçeceksiniz.
- Daha önce hazırladığınız cüzdan adresini girmeniz gerekecek.
- Ücretsiz olarak oluşturduğunuz RPC bağlantısını girmeniz istenecek.
(Hangi ağı seçtiyseniz, o ağa ait RPC kullanılmalı.)

Örnek Çıktı:

![image](https://github.com/user-attachments/assets/7c0aec1e-4d9f-433b-b21b-588ced4def85)

---

# RTX 4090 için Broker.toml Ayar Rehberi

### Agresif Ayar:
```toml
[prover]
mcycle_price = "0.0000000000002" 
peak_prove_khz = 500 
max_mcycle_limit = 25000
min_deadline = 180
max_concurrent_proofs = 2
lockin_priority_gas = 50000000000
```

### Dengeli Ayar:
```toml
[prover]
mcycle_price = "0.000000000001"
peak_prove_khz = 420
max_mcycle_limit = 15000
min_deadline = 240
max_concurrent_proofs = 1
lockin_priority_gas = 25000000000
```

---

## Ayarların Anlamı:

- **mcycle_price**: İş başına istediğiniz ücret yani ne kadar düşük girerseniz o kadar çok order alırsınız.
- **peak_prove_khz**: GPU'nuzun saniyede yapabileceği işlem sayısı. (GPU gücünüz önemli eğer sorun yaşarsanız, düşürün veya Benchmark testi yapın.)
- **max_mcycle_limit**: Kabul edeceğiniz en büyük iş boyutunu temsil eder.
- **min_deadline**: İşi bitirmek için minimum süre (güvenlik için)
- **max_concurrent_proofs**: Aynı anda kaç iş yapacağınız. (2 üzerine çıkmayın)
- **lockin_priority_gas**: İşi kapmak için vereceğiniz komisyon (yüksek gwei = yüksek order alma şansı)

Rekabet oldukça yüksek ve ayarlarla oynamanız gerekebilir. Mantıklarına göre oynamalar yapabilirsiniz. Her yaptığınız ayarı en az 2 saat deneyin.
