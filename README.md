# 🕌 qcf_quran_plus

[![Pub Version](https://img.shields.io/pub/v/qcf_quran_plus?color=blue&style=flat-square)](https://pub.dev/packages/qcf_quran_plus)
[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter&style=flat-square)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A **lightweight, high-performance Flutter Quran package** powered by the official **QCF (Hafs) font**.

Designed for professional Islamic applications, this package provides a fully offline, 60fps optimized Quran rendering engine complete with Uthmani Tajweed rules, smart search, and a comprehensive metadata API.

---

## 📸 Screenshots

<p align="center">
  <img width="250" alt="Mushaf View" src="https://github.com/user-attachments/assets/482a0b7f-f048-4434-86af-c40e301dc503" />
  <img width="250" alt="Tajweed Support" src="https://github.com/user-attachments/assets/65dc7b33-e80e-4cd4-ac4e-8d80957ae654" />
</p>

<p align="center">
  <img width="250" alt="Surah List Mode" src="https://github.com/user-attachments/assets/5a4652cf-9b53-4521-991f-304afd91a6cd" />
  <img width="250" alt="Dark Mode" src="https://github.com/user-attachments/assets/da1d0f89-41e2-4e2e-8c21-6a50bece6786" />
</p>

<p align="center">
  <img width="250" alt="Search Engine" src="https://github.com/user-attachments/assets/4bac8673-06e8-4478-bf2f-55f331cd61f2" />
  <img width="250" alt="Metadata Details" src="https://github.com/user-attachments/assets/8caa32df-7168-48e3-8c1e-657710b6f5ad" />
</p>

---

## ✨ Key Features

- **📖 Authentic Mushaf Rendering:** Full 604-page Quran with exact Madinah Mushaf layout.
- **⚡ High Performance:** Zero network requests, built for 60fps smooth scrolling, with an isolated font-loading engine.
- **🎨 Uthmani Tajweed Rules:** Native coloring for Tajweed in both Light & Dark modes without performance drops.
- **🔍 Smart Offline Search:** Fast, diacritic-insensitive Arabic search with automatic text normalization.
- **🎯 Dynamic Highlighting:** Pass a list of highlights to seamlessly integrate audio-syncing and bookmarks.
- **📜 Vertical Reading Mode:** Scrollable Surah lists ideal for Tafsir, translation, and audio players.
- **📊 Comprehensive Metadata:** Instant access to Surah names, Juz, Quarter (Rub al-Hizb), Makki/Madani info, and page lookups.

---

## 🚀 Getting Started

### 1. Add Dependencies

Update your `pubspec.yaml`:

```yaml
dependencies:
  qcf_quran_plus: ^latest_version
  scrollable_positioned_list: ^0.3.8