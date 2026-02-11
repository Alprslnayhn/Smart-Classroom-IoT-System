#!/bin/bash

# --- AYARLAR ---
UYGULAMA_ADI="Havalandırma Sistemi"
CALISMA_DIZINI="/home/aaron/HavaKalitesiArayuz"
SCRIPT_YOLU="$CALISMA_DIZINI/baslat.sh"
ICON_ADI="weather-clear" 
KUR_SCRIPT="$CALISMA_DIZINI/otomasyonu_kur.sh"

# --- RENKLER ---
YESIL='\033[1;32m'
MAVI='\033[1;34m'
KIRMIZI='\033[1;31m'
SARI='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# =================================================
#        ÇALIŞMA MODU KONTROLÜ
# =================================================
MOD="yonetici"
if [[ "$1" == "--app-mode" ]]; then
    MOD="uygulama"
fi

# =================================================
#         1. FONKSİYONLAR
# =================================================

function kisayol_olustur() {
    MENU_DOSYASI="$HOME/.local/share/applications/havalandirma.desktop"
    
    # Masaüstü ve Menü kısayolunu oluştur
    cat <<EOF > "$MENU_DOSYASI"
[Desktop Entry]
Type=Application
Name=$UYGULAMA_ADI
Comment=Akıllı Hava Kalitesi Kontrol Paneli
Exec=$SCRIPT_YOLU --app-mode
Icon=$ICON_ADI
Terminal=true
Categories=Utility;Engineering;
EOF
    chmod +x "$MENU_DOSYASI"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null

    if [ -d "$HOME/Desktop" ]; then DESKTOP_DIR="$HOME/Desktop"; else DESKTOP_DIR="$HOME/Masaüstü"; fi
    MASAUSTU_DOSYASI="$DESKTOP_DIR/havalandirma.desktop"

    cp "$MENU_DOSYASI" "$MASAUSTU_DOSYASI"
    chmod +x "$MASAUSTU_DOSYASI"
    gio set "$MASAUSTU_DOSYASI" metadata::trusted true 2>/dev/null
}

# =================================================
#         2. YÖNETİCİ MODU (İLK KURULUM)
# =================================================
if [[ "$MOD" == "yonetici" ]]; then
    clear
    echo -e "${MAVI}=================================================${NC}"
    echo -e "${MAVI}   🛠️  $UYGULAMA_ADI - SİSTEM BAŞLATILIYOR      ${NC}"
    echo -e "${MAVI}=================================================${NC}"
    echo ""
    
    echo -e "${CYAN}[KURULUM 1/2]${NC} Masaüstü kısayolu kontrol ediliyor..."
    kisayol_olustur
    echo -e "${YESIL}>> Kısayol hazır.${NC}"
    echo ""

    echo -e "${CYAN}[KURULUM 2/2]${NC} Otomasyon kontrol ediliyor..."
    if [ -f "$KUR_SCRIPT" ]; then 
        bash "$KUR_SCRIPT" > /dev/null 2>&1
        echo -e "${YESIL}>> Sistem başlangıca eklendi.${NC}"
    fi
    echo ""
    echo -e "${YESIL}✅ Kurulumlar tamamlandı. Sunucuya geçiliyor...${NC}"
    sleep 2
fi

# =================================================
#         3. UYGULAMA MODU (SUNUCU BAŞLATMA)
# =================================================

if [[ "$MOD" == "uygulama" ]]; then
    clear
    echo -e "${MAVI}=================================================${NC}"
    echo -e "${MAVI}   🚀 $UYGULAMA_ADI AKTİF (SSL MODU)          ${NC}"
    echo -e "${MAVI}=================================================${NC}"
fi

cd "$CALISMA_DIZINI" || { echo -e "${KIRMIZI}HATA: Dizin yok!${NC}"; read -p "Enter..." wait; exit 1; }

# --- HOTSPOT MANTIĞI (ESKİ KODDAN GERİ GETİRİLDİ) ---
WIFI_ARAYUZ=$(nmcli device | grep wifi | grep -v p2p | awk '{print $1}' | head -n 1)

if [ -z "$WIFI_ARAYUZ" ]; then
    echo -e "${KIRMIZI}HATA: Wi-Fi kartı bulunamadı!${NC}"
    read -p "Çıkış..." wait; exit 1
fi

echo -e "${CYAN}[AĞ]${NC} Hotspot kontrol ediliyor..."
AKTIF_BAGLANTI=$(nmcli connection show --active | grep "HavaKalitesi")

if [ -z "$AKTIF_BAGLANTI" ]; then
    echo -e "${SARI}>> Hotspot başlatılıyor (HavaKalitesi / 12345678)...${NC}"
    
    # Eski veya hatalı bağlantıları temizle
    sudo nmcli connection delete "HavaKalitesi" > /dev/null 2>&1
    sudo nmcli device disconnect "$WIFI_ARAYUZ" > /dev/null 2>&1
    nmcli radio wifi on
    
    # Yeni Hotspot Oluştur
    sudo nmcli con add type wifi ifname "$WIFI_ARAYUZ" con-name "HavaKalitesi" autoconnect yes ssid "HavaKalitesi" > /dev/null 2>&1
    sudo nmcli con modify "HavaKalitesi" 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared > /dev/null 2>&1
    sudo nmcli con modify "HavaKalitesi" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "12345678" > /dev/null 2>&1
    
    # Bağlantıyı Aktif Et
    sudo nmcli con up "HavaKalitesi" > /dev/null 2>&1
    echo -e "${YESIL}>> Hotspot aktif edildi!${NC}"
fi

sleep 3

# IP Adresini Bul
IP_ADRES=$(ip -4 addr show "$WIFI_ARAYUZ" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if [ -z "$IP_ADRES" ]; then IP_ADRES="BULUNAMADI"; fi

echo -e "✅ Hotspot IP: ${MAVI}$IP_ADRES${NC}"

echo -e "${CYAN}[SUNUCU]${NC} Port 3000 hazırlanıyor..."
fuser -k 3000/tcp > /dev/null 2>&1 
pkill -f "node server.js" > /dev/null 2>&1
sleep 1

echo -e "${YESIL}🚀 Sunucu Başlatıldı!${NC}"
echo -e "Web Arayüzü: https://$IP_ADRES:3000"
echo -e "Durdurmak için ${KIRMIZI}sistemi_kaldir.sh${NC} dosyasını çalıştırın."

if [ "$IP_ADRES" != "BULUNAMADI" ]; then
    # HTTPS olarak aç
    (sleep 5 && xdg-open "https://$IP_ADRES:3000") > /dev/null 2>&1 &
fi

node server.js