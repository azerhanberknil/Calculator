# CalcPro

Güzel, modern bir arayüze sahip, bilimsel işlemler de dahil olmak üzere tüm matematiksel hesaplamaları yapabilen Android uygulaması.

---

## Özellikler

- ✅ Temel işlemler: toplama, çıkarma, çarpma, bölme
- ✅ Trigonometrik: sin, cos, tan, asin, acos, atan, sinh, cosh, tanh
- ✅ Logaritmik: log (10 tabanı), ln (doğal log), log2
- ✅ Kuvvet/kök: x², x³, xʸ, √x, ∛x
- ✅ Sabitler: π (pi), e (Euler)
- ✅ Faktöriyel (n!)
- ✅ Yüzde (%)
- ✅ Parantez desteği, iç içe fonksiyonlar
- ✅ Bellek işlemleri: M+, M-, MR, MC
- ✅ Radyan / Derece modu
- ✅ 2. Fonksiyon modu (ters trigonometri)
- ✅ 50 işlemlik hesap geçmişi
- ✅ Canlı sonuç önizleme
- ✅ Haptic (titreşim) geri bildirim
- ✅ Özel matematiksel ifade ayrıştırıcı (bağımlılık gerektirmez)

---

## Kurulum

### Gereksinimler

- Flutter SDK 3.2+  
- Android Studio veya VS Code (Flutter eklentisiyle)
- Android SDK (API 21+)

### Adımlar

```bash
# 1. Bu klasöre gidin
cd calcpro

# 2. Bağımlılıkları yükleyin
flutter pub get

# 3. Bağlı Android cihazda veya emülatörde çalıştırın
flutter run

# 4. Sürüm APK oluşturun
flutter build apk --release

# 5. App Bundle oluşturun (Play Store için önerilir)
flutter build appbundle --release
```

---

## Play Store'a Yükleme

### 1. İmzalama anahtarı oluşturun
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 2. `android/key.properties` dosyasını oluşturun
```properties
storePassword=ŞİFRENİZ
keyPassword=ANAHTAR_ŞİFRENİZ
keyAlias=upload
storeFile=../../../upload-keystore.jks
```

### 3. `android/app/build.gradle` dosyasına imzalama ekleyin
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. App Bundle oluşturun ve yükleyin
```bash
flutter build appbundle --release
```
Oluşturulan dosya: `build/app/outputs/bundle/release/app-release.aab`

Bu `.aab` dosyasını Google Play Console'a yükleyin.

---

## Uygulama Kimliği (Package Name) Değiştirme

`android/app/build.gradle` dosyasında:
```gradle
applicationId "com.sizinisim.calcpro"
```

---

## Minimum Android Sürümü

`android/app/build.gradle` dosyasında:
```gradle
minSdkVersion 21   // Android 5.0+
targetSdkVersion 34
```

---

## Renk Teması

| Renk | Kullanım |
|------|----------|
| `#08081A` | Arkaplan |
| `#7C3AED` | Mor vurgu (operatörler, eşittir başlangıç) |
| `#06B6D4` | Cyan vurgu (eşittir bitiş, önizleme) |
| `#1C1C3E` | Sayı düğmeleri |
| `#0D2828` | Bilimsel düğmeler |
| `#3D0909` | Temizle/Sil düğmeleri |

---

## Lisans

MIT — özgürce kullanın ve özelleştirin.
