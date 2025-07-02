# Boundless Script ile Otomatik Kurulum Rehberi:

## Başlamadan Önce Yapmanız Gerekenler:

1. Yeni bir cüzdan oluştur.  
   Base Sepolia ağına **5 USDC (test token)** ve **1-2 USD değerinde Sepolia ETH** gönder.

2. Aşağıdaki adımları takip ederek test tokenlarını al:

   - https://faucet.circle.com üzerinden test USDC al.  
   - Sepolia ETH’yi https://superbridge.app/base-sepolia ile Base Sepolia’ya bridge et.

3. Aşağıdaki siteden Base Sepolia RPC al:  
   - https://dashboard.blockpi.io

   → Ücretsiz kayıt ol ve "Base-Sepolia" endpoint’i oluştur.  
   → Aylık 49$’lık paket ile daha yüksek performans elde edebilir, Boundless order’larını daha sorunsuz tamamlayabilirsin.

⚠️ Order yakalayabilmek için hızlı bir RPC kullanmanız çok önemlidir.

💡 Bu miktarlar ve işlemler tüm ağlar için geçerlidir.  
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
