# CLAUDE.md — Flux · Gestion Personnelle

PWA mono-fichier : **tout est dans `index.html`** (~2700 lignes, HTML + CSS + JS, sans build ni npm). Ne pas extraire en fichiers séparés (PWA/iOS). Autres fichiers : `sql.sql` (schéma), `sw.js` (network-first), `manifest.json`.
Supabase (`@supabase/supabase-js@2`, CDN) · Chart.js 4.4.1 (CDN) · Français · devise `Rs`, budget par défaut 60 000 Rs/mois.

## Lire le code sans gaspiller (IMPORTANT)

- **Ne jamais lire `index.html` en entier.** Grep le repère `§` ou le nom de fonction, puis `Read` avec `offset`/`limit` (~80-150 lignes).
- Repères (un commentaire unique par section, ex. `/* §JS-STORE — … */`) :

| Zone | Repères |
|---|---|
| CSS | `§CSS-LEGACY` (ancien, ne pas modifier) · `§CSS-LEGACY-DARK` · `§CSS-APPLE` (couche finale) · `§CSS-FONT` · `§CSS-TOKENS-DARK` · `§CSS-BASE` · `§CSS-CHARTS` · `§CSS-TABBAR` · `§CSS-MOBILE` |
| HTML | `§HTML-LOGIN` · `§HTML-SIDEBAR` · `§PAGE-DASHBOARD` · `§PAGE-TRANSACTIONS` · `§PAGE-ANOMALIES` · `§PAGE-IMPORT` · `§PAGE-PARAMETRES` · `§PAGE-PERIODES` · `§HTML-TABBAR` · `§HTML-MODAL` |
| JS | `§JS-SUPABASE` · `§JS-AUTH` · `§JS-APP` (début de `_startApp()`) · `§JS-ICONS` · `§JS-CHART-THEME` · `§JS-STORE` · `§JS-STATE` · `§JS-UTILS` · `§JS-NAV` · `§JS-DASHBOARD` · `§JS-CHARTS` · `§JS-BUDGET-TABLE` · `§JS-TRANSACTIONS` · `§JS-MODAL` · `§JS-IMPORT` · `§JS-SETTINGS` · `§JS-ANOMALIES` · `§JS-PERIODES` · `§JS-IOS` |

- Nouvelle section ? Ajouter un repère `§` et la ligne correspondante ici. Pas de numéros de ligne dans ce fichier.
- Après une modif JS, vérifier la syntaxe en extrayant les blocs `<script>` et en lançant `node --check`.

## Structure

- `_SB` (client Supabase global) → IIFE Auth (email + mot de passe, `signInWithPassword`, session en localStorage) → `_startApp()` contient **tout** le JS applicatif.
- Déconnexion : `#btn-logout` → `signOut()` + `location.reload()`.
- `Store` : `loadData`, `insertTransaction`, `updateTransaction`, `deleteTransaction`, `bulkInsert`, `deleteAll`, `loadSettings`, `saveSettings` (upsert `onConflict: 'user_id'`).
- État : `data[]` (toutes les transactions), `settings {budget}`, `activePeriod` (`null` | `'YYYY-MM'`), `catLinesUnit`, filtres, `PAGE_SIZE = 25`. Pas de realtime : on rafraîchit après chaque écriture.
- Pages : `navigate(id)` → `dashboard` / `transactions` / `periodes` / `anomalies` (doublons) / `import` / `parametres`.
- Tables : `profiles`, `settings` (unique `user_id`), `categories`, `transactions` ; vues `v_monthly_summary`, `v_current_month_by_cat`.
- **Montant négatif = dépense, positif = revenu.** `important = true` = dépense évitable (surveillée).
- Import CSV : `Date;Categorie;Montant;Mode;Description;Important` (`;` ou `,`, date ISO ou `DD/MM/YYYY`, `Oui`/`Non`, montant forcé négatif).
- Utils : `el`, `fmtAbs`, `fmtSign`, `fmtK`, `fmtDate`, `monthLabel`, `currentYearMonth`, `catClass`, `catColor`, `cssVar`, `hexA`, `escHtml`, `showSpinner`/`hideSpinner`, `setSyncStatus`.

## Design system (couche `§CSS-APPLE`)

Toute modif visuelle se fait dans `§CSS-APPLE` (elle gagne la cascade). Ne pas toucher `§CSS-LEGACY`.

**Tokens** (sur `body`, pas `:root`) : clair sur `body` ; sombre sur `body[data-theme="dark"]` **et** `@media (prefers-color-scheme:dark) body:not([data-theme="light"])`. Ces deux blocs doivent rester identiques.
- Thème : Paramètres > Apparence (`#theme-seg`) → `localStorage['flux-theme']` = `light` (défaut) | `dark` | `auto`. Il est appliqué par le script en tête de `<body>`.
- « Menthe Flux » : `--bg` `--surface` `--fill`/`--fill2` `--sb-*` ; texte `--text` `--text2` `--text3` (labels) `--text4` ; `--accent #087F77` = **seule couleur d'action** (texte blanc dessus).
- `--green` / `--red` / `--amber` (+ `-bg`, `-bd`) = sémantique uniquement (revenu / dépense / alerte).
- Catégories `--c-utils … --c-autres` via `catColor(cat)`, partagées par les pastilles et les graphiques.
- Rayons `--r 10` `--rl 14` `--rxl 18` ; ombres `--sh` / `--shl` ; focus `--shfocus`.
- Police : `--sans` = **Manrope** partout (`@font-face` Fontsource 400–700 dans `§CSS-FONT`, `local()` d'abord), repli `-apple-system` / Segoe UI / Roboto ; `--display = var(--sans)`. Gros montants (`.stat-val`, `.budget-amounts strong`) en `ui-rounded` (SF Pro Rounded sur Apple, Manrope ailleurs). Jamais de `font-family` en dur. Les graphiques se redessinent sur `document.fonts` `loadingdone`.
- Alias legacy (`--mint`, `--gold`, `--blue`, `--mono`, `--serif`, `--shadow`…) → nouveaux tokens. Ils neutralisent les `style=""` du JS. Jamais de couleur codée en dur.

**Règles UI**
- Libellés en casse normale (12px / 500 / `--text3`), jamais d'uppercase. Titre de page : 26px (28px mobile) / 700. Titre de carte : 16px / 600.
- Cartes sans bordure, rayon 18, ombre `--sh`. Boutons capsules : `.btn-primary` (accent), `.btn-ghost` (`--fill`), `.btn-danger`, `.btn-sm`, `.icon-btn`.
- Choix exclusif → `.seg` > `.seg-btn.active`. `.cat-pill` sans bordure, teintée par `color-mix`.
- Icônes : uniquement en SVG inline `<svg class="ico" viewBox="0 0 24 24">` (trait 1.8, `currentColor`), jamais d'emoji. Constantes `ICON_EDIT/DUP/DEL/STAR/GRID`.
- Actions sur une transaction : `openEdit`, `duplicateTx` (formulaire pré-rempli sans id, daté d'aujourd'hui), `deleteTx`. Visibles au survol, toujours visibles au tactile.
- Montants : toujours via `fmtAbs` / `fmtSign`. Gros chiffres via `clamp()` + `cqi` (`.stat-card` = container).
- FAB : seulement sur le tableau de bord desktop, masqué quand une modale est ouverte.

**Graphiques** (`§JS-CHART-THEME`, `§JS-CHARTS`)
- Palette `--ch-pos/neg/neu/alpha/grid/zero`, lue dans `CH` par `applyChartTheme()` (seul endroit à modifier) ; `Chart.defaults` : police `--sans` 11px, pas de légende, grille horizontale, ≤ 5 graduations `fmtK`, tooltip sombre.
- Par catégorie : couleur `catColor`, série la plus lourde mise en avant. Sans catégorie : 1er élément `--ch-neg`, le reste `--ch-neu`.
- Plugin `editorial` : trait au bout des barres / lollipop, `endLabels` (clic = masquer la série, remplace la légende), `refLines`.
- `lollipopRows(entries, labelFn, colorFn?)` pour les barres HTML (`.lolli*`, `--p`).
- `#cat-lines-unit` : Semaine (16 semaines lun→dim, défaut) / Mois (12 mois). Courbes `monotone` ; dégradé (alpha ≤ .16) sur la série clé seulement. Redessin quand le thème change.

**Responsive / iOS** (`§CSS-MOBILE`)
- `≤ 900px` : sidebar masquée, header translucide + tab bar iOS, `#btn-add` masqué. `≤ 600px` : transactions en cartes (grid sur `#tx-tbody tr`).
- `.main` est le seul conteneur qui défile : tout effet de scroll s'accroche à `.main` (`body.is-scrolled` → titre compact).
- Inputs ≥ 16px sur mobile ; safe areas `env(safe-area-inset-*)` ; `prefers-reduced-motion` respecté.

## Git
`master` (principale) · `dev` (travail).
