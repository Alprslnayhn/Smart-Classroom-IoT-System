#!/bin/bash

# --- RENKLER ---
YESIL='\033[1;32m'
KIRMIZI='\033[1;31m'
MAVI='\033[1;34m'
SARI='\033[1;33m'
NC='\033[0m' # Renk Yok

clear
echo -e "${MAVI}=================================================${NC}"
echo -e "${MAVI}   🗑️ HAVA KALİTESİ OTOMASYONU KALDIRMA ARACI   ${NC}"
echo -e "${MAVI}=================================================${NC}"
echo ""

# Hedef dosya (Az önce oluşturduğumuz dosya)
HEDEF_DOSYA="$HOME/.config/autostart/hava-kalitesi.desktop"

echo -e "${SARI}Otomatik başlatma dosyası aranıyor...${NC}"

if [ -f "$HEDEF_DOSYA" ]; then
    echo -e "Bulunan Dosya: ${MAVI}$HEDEF_DOSYA${NC}"
    
    # Silme komutu
    rm "$HEDEF_DOSYA"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${YESIL}✅ BAŞARILI: Otomatik başlatma kaldırıldı.${NC}"
        echo "Bilgisayar açıldığında artık sistem kendiliğinden başlamayacak."
    else
        echo -e "${KIRMIZI}❌ HATA: Dosya silinemedi!${NC}"
    fi
else
    echo ""
    echo -e "${KIRMIZI}❌ HATA: Kaldırılacak dosya bulunamadı.${NC}"
    echo "Zaten silinmiş olabilir."
fi

echo ""
echo -e "${MAVI}=================================================${NC}"
