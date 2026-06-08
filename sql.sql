-- ═══════════════════════════════════════════════════════════════════
-- GESTION DE COMPTE — Script SQL Supabase
-- ═══════════════════════════════════════════════════════════════════
-- Exécuter dans : Supabase Dashboard > SQL Editor > New Query
-- Ordre d'exécution : ce fichier entier d'un coup
-- ═══════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────
-- 0. EXTENSIONS
-- ───────────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";


-- ───────────────────────────────────────────────────────────────────
-- 1. TABLE : profiles
--    Une ligne par utilisateur (liée à auth.users de Supabase)
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.profiles is
  'Profil utilisateur, lié à auth.users. Créé automatiquement à l''inscription.';


-- ───────────────────────────────────────────────────────────────────
-- 2. TABLE : settings
--    Paramètres par utilisateur (budget mensuel, préférences)
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.settings (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  budget_mensuel  numeric(15,2) not null default 60000,
  devise          text not null default 'Rs',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint settings_user_unique unique (user_id)
);

comment on table public.settings is
  'Un seul enregistrement par utilisateur. Budget mensuel et préférences.';


-- ───────────────────────────────────────────────────────────────────
-- 3. TABLE : categories
--    Liste des catégories (partagées globalement + custom par user)
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.categories (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid references public.profiles(id) on delete cascade,
  -- user_id NULL = catégorie globale (visible par tous, non modifiable)
  -- user_id SET  = catégorie custom de l'utilisateur
  nom         text not null,
  couleur_bg  text not null default '#f5f5f5',
  couleur_fg  text not null default '#333333',
  ordre       integer not null default 99,
  created_at  timestamptz not null default now(),

  constraint categories_nom_user_unique unique (user_id, nom)
);

comment on table public.categories is
  'Catégories globales (user_id IS NULL) et catégories custom par user.';

-- Catégories globales par défaut
insert into public.categories (user_id, nom, couleur_bg, couleur_fg, ordre) values
  (null, 'Utils',                '#e4edf8', '#2a559a', 1),
  (null, 'Loisirs / Evenement',  '#ece4f5', '#7030a0', 2),
  (null, 'Courses (Alimentation)','#e3f0e9','#2d7a50', 3),
  (null, 'Eating out',           '#fef3e2', '#c07000', 4),
  (null, 'Logement',             '#e4f0f8', '#1a6090', 5),
  (null, 'Abonnement',           '#f0e4f8', '#6a20a0', 6),
  (null, 'Autres',               '#f5f5f5', '#555555', 7)
on conflict do nothing;


-- ───────────────────────────────────────────────────────────────────
-- 4. TABLE : transactions
--    Table principale — chaque dépense / revenu
-- ───────────────────────────────────────────────────────────────────
create table if not exists public.transactions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  date         date not null,
  categorie    text not null,
  montant      numeric(15,2) not null,
  -- Négatif = dépense, Positif = revenu (convention app)
  mode         text not null default 'Carte',
  description  text not null default '',
  important    boolean not null default false,
  -- important = TRUE  → dépense évitable / à surveiller
  -- important = FALSE → dépense nécessaire
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Index pour les requêtes fréquentes
create index if not exists idx_transactions_user_id   on public.transactions(user_id);
create index if not exists idx_transactions_date       on public.transactions(date desc);
create index if not exists idx_transactions_user_date  on public.transactions(user_id, date desc);
create index if not exists idx_transactions_categorie  on public.transactions(user_id, categorie);
create index if not exists idx_transactions_important  on public.transactions(user_id, important);

comment on table public.transactions is
  'Toutes les transactions (dépenses et revenus) par utilisateur.';
comment on column public.transactions.montant is
  'Négatif = dépense, Positif = revenu.';
comment on column public.transactions.important is
  'TRUE = dépense évitable/futile. FALSE = dépense nécessaire.';


-- ───────────────────────────────────────────────────────────────────
-- 5. TRIGGERS : updated_at automatique
-- ───────────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create or replace trigger trg_settings_updated_at
  before update on public.settings
  for each row execute function public.set_updated_at();

create or replace trigger trg_transactions_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();


-- ───────────────────────────────────────────────────────────────────
-- 6. TRIGGER : création automatique du profil + settings à l'inscription
-- ───────────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  -- Créer le profil
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;

  -- Créer les settings avec valeurs par défaut
  insert into public.settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create or replace trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ───────────────────────────────────────────────────────────────────
-- 7. ROW LEVEL SECURITY (RLS)
--    Chaque user ne voit et ne modifie QUE ses propres données
-- ───────────────────────────────────────────────────────────────────

-- Activer RLS sur toutes les tables
alter table public.profiles     enable row level security;
alter table public.settings     enable row level security;
alter table public.categories   enable row level security;
alter table public.transactions enable row level security;

-- ── profiles ──
create policy "profiles: select own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles: update own"
  on public.profiles for update
  using (auth.uid() = id);

-- ── settings ──
create policy "settings: select own"
  on public.settings for select
  using (auth.uid() = user_id);

create policy "settings: insert own"
  on public.settings for insert
  with check (auth.uid() = user_id);

create policy "settings: update own"
  on public.settings for update
  using (auth.uid() = user_id);

-- ── categories ──
-- L'user voit les catégories globales (user_id IS NULL) + les siennes
create policy "categories: select"
  on public.categories for select
  using (user_id is null or auth.uid() = user_id);

create policy "categories: insert own"
  on public.categories for insert
  with check (auth.uid() = user_id);

create policy "categories: update own"
  on public.categories for update
  using (auth.uid() = user_id);

create policy "categories: delete own"
  on public.categories for delete
  using (auth.uid() = user_id);

-- ── transactions ──
create policy "transactions: select own"
  on public.transactions for select
  using (auth.uid() = user_id);

create policy "transactions: insert own"
  on public.transactions for insert
  with check (auth.uid() = user_id);

create policy "transactions: update own"
  on public.transactions for update
  using (auth.uid() = user_id);

create policy "transactions: delete own"
  on public.transactions for delete
  using (auth.uid() = user_id);


-- ───────────────────────────────────────────────────────────────────
-- 8. VUES UTILES (optionnelles, pour requêtes dashboard)
-- ───────────────────────────────────────────────────────────────────

-- Vue : résumé mensuel par user
create or replace view public.v_monthly_summary as
select
  user_id,
  to_char(date, 'YYYY-MM')                         as mois,
  sum(case when montant < 0 then abs(montant) else 0 end) as total_depenses,
  sum(case when montant > 0 then montant       else 0 end) as total_revenus,
  sum(montant)                                     as solde_net,
  count(*)                                         as nb_transactions,
  count(*) filter (where important = true)         as nb_importantes
from public.transactions
group by user_id, to_char(date, 'YYYY-MM');

-- Vue : résumé par catégorie pour le mois en cours
create or replace view public.v_current_month_by_cat as
select
  user_id,
  categorie,
  sum(abs(montant))   as total,
  count(*)            as nb,
  bool_or(important)  as contient_importante
from public.transactions
where
  montant < 0
  and to_char(date, 'YYYY-MM') = to_char(now(), 'YYYY-MM')
group by user_id, categorie;

comment on view public.v_monthly_summary      is 'Résumé mensuel agrégé par utilisateur.';
comment on view public.v_current_month_by_cat is 'Dépenses du mois en cours groupées par catégorie.';


-- ───────────────────────────────────────────────────────────────────
-- FIN DU SCRIPT
-- ───────────────────────────────────────────────────────────────────
-- Tables créées :
--   public.profiles      → profil utilisateur
--   public.settings      → paramètres (budget, devise)
--   public.categories    → catégories globales + custom
--   public.transactions  → toutes les transactions
-- Vues créées :
--   public.v_monthly_summary
--   public.v_current_month_by_cat
-- ═══════════════════════════════════════════════════════════════════

public key : eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1bWJ6eWdreHRpZW1ieXV4c2N1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1OTIyNjYsImV4cCI6MjA4OTE2ODI2Nn0.eve4s3TH-s7tPKBqkjZdsbMrSsbEEIiMYsZO_TMhLi0
project url : https://pumbzygkxtiembyuxscu.supabase.co