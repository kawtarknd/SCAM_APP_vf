# 🩺 SCAM – Surveillance Contextuelle des Anomalies Cardio-Motrices

SCAM est un système IoT intelligent permettant de surveiller en temps réel les paramètres physiologiques (BPM, SpO₂) et les mouvements (accélération & gyroscope) afin de détecter les anomalies telles que la tachycardie, la bradycardie et les chutes.  
Il combine un ESP32 équipé de capteurs, un backend distribué, une interface Flutter Web déployée sur Netlify, et des services Cloud pour le traitement, l’authentification et la gestion des alertes.

---

## 🚀 Fonctionnalités principales

- Lecture des données physiologiques via capteurs (BPM, SpO₂)  
- Analyse des signaux inertiels (accéléromètre & gyroscope)  
- Détection en temps réel des anomalies cardio-motrices  
- Gestion des alertes et historisation  
- Dashboard Flutter Web affichant :  
  - Courbes BPM / SpO₂  
  - Détection des anomalies  
  - Historique des alertes  
- Authentification sécurisée via Firebase  
- Communication IoT → Cloud via ESP32

---

## 🏗️ Architecture générale

![Architecture Générale](./architecture.jpeg)

---

## 🛠️ Technologies utilisées

### Frontend
- Flutter Web  
- Déploiement sur Netlify

### Backend / Traitement
- API + traitement Python déployé sur Render

### Cloud et Données
- Firebase Authentication  
- Firebase Realtime Database (données en direct)  
- Supabase (historisation, stockage des alertes)

### Matériel
- ESP32  
- Capteur MAX30102  
- MPU6050 (IMU)

---

## 🔗 Fonctionnement global

1. **ESP32** lit les données BPM, SpO₂, accéléromètre et gyroscope  
2. Il envoie les données vers le **backend Render**, qui applique le traitement  
3. Render publie les alertes vers **Supabase** et les données instantanées vers **Firebase**  
4. L’interface **Flutter Web (Netlify)** récupère les données et affiche :  
   - Les mesures en temps réel  
   - Les alertes détectées  
   - L’historique des anomalies

Tout le pipeline fonctionne en continu et en temps réel.

---

## ❤️ Équipe

Projet réalisé en collaboration entre les étudiants de **Master Data Analytics & AI** et **Master Ingénierie Informatique & Systèmes Distribués**, dans le cadre du module **Réseaux & IoT**.

### Master ADIA - Analytiques des données & Intelligence Artificielle
- Elqorachi Hind  
- Khair Latifa  
- Kinad Kawtar

### Master IISE — Ingénierie Informatique & Systèmes Distribués
- Ahbri Jihad  
- Baba Farah  
- El Hefiane Meryem

---

## 📄 Licence

Projet académique — non destiné à un usage commercial.
