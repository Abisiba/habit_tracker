# Habittracker

KDE Plasma widget ve Flutter Android uygulamasından oluşan Supabase senkronize habit tracker.

## Klasorler

- `habittracker/`: KDE Plasma widget paketi.
- `habittracker-android/`: Flutter Android uygulamasi.

## Kurulum

Supabase tablo ve policy kurulumu icin:

```text
habittracker-android/KURULUM.md
```

Android APK derlemek icin:

```bash
cd habittracker-android
flutter pub get
flutter build apk --release
```

Plasma widget paketi `com.user.habittracker` id'sini kullanir. Yerel kurulumda plasmoid symlink'i su klasore bakacak sekilde ayarlanabilir:

```text
habittracker/
```
