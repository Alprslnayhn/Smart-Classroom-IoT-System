#!/bin/bash

# --- RENKLER ---
KIRMIZI='\033[1;31m'
YESIL='\033[1;32m'
SARI='\033[1;33m'
MAVI='\033[1;34m'
NC='\033[0m' # No Color

clear
echo -e "${MAVI}=================================================${NC}"
echo -e "${MAVI}   🗑️  KISAYOL TEMİZLEME ARACI             ${NC}"
echo -e "${MAVI}=================================================${NC}"
echo ""

# SİLİNECEK DOSYA YOLLARI
MENU_KISAYOLU="$HOME/.local/share/applications/havalandirma.desktop"
MASAUSTU_ENG="$HOME/Desktop/havalandirma.desktop"
MASAUSTU_TR="$HOME/Masaüstü/havalandirma.desktop"

# 1. MENÜ KISAYOLUNU SİL
if [ -f "$MENU_KISAYOLU" ]; then
    rm "$MENU_KISAYOLU"
    echo -e "${YESIL}✅ Başlat menüsü kısayolu silindi.${NC}"
else
    echo -e "${SARI}ℹ️  Başlat menüsünde kısayol bulunamadı.${NC}"
fi

# 2. MASAÜSTÜ KISAYOLUNU SİL (İngilizce/Türkçe klasör kontrolü)
SILDIM=0

if [ -f "$MASAUSTU_ENG" ]; then
    rm "$MASAUSTU_ENG"
    echo -e "${YESIL}✅ Masaüstü kısayolu silindi (Desktop).${NC}"
    SILDIM=1
fi

if [ -f "$MASAUSTU_TR" ]; then
    rm "$MASAUSTU_TR"
    echo -e "${YESIL}✅ Masaüstü kısayolu silindi (Masaüstü).${NC}"
    SILDIM=1
fi

if [ $SILDIM -eq 0 ]; then
     echo -e "${SARI}ℹ️  Masaüstünde kısayol bulunamadı.${NC}"
fi

# 3. VERİTABANINI GÜNCELLE
# Menüden anında kaybolması için veritabanını yeniliyoruz
update-desktop-database "$HOME/.local/share/applications" > /dev/null 2>&1

echo ""
echo -e "${MAVI}İşlem tamamlandı! Artık arama yaptığında çıkmayacak.${NC}"