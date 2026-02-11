#!/bin/bash

# --- DOSYA YOLU AYARLARI ---
AUTOSTART_DOSYASI="$HOME/.config/autostart/hava-kalitesi.desktop"
MENU_DOSYASI="$HOME/.local/share/applications/havalandirma.desktop"
# Masaüstü yolunu otomatik bulmaya çalış, bulamazsa varsayılanları dene
if [ -d "$HOME/Desktop" ]; then
    MASAUSTU_DOSYASI="$HOME/Desktop/havalandirma.desktop"
elif [ -d "$HOME/Masaüstü" ]; then
    MASAUSTU_DOSYASI="$HOME/Masaüstü/havalandirma.desktop"
else
    MASAUSTU_DOSYASI="$HOME/Desktop/havalandirma.desktop"
fi

# --- RENKLER ---
YESIL='\033[1;32m'
KIRMIZI='\033[1;31m'
SARI='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${KIRMIZI}=================================================${NC}"
echo -e "${KIRMIZI}   🗑️  SİSTEM KALDIRMA VE TEMİZLİK ARACI        ${NC}"
echo -e "${KIRMIZI}=================================================${NC}"
echo ""
echo "Bu işlem sistemdeki şu bileşenleri SİLECEK:"
echo "1. Çalışan Sunucu ve Hotspot ağı"
echo "2. Otomatik Başlatma Ayarı (Autostart)"
echo "3. Uygulama Menüsü Simgesi"
echo "4. Masaüstü Kısayolu"
echo ""

read -p "Her şeyi silip kaldırmak istiyor musunuz? (e/h): " CEVAP
if [[ "$CEVAP" != "e" && "$CEVAP" != "E" ]]; then
    echo "İşlem iptal edildi."
    exit 0
fi

echo ""
echo -e "${CYAN}--- TEMİZLİK BAŞLIYOR ---${NC}"

# 1. SUNUCU VE AĞI DURDUR
echo -e "${SARI}[1/4] Sunucu ve Ağ kapatılıyor...${NC}"
fuser -k 3000/tcp > /dev/null 2>&1
pkill -f "node server.js" > /dev/null 2>&1
sudo nmcli connection delete "HavaKalitesi" > /dev/null 2>&1
echo -e "${YESIL}>> Servisler durduruldu.${NC}"

# 2. OTOMASYONU SİL
echo -e "${SARI}[2/4] Otomatik başlatma kaldırılıyor...${NC}"
if [ -f "$AUTOSTART_DOSYASI" ]; then
    rm "$AUTOSTART_DOSYASI"
    echo -e "${YESIL}>> Autostart dosyası silindi.${NC}"
else
    echo ">> Otomasyon zaten yok."
fi

# 3. MENÜ KISAYOLUNU SİL
echo -e "${SARI}[3/4] Uygulama menüden siliniyor...${NC}"
if [ -f "$MENU_DOSYASI" ]; then
    rm "$MENU_DOSYASI"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    echo -e "${YESIL}>> Menü girdisi silindi.${NC}"
else
    echo ">> Menüde zaten yok."
fi

# 4. MASAÜSTÜ KISAYOLUNU SİL
echo -e "${SARI}[4/4] Masaüstü kısayolu siliniyor...${NC}"
if [ -f "$MASAUSTU_DOSYASI" ]; then
    rm "$MASAUSTU_DOSYASI"
    echo -e "${YESIL}>> Masaüstü kısayolu silindi.${NC}"
else
    echo ">> Masaüstü kısayolu bulunamadı."
fi

echo ""
echo -e "${YESIL}✅ KALDIRMA İŞLEMİ TAMAMLANDI.${NC}"
echo "Sistem tertemiz!"
sleep 2
