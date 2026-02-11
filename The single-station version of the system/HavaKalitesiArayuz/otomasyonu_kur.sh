#!/bin/bash

# --- AYARLAR ---
# Eğer klasör ismin farklıysa burayı kontrol et
SCRIPT_YOLU="$HOME/HavaKalitesiArayuz/baslat.sh" 

# --- RENKLER ---
YESIL='\033[1;32m'
MAVI='\033[1;34m'
SARI='\033[1;33m'
KIRMIZI='\033[1;31m'
NC='\033[0m'

clear
echo -e "${MAVI}=================================================${NC}"
echo -e "${MAVI}   ⚙️  HAVA KALİTESİ OTOMASYON KURULUMU         ${NC}"
echo -e "${MAVI}=================================================${NC}"
echo ""

# 1. Script Dosyası Kontrolü (Güvenlik Önlemi)
if [ ! -f "$SCRIPT_YOLU" ]; then
    echo -e "${KIRMIZI}HATA: Başlatma dosyası ($SCRIPT_YOLU) bulunamadı!${NC}"
    echo "Lütfen 'HavaKalitesiArayuz' klasörünün adını veya yerini kontrol edin."
    exit 1
fi

# 2. Klasör Kontrolü ve Oluşturma
HEDEF_KLASOR="$HOME/.config/autostart"
DOSYA_YOLU="$HEDEF_KLASOR/hava-kalitesi.desktop"

echo -e "${SARI}[ADIM 1] Başlangıç klasörü kontrol ediliyor...${NC}"
if [ ! -d "$HEDEF_KLASOR" ]; then
    mkdir -p "$HEDEF_KLASOR"
    echo "Klasör oluşturuldu: $HEDEF_KLASOR"
else
    echo "Klasör zaten mevcut."
fi
echo ""

# 3. .desktop Dosyasını Oluşturma
echo -e "${SARI}[ADIM 2] Otomatik başlatma dosyası yapılandırılıyor...${NC}"

# ÖNEMLİ DEĞİŞİKLİK BURADA: --app-mode eklendi
cat <<EOF > "$DOSYA_YOLU"
[Desktop Entry]
Type=Application
Exec=gnome-terminal -- /bin/bash -c "$SCRIPT_YOLU --app-mode; exec bash"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Hava Kalitesi Otomasyonu
Comment=Otomatik başlatıcı
Terminal=true
EOF

if [ -f "$DOSYA_YOLU" ]; then
    echo "Dosya oluşturuldu: $DOSYA_YOLU"
else
    echo -e "${KIRMIZI}HATA: Dosya oluşturulamadı!${NC}"
    exit 1
fi
echo ""

# 4. İzinleri Verme
echo -e "${SARI}[ADIM 3] Çalıştırma izinleri veriliyor...${NC}"
chmod +x "$DOSYA_YOLU"

echo ""
echo -e "${MAVI}=================================================${NC}"
echo -e "${YESIL}✅ İŞLEM BAŞARILI: Otomasyon Güncellendi!${NC}"
echo -e "Bilgisayar açıldığında sistem 'Uygulama Modunda' başlayacak."
echo -e "${MAVI}=================================================${NC}"
