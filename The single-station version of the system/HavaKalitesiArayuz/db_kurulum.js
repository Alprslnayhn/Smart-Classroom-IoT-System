const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./sensor_verileri.db');
const crypto = require('crypto');

function sifrele(text) { return crypto.createHash('md5').update(text).digest('hex'); }

db.serialize(() => {
    // 1. Ölçümler Tablosu (GÜNCELLENDİ)
    // Ham veri ve İşlenmiş veri ayrıldı. Fan ve Alarm durumu eklendi.
    db.run(`CREATE TABLE IF NOT EXISTS olcumler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tarih DATETIME DEFAULT CURRENT_TIMESTAMP,
        ham_co2 INTEGER,        -- Sensörden gelen saf veri
        islenmis_co2 INTEGER,   -- Algoritmalarla düzeltilmiş veri
        sicaklik REAL,
        nem REAL,
        pm25 INTEGER,
        fan_durumu INTEGER DEFAULT 0,  -- 0: Kapalı, 1: Açık
        alarm_durumu INTEGER DEFAULT 0 -- 0: Normal, 1: Tehlike
    )`);

    // 2. Kullanıcılar
    db.run(`CREATE TABLE IF NOT EXISTS kullanicilar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici_adi TEXT UNIQUE,
        sifre TEXT,
        rol TEXT,
        hatali_giris INTEGER DEFAULT 0,
        kilitli_mi INTEGER DEFAULT 0
    )`);

    // 3. Loglar
    db.run(`CREATE TABLE IF NOT EXISTS loglar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kullanici TEXT,
        islem TEXT,
        detay TEXT,
        tarih DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    // Admin Ekle
    const stmt = db.prepare("INSERT INTO kullanicilar (kullanici_adi, sifre, rol) VALUES (?, ?, ?)");
    stmt.run("admin", sifrele("1234"), "admin", (err) => {
        if (!err) console.log("✅ Admin kullanıcısı oluşturuldu.");
    });
    stmt.finalize();

    console.log("✅ Veritabanı (SSL Uyumlu ve Algoritma Destekli) Hazır.");
});
db.close();