# README

## Description du projet

Ce projet permet de collecter automatiquement les données d'un dispositif industriel (ex: TC-900 de Full Gauge), de les formater, et de les envoyer vers ThingsBoard Cloud à l'aide d'un client HTTP résilient. Il est conçu pour être fiable, modulaire, facilement maintenable et extensible.

---

## Arborescence du projet

```
scripts/
├── venv/                   ← Environnement virtuel Python
├── send_to_tb/             ← Package Python “send_to_tb” (code principal)
│   ├── __init__.py
│   ├── .env
│   ├── main.py
│   ├── clients/
│   │   ├── __init__.py
│   │   ├── http_client.py
│   │   └── thingsboard_client.py
│   ├── fetchers/
│   │   ├── __init__.py
│   │   ├── data_fetcher.py
│   │   └── sitrad_data_fetcher.py
│   ├── launcher/
│   │   ├── __init__.py
│   │   └── send_launcher.py
│   └── utils/
│       ├── __init__.py  
│       └── log_cleaner.py      ← purge automatique des logs
├── setup_bash/             ← Scripts bash opérationnels
│   ├── setup_timer.sh          ← Installe le timer systemd
│   ├── kill_timer.sh           ← Supprime le timer
│   └── setup_sitrad.sh         ← Lance Wine + Sitrad PRO
```

---

## Prérequis

* Python 3.7+
* `requests` (lib HTTP)
* Linux ou Raspberry Pi avec `systemd --user`
* Accès à ThingsBoard (token + device)
* Base de données SQLite (générée par Sitrad)

---

## Installation pas à pas

### 1. Créer et activer l'environnement virtuel

```bash
cd /chemin/vers/scripts
python3 -m venv venv
source venv/bin/activate
```

### 2. Installer les dépendances Python

Une fois le venv activé :

```bash
pip install --upgrade pip
pip install requests
```

Si vous ajoutez d'autres bibliothèques, créez un fichier `requirements.txt` :

```bash
pip install -r requirements.txt
```

### 3. Préparer le fichier `.env`

Dans `scripts/send_to_tb/.env` :

```ini
###############################################################################
# ▶️ Credentials
###############################################################################
DEVICE_TOKEN=LP7c1aIMyA713GNB0HoJ

###############################################################################
# ▶️ Paths
###############################################################################
DB_PATH=~/.wine/drive_c/ProgramData/Full Gauge/Sitrad/data.db
STATE_FILE=.last_rowid
LOG_FILE=sitrad_push.log

###############################################################################
# ▶️ Behaviour
###############################################################################
MAX_MSGS_PER_SEC=10          # limite douce : 10 messages par seconde
MAX_RETRY=5                  # tentatives max (split & back-off compris)
INITIAL_DELAY_MS=200         # back-off initial (millisecondes)
LOG_LEVEL=INFO               # DEBUG | INFO | WARNING | ERROR
MIN_VALID_TS_MS=946684800000 # 2000-01-01 UTC en ms
PURGE_LOG_DAYS=7             # auto-delete logs older than X days
```

> `DB_PATH` : utilisez l'expansion `~` ou un chemin absolu complet.
> Les fichiers `STATE_FILE` et `LOG_FILE` seront créés à l'exécution.

### 4. Rendre les scripts exécutables

Depuis la racine `scripts/` :

```bash
chmod +x send_to_tb/main.py
chmod +x setup_bash/setup_timer.sh
chmod +x setup_bash/kill_timer.sh
chmod +x setup_bash/setup_sitrad.sh
```

### 5. Lancer le programme `send_to_tb`

Activez le venv :

```bash
source venv/bin/activate
```

Option A :

```bash
cd send_to_tb
python main.py
```

Ou si `main.py` est exécutable :

```bash
./main.py
```

Option B :

```bash
cd scripts
python -m send_to_tb.main
```

---

##Exécution automatique toutes les 30 secondes

### Installer le timer :

```bash
./setup_bash/setup_timer.sh
```

Cela crée :

* `~/.config/systemd/user/send_to_tb.service`
* `~/.config/systemd/user/send_to_tb.timer`

Et active le timer.

### Vérifier le statut :

```bash
systemctl --user list-timers
journalctl --user -u send_to_tb.service -n 50
```

### Supprimer le timer :

```bash
./setup_bash/kill_timer.sh
```

---

## Lancer Sitrad PRO (via Wine)

```bash
./setup_bash/setup_sitrad.sh
```

---

## Fonctionnement interne

### `main.py`

* Charge `.env`
* Crée `SitradDataFetcher`
* Crée `ThingsBoardClient`
* Lance `SendToLauncher`

### `SitradDataFetcher`

* `read_last_id()`
* `fetch_rows(last_id)`
* `build_payload(row)`
* `fetch_and_prepare()`

### `ThingsBoardClient`

* Calcule l'URL d’envoi
* `post_json_with_retry()`
* `send_resilient(batch)`

### `SendToLauncher`

* `start()`
* Coupe les payloads en lots selon `MAX_MSGS_PER_SEC`
* Appelle `client.send_resilient(...)`
* Écrit le `rowid` courant

---

## FAQ

**Q : Je veux voir le `rowid` actuel ?**

```bash
cat send_to_tb/.last_rowid
```

**Q : Le script tourne-t-il ?**

```bash
systemctl --user list-timers
```

**Q : Comment voir les journaux d'envoi ?**

```bash
journalctl --user -u send_to_tb.service -n 50
```

**Q : Où dois-je exécuter `chmod +x` ?**

```bash
chmod +x send_to_tb/main.py
chmod +x setup_bash/setup_sitrad.sh
```

**Q : Comment tester à vide ?**

```ini
MAX_MSGS_PER_SEC=0
```

Ou commentez `send_resilient(...)` dans le code.

**Q : Pourquoi `~` dans `DB_PATH` ?**
R : Il est automatiquement converti par `os.path.expanduser()`.

**Q : Dois-je versionner `venv/` ?**
R : Non. Ajoutez-le à `.gitignore`.

---

## Possibilités d'extension

* Nouveau `DataFetcher` (MySQL, API, CSV...) → hériter de `DataFetcher`
* Nouveau `HttpClient` (Kafka, API IoT...) → hériter de `HttpClient`
* Le coeur `SendToLauncher` reste indépendant de la source ou destination

---

Avec ce README, vous pouvez :

* Initialiser un environnement virtuel
* Installer les dépendances
* Rendre les scripts exécutables
* Lancer manuellement ou automatiquement `send_to_tb`
* Superviser les émissions vers ThingsBoard

> Adaptez les chemins selon votre configuration.
