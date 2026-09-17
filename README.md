# site-deploy

Zentraler, wiederverwendbarer GitHub-Workflow, der meine Websites per FTPS auf
den all-inkl-Webspace lädt. Jede Website ruft ihn mit ein paar Zeilen auf.

| Repo | Domain | Build | Hochgeladen wird |
|---|---|---|---|
| Portfolio-Website | michaelflohrschuetz.com | – | Repo ohne `contact-form-api/`, `ToDo.txt` |
| JustYogaRetreat | justyogaretreat.de | – | Repo ohne `assets/` |
| hpkraemerDE | kraemer-naturheilpraxis.de | `node build.js` | Repo ohne `src/`, `build.js`, `package*.json` |
| hpkraemerIT | hpkraemer.it | – | ganzes Repo |
| hallinger-gestalt-baum (Carla) | carlahallinger.de | `npm ci && npm run build` | `dist/` |

Immer ausgeschlossen: `.git*`, `.github/`, `node_modules/`, `.DS_Store`,
`README.md`, `.vscode/`. Was in `.gitignore` steht (z. B. `OLD_WP/`), ist im
CI-Checkout gar nicht vorhanden und kann nicht hochgehen.

## Ablauf

Push auf `main` → Workflow baut (falls nötig) → lädt **nur geänderte Dateien**
hoch. Im Repo gelöschte Dateien werden auch auf dem Server gelöscht. Dateien,
die nie über den Workflow hochgeladen wurden, bleiben unangetastet.

Grundlage ist die Datei `.ftp-deploy-sync-state.json`, die der Workflow im
Zielverzeichnis ablegt. Fehlt sie, bricht der nächste Lauf ab (siehe unten).

Läuft gerade ein Upload, wird er nie abgebrochen. Weitere Pushes warten, wobei
GitHub nur den **neuesten** wartenden Lauf behält; der nimmt ohnehin alle
Änderungen mit. Ein noch wartender manueller clean-slate-Lauf wird dabei aber
ebenfalls verdrängt – dann einfach erneut starten.

Vor jedem normalen Upload prüft der Workflow, ob die State-Datei auf dem Server
liegt. Fehlt sie (oder ist der Server nicht erreichbar), bricht er rot ab, statt
still einen „ersten Deploy“ ohne Löschungen zu machen.
Nach einem clean-slate-Lauf prüft er, dass auf dem Server nur noch Einträge
liegen, die aus diesem Upload stammen. Ist das Leeren teilweise gescheitert,
wird der Lauf rot und nennt die Reste.

Ein Build kann Warnungen melden, indem er je eine Zeile an die Datei in
`$BUILD_WARNINGS_FILE` anhängt. Der Deploy läuft trotzdem, danach wird der Lauf
aber rot – damit GitHub eine Fehler-Mail schickt. Die Meldung sagt dann
ausdrücklich, dass die Seite live ist.

## Eine Website anschließen

1. **FTP-Zusatzkonto anlegen** (KAS → FTP → „Neues FTP-Konto“), eingeschränkt
   auf das Verzeichnis der Domain. Dann ist `./` das richtige Ziel, und selbst
   ein Fehler in der Konfiguration kann keine andere Domain treffen.
2. **Secrets setzen:**
   ```bash
   ./set-secrets.sh MitoMonkey/JustYogaRetreat
   ```
   - Server: `w0xxxxxx.kasserver.com` (nur dafür ist das Zertifikat gültig).
   - Server dir: bei einem auf die Domain beschränkten Konto einfach Enter
     (`./`), denn der Login landet bereits im Domain-Ordner.
   - Alternativ im Browser: Repo → Settings → Secrets and variables → Actions,
     `FTP_SERVER`, `FTP_USERNAME`, `FTP_PASSWORD`, `FTP_SERVER_DIR` (alle Pflicht).
3. **Aufrufer** `.github/workflows/deploy.yml` ins Website-Repo legen (siehe
   eines der bestehenden Repos).
4. **Erster Lauf mit leerem Server:** GitHub → Actions → Deploy → „Run
   workflow“ → Haken bei *clean-slate*. Das löscht alles, was bisher im
   Zielverzeichnis lag, und lädt den Repo-Stand frisch hoch. Danach reichen
   normale Pushes.

> **clean-slate löscht ALLES im Zielverzeichnis**, auch ausgeschlossene
> Dateien. Der Workflow verweigert es deshalb mit dem all-inkl-Hauptkonto
> (Benutzername `w0…`), das alle Domains sieht.

## Sichtbarkeit

Dieses Repo ist öffentlich, damit auch öffentliche Website-Repos den Workflow
aufrufen dürfen. Es enthält keine Zugangsdaten: die liegen ausschließlich als
Secrets in den Website-Repos, und der Workflow läuft im Kontext des
aufrufenden Repos.

## Aufrufer-Parameter

| Input | Default | Zweck |
|---|---|---|
| `build-command` | leer | Build-Befehl; leer = kein Build, kein Node-Setup |
| `node-version` | `24` | Node für den Build |
| `publish-dir` | `./` | hochzuladender Ordner, mit `/` am Ende |
| `exclude` | leer | zusätzliche Glob-Muster, eines pro Zeile |
| `clean-slate` | `false` | Server-Verzeichnis vorher leeren |

## Fehlersuche

- **„Missing repository secrets“** / **„must end with /“**: Schritt 2.
- **„No .ftp-deploy-sync-state.json on the server“**: erster Deploy noch nicht
  gemacht (Schritt 4), oder die Datei wurde auf dem Server gelöscht → Lauf mit
  clean-slate.
- **„Could not list the server dir“**: Server, Zugangsdaten oder Verzeichnis
  falsch.
- **TLS-/Zertifikatsfehler**: `FTP_SERVER` muss `w0xxxxxx.kasserver.com` sein,
  nicht die eigene Domain.
- **Nichts hochgeladen, obwohl geändert**: die Action vergleicht Hashes mit der
  State-Datei. Wurde auf dem Server von Hand etwas geändert, weiß sie davon
  nichts → Lauf mit clean-slate.
