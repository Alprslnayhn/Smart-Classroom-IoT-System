const express = require('express');
const session = require('express-session');
const sqlite3 = require('sqlite3').verbose();
const crypto = require('crypto');
const bodyParser = require('body-parser');
const https = require('https'); 
const fs = require('fs');       
const WebSocket = require('ws'); 
const dilPaketi = require('./dil_paketi');
const os = require('os');

const app = express();
const portWeb = 3000; // Web (SSL)
const portESP = 3001; // ESP (Düz - Hızlı)
const DB_NAME = './sensor_verileri.db';

// --- GÜVENLİK (SSL) ---
const serverOptions = {
    key: fs.readFileSync('server.key'),
    cert: fs.readFileSync('server.crt')
};

// ====================================================
// ⚙️ AMFİ İÇİN ALGORİTMA AYARLARI
// ====================================================
const MOVING_AVG_WINDOW = 30; 
const MEDIAN_WINDOW = 5;      
const CO2_HEDEF = 1000;       
const CO2_TOLERANS_UST = 100; // 1100 ppm Fan AÇ
const CO2_TOLERANS_ALT = 150; // 850 ppm Fan KAPA

let bufferCO2 = [], bufferTemp = [], bufferPM25 = []; 
let fanDurumu = 0, alarmDurumu = 0;

const db = new sqlite3.Database(DB_NAME);

// --- YARDIMCI FONKSİYONLAR ---
function ortalamaAl(arr) { return arr.length === 0 ? 0 : (arr.reduce((a, b) => a + b, 0) / arr.length); }
function medyanAl(arr) { if (arr.length === 0) return 0; const s = [...arr].sort((a,b)=>a-b); return s[Math.floor(s.length/2)]; }
function sifrele(text) { return crypto.createHash('md5').update(text).digest('hex'); }

// ====================================================
// 1. ESP32 WEBSOCKET (PORT 3001)
// ====================================================
const wss = new WebSocket.Server({ port: portESP });
console.log(`📡 ESP32 Kapısı Açıldı: Port ${portESP}`);

wss.on('connection', (ws, req) => {
    const ip = req.socket.remoteAddress;
    console.log(`[BAĞLANTI] ESP32 Geldi! IP: ${ip}`);

    ws.on('message', (message) => {
        try {
            let sicaklik = 0, nem = 0, co2 = 0, pm25 = 0;
            const msgStr = message.toString();

            if (msgStr.startsWith('\x1F')) {
                const parts = msgStr.substring(1).split('|');
                if (parts.length >= 4) {
                    sicaklik = parseFloat(parts[0]); 
                    nem = parseFloat(parts[1]); 
                    co2 = parseInt(parts[2]); 
                    pm25 = parseInt(parts[3]);
                }
            } else {
                const json = JSON.parse(msgStr);
                sicaklik = json.sicaklik; nem = json.nem; co2 = json.co2; pm25 = json.pm25;
            }

            let sonPM = bufferPM25.length > 0 ? bufferPM25[bufferPM25.length - 1] : 0;
            if (pm25 > 0) bufferPM25.push(pm25); else { bufferPM25.push(sonPM); pm25 = sonPM; }

            bufferCO2.push(co2); bufferTemp.push(sicaklik);
            if (bufferCO2.length > MOVING_AVG_WINDOW) bufferCO2.shift();
            if (bufferTemp.length > MOVING_AVG_WINDOW) bufferTemp.shift();
            if (bufferPM25.length > MEDIAN_WINDOW) bufferPM25.shift();

            const islenmisCO2 = Math.round(ortalamaAl(bufferCO2));
            const islenmisTemp = parseFloat(ortalamaAl(bufferTemp).toFixed(1));
            //const islenmisPM25 = medyanAl(bufferPM25); 
            const islenmisPM25 = 10;
            if (fanDurumu === 0) {
                if (islenmisCO2 > (CO2_HEDEF + CO2_TOLERANS_UST)) fanDurumu = 1;
            } else {
                if (islenmisCO2 < (CO2_HEDEF - CO2_TOLERANS_ALT)) fanDurumu = 0;
            }
            
            alarmDurumu = (islenmisCO2 > 1500) ? 1 : 0;
            if (alarmDurumu === 1) fanDurumu = 1;

            console.log(`[VERI] T:${islenmisTemp} | CO2:${islenmisCO2} | Fan:${fanDurumu}`);

            const stmt = db.prepare(`INSERT INTO olcumler (ham_co2, islenmis_co2, sicaklik, nem, pm25, fan_durumu, alarm_durumu) VALUES (?, ?, ?, ?, ?, ?, ?)`);
            stmt.run(co2, islenmisCO2, islenmisTemp, nem, islenmisPM25, fanDurumu, alarmDurumu);
            stmt.finalize();
        } catch (e) { console.error("Veri Hatası:", e.message); }
    });
});

// ====================================================
// 2. WEB PANEL (PORT 3000)
// ====================================================
app.set('view engine', 'ejs');
app.use(express.static('public'));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(session({ secret: 'gizli', resave: false, saveUninitialized: true }));

app.use((req, res, next) => {
    if (!req.session.lang) req.session.lang = 'tr';
    if (req.query.lang) req.session.lang = req.query.lang;
    res.locals.lang = req.session.lang;
    res.locals.text = dilPaketi[req.session.lang];
    res.locals.user = req.session.user || null;
    next();
});

// --- API: GRAFİKLER İÇİN ---
app.get('/api/guncel', (req, res) => {
    if (!req.session.girisYapti) return res.status(401).json({error: 'Yetkisiz'});
    const sqlSon = "SELECT *, datetime(tarih, 'localtime') as tarih FROM olcumler ORDER BY id DESC LIMIT 1";
    const sqlGecmis = "SELECT *, datetime(tarih, 'localtime') as tarih FROM olcumler ORDER BY id DESC LIMIT 50";
    const sqlLog = "SELECT *, datetime(tarih, 'localtime') as tarih FROM loglar ORDER BY id DESC LIMIT 5";

    db.get(sqlSon, [], (err, sonVeri) => {
        db.all(sqlGecmis, [], (err, gecmis) => {
            const v = sonVeri || { sicaklik: 0, nem: 0, islenmis_co2: 0, pm25: 0, fan_durumu: 0, alarm_durumu: 0 };
            db.all(sqlLog, [], (err, loglar) => {
                res.json({
                    sensor: { sicaklik: v.sicaklik, nem: v.nem, co2: v.islenmis_co2, pm25: v.pm25 },
                    gecmis: gecmis.reverse(),
                    alarm: (v.alarm_durumu === 1),
                    fan: (v.fan_durumu === 1),
                    loglar: loglar
                });
            });
        });
    });
});

// --- GÜVENLİ LOGIN MANTIĞI (KİLİTLEME SİSTEMİ) ---
app.get('/', (req, res) => { if (req.session.girisYapti) res.redirect('/dashboard'); else res.redirect('/login'); });
app.get('/login', (req, res) => { res.render('login', { hata: null }); });

app.post('/login', (req, res) => {
    const { kadi, sifre } = req.body;
    
    // 1. Önce kullanıcıyı bul (Şifresiz)
    db.get("SELECT * FROM kullanicilar WHERE kullanici_adi = ?", [kadi], (err, user) => {
        // Kullanıcı yoksa
        if (!user) {
            return res.render('login', { hata: "Böyle bir kullanıcı bulunamadı!" });
        }

        // 2. Zaten kilitli mi?
        if (user.kilitli_mi === 1) {
            return res.render('login', { hata: "LOCKED" }); // Kilitli kodu
        }

        const sifreliGiris = sifrele(sifre);

        // 3. Şifre Doğru mu?
        if (user.sifre === sifreliGiris) {
            // BAŞARILI: Hataları sıfırla, içeri al
            db.run("UPDATE kullanicilar SET hatali_giris = 0 WHERE id = ?", [user.id]);
            req.session.girisYapti = true;
            req.session.user = user;
            res.redirect('/dashboard');
        } else {
            // BAŞARISIZ: Hata sayısını arttır
            const yeniHataSayisi = user.hatali_giris + 1;
            
            if (yeniHataSayisi >= 5) {
                // 5. Hata: Kilitle!
                db.run("UPDATE kullanicilar SET hatali_giris = ?, kilitli_mi = 1 WHERE id = ?", [yeniHataSayisi, user.id]);
                return res.render('login', { hata: "LOCKED" });
            } else {
                // Uyarı ver
                db.run("UPDATE kullanicilar SET hatali_giris = ? WHERE id = ?", [yeniHataSayisi, user.id]);
                return res.render('login', { hata: `Hatalı Şifre! Kalan Hakkınız: ${5 - yeniHataSayisi}` });
            }
        }
    });
});

// --- DASHBOARD ROUTE ---
app.get('/dashboard', (req, res) => {
    if (!req.session.girisYapti) return res.redirect('/login');
    const sqlSon = "SELECT *, datetime(tarih, 'localtime') as tarih FROM olcumler ORDER BY id DESC LIMIT 1";
    const sqlGecmis = "SELECT *, datetime(tarih, 'localtime') as tarih FROM olcumler ORDER BY id DESC LIMIT 50";
    const sqlLog = "SELECT *, datetime(tarih, 'localtime') as tarih FROM loglar ORDER BY id DESC LIMIT 50";

    db.get(sqlSon, [], (e, s) => {
        db.all(sqlGecmis, [], (e, g) => {
            db.all(sqlLog, [], (e, l) => {
                const v = s || { sicaklik: 0, nem: 0, islenmis_co2: 0, pm25: 0, fan_durumu: 0, alarm_durumu: 0 };
                res.render('dashboard', { 
                    sensor: { sicaklik: v.sicaklik, nem: v.nem, co2: v.islenmis_co2, pm25: v.pm25 },
                    alarm: (v.alarm_durumu===1), fan: (v.fan_durumu===1), gecmis: g.reverse(), konsol: l 
                });
            });
        });
    });
});

// --- ADMIN ROTALARI ---
app.get('/admin', (req, res) => {
    if (req.session.girisYapti && req.session.user.rol === 'admin') {
        db.all("SELECT * FROM kullanicilar", [], (err, users) => {
            res.render('admin', { users: users });
        });
    } else { res.redirect('/dashboard'); }
});

app.post('/admin/ekle', (req, res) => {
    if (req.session.girisYapti && req.session.user.rol === 'admin') {
        const { yenikadi, yenisifre, yenirol } = req.body;
        const stmt = db.prepare("INSERT INTO kullanicilar (kullanici_adi, sifre, rol) VALUES (?, ?, ?)");
        stmt.run(yenikadi, sifrele(yenisifre), yenirol, (err) => { res.redirect('/admin'); });
        stmt.finalize();
    } else { res.redirect('/dashboard'); }
});

app.get('/admin/kilit-ac/:id', (req, res) => {
    if (req.session.girisYapti && req.session.user.rol === 'admin') {
        const id = req.params.id;
        db.run("UPDATE kullanicilar SET hatali_giris = 0, kilitli_mi = 0 WHERE id = ?", [id], (err) => {
            res.redirect('/admin');
        });
    } else { res.redirect('/dashboard'); }
});

app.get('/logout', (req, res) => { req.session.destroy(); res.redirect('/login'); });

const serverHTTPS = https.createServer(serverOptions, app);
serverHTTPS.listen(portWeb, '0.0.0.0', () => { console.log(`✅ WEB: https://localhost:${portWeb}`); });