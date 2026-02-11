import numpy as np
import matplotlib.pyplot as plt

# ==========================================
# 1. AYARLAR (Senin Belirlediğin Değerler)
# ==========================================
MOVING_AVG_WINDOW = 30  # Hareketli Ortalama Penceresi
MEDIAN_WINDOW = 5       # Medyan Penceresi
CO2_HEDEF = 1000        # Hedef Sınır
TOLERANS = 150          # Histerezis (+- 150)
ACMA_ESIGI = CO2_HEDEF + TOLERANS # 1150
KAPANMA_ESIGI = CO2_HEDEF - TOLERANS # 850

# ==========================================
# 2. SANAL VERİ ÜRETİMİ (Sanal Amfi)
# ==========================================
# 300 saniyelik (5 dakika) bir simülasyon yapalım
zaman = np.arange(0, 300)
gercek_co2 = np.zeros(300)

# Senaryo:
for t in range(300):
    if t < 50: 
        gercek_co2[t] = 400
    elif t < 150:
        gercek_co2[t] = gercek_co2[t-1] + 10 # Hızlı artış
    elif t < 250:
        gercek_co2[t] = gercek_co2[t-1] - 6  # Fan etkisi (Düşüş)
    else:
        gercek_co2[t] = gercek_co2[t-1] + 1  # Hafif artış

# Gürültü ve Hata Ekleme
np.random.seed(42) # Her seferinde aynı rastgelelik olsun
gurultulu_co2 = gercek_co2 + np.random.normal(0, 50, 300) # +-50 ppm titreme

# HATA SENARYOSU: Ani Sıçramalar (Spike)
gurultulu_co2[100] = 5000 # Sensör hatası (Çok yüksek)
gurultulu_co2[200] = 0    # Sensör okuyamadı (Sıfır)

# ==========================================
# 3. ALGORİTMALARIN UYGULANMASI
# ==========================================
islenmis_veri = []
fan_durumu = []
fan_acik_mi = False
buffer = [] # Hareketli ortalama için
median_buffer = [] # Medyan için

for i in range(300):
    anlik_deger = gurultulu_co2[i]
    
    # A) Medyan Filtresi (Hata Ayıklama - Toz/CO2 Spike Temizliği)
    median_buffer.append(anlik_deger)
    if len(median_buffer) > MEDIAN_WINDOW: median_buffer.pop(0)
    temiz_veri = np.median(median_buffer) 
    
    # B) Hareketli Ortalama (Yumuşatma)
    buffer.append(temiz_veri) # Medyandan geçeni tampona atıyoruz
    if len(buffer) > MOVING_AVG_WINDOW: buffer.pop(0)
    ortalama_veri = np.mean(buffer)
    
    islenmis_veri.append(ortalama_veri)
    
    # C) Histerezis (Fan Kontrol)
    if ortalama_veri > ACMA_ESIGI:
        fan_acik_mi = True
    elif ortalama_veri < KAPANMA_ESIGI:
        fan_acik_mi = False
    
    # Grafikte göstermek için fan durumunu ölçekliyorum (400 kapalı, 1400 açık gibi dursun)
    fan_durumu.append(1400 if fan_acik_mi else 400)

# ==========================================
# 4. GRAFİK ÇİZİMİ
# ==========================================
plt.figure(figsize=(12, 6))

# Ham Veri (Gri ve titrek)
plt.plot(zaman, gurultulu_co2, color='lightgray', label='Ham Sensör Verisi (Gürültülü)', linewidth=1)

# Algoritma Sonucu (Kırmızı ve pürüzsüz)
plt.plot(zaman, islenmis_veri, color='red', label='Algoritma Çıktısı (İşlenmiş)', linewidth=2)

# Fan Durumu (Yeşil Alan)
# Fanın çalıştığı yerleri yeşil boyayalım
plt.fill_between(zaman, 400, 1600, where=[f > 500 for f in fan_durumu], color='green', alpha=0.1, label='Fan AÇIK Bölgesi')

# Eşik Değerleri (Kesik Çizgiler)
plt.axhline(y=ACMA_ESIGI, color='blue', linestyle='--', label=f'Fan Açma Eşiği ({ACMA_ESIGI})')
plt.axhline(y=KAPANMA_ESIGI, color='green', linestyle='--', label=f'Fan Kapama Eşiği ({KAPANMA_ESIGI})')

plt.title('130 Kişilik Amfi Algoritma Simülasyonu')
plt.xlabel('Zaman (Saniye)')
plt.ylabel('CO2 Seviyesi (ppm)')
plt.legend(loc='upper left')
plt.grid(True)
plt.tight_layout()

print("Grafik oluşturuluyor... Pencere açılınca inceleyebilirsin.")
plt.show()
