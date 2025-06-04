# README

Ce projet contient :

```
scripts/
├── venv/                  ← Environnement virtuel Python
├── send_to_tb/            ← Package Python “send_to_tb” (votre code refactoré)
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
│       └── log_cleaner.py      ← purge logic
└── autres_scripts…         ← (vos autres scripts, par exemple `setup_sitrad.sh`)
```

Le dépôt Git se trouve dans `scripts/`.

Avant de lancer quoi que ce soit, vous devez :

* Créer et activer un environnement virtuel Python à la racine de `scripts/`
* Installer les dépendances
* Rendre vos scripts exécutables

---

## 1. Créer et activer l’environnement virtuel

Placez-vous à la racine du dossier `scripts/` :

```bash
cd /chemin/vers/scripts
```

Créez un venv (si ce n’est pas déjà fait) :

```bash
python3 -m venv venv
```

Activez le venv :

### Sur Linux / macOS

```bash
source venv/bin/activate
```

### Sur Windows (PowerShell)

```powershell
.\venv\Scripts\Activate.ps1
```

### Sur Windows (cmd.exe)

```cmd
.\venv\Scripts\activate.bat
```

---

## 2. Installer les dépendances Python

Une fois le venv activé :

```bash
pip install --upgrade pip
pip install requests
```

Si vous ajoutez d’autres bibliothèques, créez un `requirements.txt` :

```bash
pip install -r requirements.txt
```

---

## 3. Préparer le fichier `.env`

Dans `scripts/send_to_tb/.env` :

```ini
###############################################################################
# ▶︎ Credentials
###############################################################################
DEVICE_TOKEN=LP7c1aIMyA713GNB0HoJ

###############################################################################
# ▶︎ Paths
###############################################################################
DB_PATH=~/.wine/drive_c/ProgramData/Full Gauge/Sitrad/data.db
STATE_FILE=.last_rowid
LOG_FILE=sitrad_push.log

###############################################################################
# ▶︎ Behaviour
###############################################################################
MAX_MSGS_PER_SEC=10          # limite douce : 10 messages par seconde
MAX_RETRY=5                  # tentatives max (split & back-off compris)
INITIAL_DELAY_MS=200         # back-off initial (millisecondes)
LOG_LEVEL=INFO               # DEBUG | INFO | WARNING | ERROR
MIN_VALID_TS_MS=946684800000 # 2000-01-01 UTC en ms
PURGE_LOG_DAYS=7             # auto-delete logs older than X days
```

> `DB_PATH` : utilisez l’expansion `~` ou un chemin absolu complet.
> Les fichiers `STATE_FILE` et `LOG_FILE` seront créés à l’exécution.

---

## 4. Rendre les scripts exécutables

Depuis la racine `scripts/` :

```bash
chmod +x send_to_tb/main.py
chmod +x autres_scripts/*.sh
```

Exemple :

```bash
chmod +x setup_sitrad.sh
```

---

## 5. Lancer le programme `send_to_tb`

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

## 6. Fonctionnement interne

* `main.py` :

  * Charge `.env`
  * Crée `SitradDataFetcher`
  * Crée `ThingsBoardClient`
  * Lance `SendToLauncher`

* `SitradDataFetcher`

  * `read_last_id()`
  * `fetch_rows(last_id)`
  * `build_payload(row)`
  * `fetch_and_prepare()`

* `ThingsBoardClient`

  * Calcule l'URL
  * `post_json_with_retry()`
  * `send_resilient(batch)`

* `SendToLauncher`

  * `start()`
  * Coupe les payloads en lots selon `MAX_MSGS_PER_SEC`
  * Appelle `client.send_resilient(...)`
  * Écrit le `rowid` courant

---

## 7. Extensions possibles

* Nouveau `DataFetcher` (MySQL, API, CSV...) → hériter de `DataFetcher`
* Nouveau `HttpClient` (Kafka, API IoT...) → hériter de `HttpClient`

Le coeur `SendToLauncher` reste indépendant de la source ou destination.

---

## FAQ

**Q : Où dois-je exécuter `chmod +x` ?**
R : Sur chaque script que vous voulez lancer directement :

```bash
chmod +x send_to_tb/main.py
chmod +x setup_sitrad.sh
```

**Q : Comment tester à vide ?**
R : Mettez `MAX_MSGS_PER_SEC=0` dans le `.env` ou commentez `send_resilient(...)`

**Q : Pourquoi `~` dans `DB_PATH` ?**
R : Il est automatiquement converti avec `os.path.expanduser()`.

**Q : Dois-je versionner `venv/` ?**
R : Non. Ajoutez-le dans `.gitignore`. Utilisez `requirements.txt`.

---

Avec ce README, vous pouvez :

* Initialiser un venv
* Installer les dépendances
* Rendre les scripts exécutables
* Lancer `send_to_tb`

Adaptez les chemins selon votre configuration.
