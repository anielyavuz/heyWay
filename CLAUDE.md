# Pulse - Navigasyon ve Sosyal Medya Uygulaması

## Proje Amacı
Google Maps benzeri navigasyon özelliklerine sahip, kullanıcıların cafe, restoran, otel gibi mekanları keşfedip sosyal etkileşimde bulunabileceği bir mobil uygulama geliştirmek.

## Ana Özellikler
- **Navigasyon**: Harita tabanlı yön bulma ve rota planlama
- **Mekan Keşfi**: Cafe, restoran, otel gibi işletmeleri bulma
- **Sosyal Özellikler**:
  - Mekanları puanlama ve değerlendirme
  - Yorum yapma sistemi
  - Check-in özelliği(Pulse yapma)
  - Sosyal medya benzeri etkileşimler

## Teknoloji Stack
- **Platform**: Flutter (Cross-platform mobil uygulama)
- **Dil**: Dart
- **Harita**: Google Maps Flutter Plugin
- **API**: Google Places API
- **Backend**: Firebase (Auth, Firestore, Storage)

## Mevcut Durum ve Özellikler

### ✅ Tamamlanan Özellikler
1. **Google Maps Entegrasyonu**:
   - Google Maps Flutter plugin ile harita görüntüleme
   - Android ve iOS API key konfigürasyonu
   - Farklı harita türleri (Normal, Satellite, Terrain, Hybrid)
   - Zoom kontrolları ve kullanıcı konumu merkezleme

2. **Discover Screen (Keşfet Ekranı)**:
   - Tam ekran harita modu ile text modu arası geçiş
   - Arama modalı (alttan yukarı çıkan panel)
   - Yakın popüler mekanları otomatik yükleme (2 cafe, 2 restoran, 2 eğlence)
   - Tıklayarak görülebilen marker'lar (emoji ve bilgi ile)
   - Renk kodlu kategori marker'ları
   - Canlı arama ve enter ile arama seçenekleri

3. **Venue Search System**:
   - Provider tabanlı state management
   - Cache sistemi ile API optimizasyonu
   - Konum tabanlı arama
   - Kategori bazlı emoji desteği (☕️ cafe, 🍽️ restoran, 🎭 eğlence)

4. **UI/UX**:
   - Ana navigasyon: Home, Discover, Profile
   - Modern material design
   - Dark/Light theme desteği
   - Responsive tasarım

### 🔧 Teknik Detaylar
- **Marker Sistemi**: Basit tıkla-gör marker'lar (InfoWindow kullanımı)
- **Harita Kontrolları**: Zoom in/out, konum merkezleme, harita türü seçici
- **Arama Modalı**: DraggableScrollableSheet ile esnek arama paneli
- **Konum**: Geolocator ile GPS entegrasyonu
- **State Management**: Provider pattern kullanımı

### 📝 Önemli Notlar
- Marker'lar için her zaman basit InfoWindow yaklaşımı kullanılmalı
- Karmaşık custom marker implementasyonları sorun çıkarabilir
- Google Places API limitleri dikkate alınmalı
- Firebase konfigürasyonu tamamlanmış durumda

## Geliştirme Notları
Bu dosya proje geliştirme sürecinde Claude Code asistanı için referans olarak kullanılacaktır.

### Gelecek Özellikler
- Venue detay sayfaları
- Kullanıcı check-in sistemi
- Sosyal etkileşim özellikleri
- Navigasyon ve rota planlama
