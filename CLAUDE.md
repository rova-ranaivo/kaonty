# CLAUDE.md — Flux · Gestion Personnelle

## Architecture

**Single-file app** : tout est dans `index.html` (~1623 lignes) — HTML + CSS + JS sans build system, sans framework, sans npm.

- **Backend** : Supabase (PostgreSQL) via `@supabase/supabase-js@2` (CDN)
- **Charts** : Chart.js v4.4.1 (CDN)
- **Fonts** : DM Serif Display / DM Mono / DM Sans (Google Fonts)
- **Langue** : Français
- **Devise** : `Rs` (roupie mauricienne), montant par défaut 60 000 Rs/mois

---

## Supabase

- **URL** : `https://pumbzygkxtiembyuxscu.supabase.co`
- **Anon key** : dans `index.html:1009` et `sql.sql:286`
- **Pas d'authentification utilisateur** : clé anon directe, RLS actif mais sans session (pas de `auth.uid()` réel en prod)

### Tables

| Table | Description |
|---|---|
| `profiles` | Profil utilisateur (lié à `auth.users`) |
| `settings` | Budget mensuel + devise (1 ligne par user) |
| `categories` | Catégories globales (`user_id IS NULL`) + custom |
| `transactions` | Toutes les transactions |

### Vues SQL utiles
- `v_monthly_summary` — résumé mensuel par user
- `v_current_month_by_cat` — dépenses du mois par catégorie

### Convention montant
- **Négatif = dépense**, **Positif = revenu**
- `important = true` = dépense évitable/futile (flag surveillance)

---

## Store API (index.html ~ligne 1012)

```js
Store.loadData()               // charge toutes les transactions
Store.insertTransaction(tx)    // insert + retourne la ligne sauvée
Store.updateTransaction(tx)    // update par tx.id
Store.deleteTransaction(id)    // supprime par id
Store.bulkInsert(rows)         // import CSV
Store.deleteAll()              // supprime tout
Store.loadSettings()           // charge budget (maybeSingle)
Store.saveSettings(s)          // upsert budget (⚠ voir bug ci-dessous)
```

**Bug connu** : `saveSettings` fait un `upsert` avec `onConflict: 'slot'` mais la table `settings` a une contrainte `unique(user_id)` — le settings ne persist pas correctement.

---

## Données en mémoire

- `data[]` : array de toutes les transactions, chargé au démarrage
- `settings` : `{ budget: 60000 }`
- `activePeriod` : `null` (tout) ou `'YYYY-MM'`
- Pas de realtime Supabase — refresh manuel après chaque write

---

## Constantes (index.html ~ligne 1059)

```js
CATEGORIES = ['Utils','Loisirs / Evenement','Courses (Alimentation)',
              'Eating out','Logement','Abonnement','Autres']

MODES = ['Carte','Especes','Juice','Virement','Mobile','Cheque','Nata']

PAGE_SIZE = 25  // transactions par page
```

---

## Pages & Navigation

| Page ID | Nom | Rendu au navigate |
|---|---|---|
| `dashboard` | Tableau de bord | `renderDashboard()` |
| `transactions` | Transactions | `renderTable()` |
| `periodes` | Periodes | `renderPeriodes()` |
| `import` | Importer CSV | (setup only) |
| `parametres` | Parametres | `renderSettings()` |

Navigation : `navigate(pageId)` — active la page + nav-btn correspondants.

---

## Authentification (Supabase Auth)

- Login par **email + mot de passe** via `supabase.auth.signInWithPassword()`
- Client Supabase `_SB` instancié au niveau global (partagé Auth + App) — `index.html:~810`
- IIFE Auth (login screen) : `index.html:~815-862`
- Session persistée automatiquement par Supabase dans localStorage
- Au chargement : `_SB.auth.getSession()` → si session valide, `_startApp()` directement
- Déconnexion : bouton "Déconnexion" sidebar → `sb.auth.signOut()` + `location.reload()`
- `_startApp()` est maintenant une fonction globale (plus dans une IIFE)

---

## Design System CSS (`:root`)

```
--mint: #00897B   (vert menthe, couleur principale)
--mint-dim: #00695C
--mint-light: #E0F2F0
--red: #C62828    (depenses)
--gold: #8D6E00   (important/warning)
--blue: #1565C0   (utils)
--bg: #F0EEE9     (fond general)
--surface: #FFFFFF
--serif: 'DM Serif Display'
--mono: 'DM Mono'
--sans: 'DM Sans'
--sidebar-w: 220px
--topbar-h: 52px
--r: 10px, --r-sm: 6px, --r-xs: 4px
```

### Responsive
- `< 900px` : sidebar masquee (hamburger), topbar mobile visible
- `< 560px` : 1 colonne, padding reduit

### Classes utiles
- `.btn-primary` / `.btn-ghost` / `.btn-danger` / `.btn-sm` / `.icon-btn`
- `.stat-card`, `.card`, `.table-wrap`, `.modal-overlay.open`
- `.cat-pill` + `.cat-utils/.cat-loisirs/.cat-alim/.cat-eating/.cat-logement/.cat-abonnement/.cat-default`
- `.alert-info/.alert-success/.alert-danger`
- `.montant-neg` (rouge) / `.montant-pos` (vert)
- `.spinner-overlay.on` pour afficher le spinner

---

## Fonctions utilitaires

```js
fmtAbs(n)           // formatage montant absolu avec Intl → "1 234 Rs"
fmtSign(n)          // avec signe → "− 1 234 Rs" ou "+ 500 Rs"
fmtDate(s)          // date ISO → "12 janv. 2025"
currentYearMonth()  // → "YYYY-MM"
monthLabel(ym)      // → "janvier 2025"
catClass(c)         // nom categorie → classe CSS cat-*
escHtml(str)        // echappe HTML
showSpinner(label)  // affiche overlay spinner
hideSpinner()
setSyncStatus('ok'|'err'|'sync', msg)  // indicateur sidebar
```

---

## Import CSV

Format attendu : `Date;Categorie;Montant;Mode;Description;Important`
- Separateur `;` ou `,` (auto-detect)
- Date acceptee : ISO `YYYY-MM-DD` ou `DD/MM/YYYY`
- Important : `Oui` / `Non`
- Montant : negatif = depense (force negatif a l'import)

---

## Git

- Branch principale : `master`
- Branch dev : `dev` (branche courante)
- Commits recents : Nata payment mode, responsive, refonte design, code PIN, categories date
- Fichiers : `index.html` (app complete), `sql.sql` (schema + cle Supabase)

---

## Regles de modification

1. Toujours editer `index.html` — c'est le seul fichier applicatif
2. Le CSS est en `<style>` dans le `<head>` (~15-557)
3. Le HTML est entre `<body>` et `<script>` (~559-848)
4. Le JS est dans le `<script>` final (~849-1621)
5. Tout le JS applicatif est dans la closure `_startApp()` (ligne ~1007-1589)
6. Le systeme PIN est dans la closure IIFE externe (ligne ~853-1002)
7. Ne pas extraire en fichiers separes — l'app est un fichier unique intentionnellement (PWA/iOS)
