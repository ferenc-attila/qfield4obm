# Szűrések — Felhasználói útmutató

A szűrések segítségével meghatározhatod, hogy mely rekordokat töltse le a plugin az OpenBioMaps szerverről, mielőtt szinkronizálja a réteget az eszközödre. Ahelyett, hogy egy tábla összes rekordját letöltenéd, feltételek és logikai csoportok segítségével leírod, milyen adatokra van szükséged — és csak az egyező rekordok kerülnek átvitelre. Ez csökenti a hálózati forgalmat, a mobil eszköz akkumlátoridejét pedig növeli.

---

## A szűrők elérése

A Szűrők a **rétegletöltési párbeszédablak** részeként jelennek meg. Miután kiválasztottál egy OBM projektet és megnyomtad a „Réteg letöltése" gombot, a párbeszédablak megnyílik, és a szűrőpanel a tábla- és rétegválasztók alatt látható.

---

## 1. lépés — Adattábla kiválasztása

A **Adattábla kiválasztása** legördülő lista az aktuális projekthez tartozó összes elérhető adattáblát felsorolja az OBM szerveren, amelyet a bennük lévő geometriatípus alapján tovább bont. Amikor kiválasztasz egy táblát, a plugin automatikusan lekéri az oszlopok definícióit a szerverről. Az oszlopok betöltése után:

- Megjelenik a **Virtuális réteg kiválasztása** legördülő lista, ahol kiválaszthatod a geometriatípust (Pontok, Vonalak, Poligonok) vagy az attribútum-only nézetet.
- A szűrőpanel aktívvá válik, és egy üres feltételsor jelenik meg automatikusan.

Ha a táblát nem sikerül betölteni (hálózati hiba, jogosultsági probléma), piros hibaüzenet jelenik meg a választó alatt.

---

## 2. lépés — Szűrő összeállítása

### Az eszköztár

A szűrőszekció tetején három vezérlőelemet találsz:

| Vezérlőelem | Funkció |
|---|---|
| **AND / OR** legördülő | Beállítja a **gyökérlogikát** — azt, hogy a legfelső szintű feltételek és csoportok hogyan kapcsolódnak egymáshoz. Az `AND` azt jelenti, hogy minden feltételnek teljesülnie kell. Az `OR` azt jelenti, hogy legalább egynek teljesülnie kell. |
| **+ Feltétel** gomb | Új egymezős feltételt ad hozzá a gyökérszinten. |
| **+ Csoport** gomb | Logikai csoportot ad hozzá, amely saját feltételeket tartalmazhat független AND/OR logikával. |

---

### Feltételsorok

Minden feltételsor három részből áll:

```
[ Mező ▼ ]  [ Operátor ▼ ]  [ Érték ]
[ NEM □ ]   [ Eltávolítás ]
```

**Mező** — kiválasztja, melyik oszlopra vonatkozzon a szűrő. A lista a tábla oszlopaiból töltődik be. A geometriaoszlopok ki vannak zárva (a térbeli szűrők a rétegkiválasztás során külön kezelhetők).

**Operátor** — az alkalmazandó összehasonlítás. Az elérhető operátorok az oszlop adattípusától függnek:

#### Szöveges operátorok

| Operátor | Jelentés |
|---|---|
| equals | Pontos egyezés (kis-/nagybetű érzékeny) |
| not equals | Pontos nem-egyezés (kis-/nagybetű érzékeny) |
| equals (ignore case) | Pontos egyezés, kis-/nagybetű figyelmen kívül hagyásával |
| not equals (ignore case) | Pontos nem-egyezés, kis-/nagybetű figyelmen kívül hagyásával |
| contains | Az oszlop értéke tartalmazza a szöveget (kis-/nagybetű érzéketlen) |
| not contains | Az oszlop értéke nem tartalmazza a szöveget (kis-/nagybetű érzéketlen) |
| like (pattern) | SQL LIKE mintaillesztés (kis-/nagybetű érzékeny; `%` tetszőleges karaktersorozatot, `_` egyetlen tetszőleges karaktert jelöl) |
| not like (pattern) | SQL NOT LIKE mintaillesztés (kis-/nagybetű érzékeny) |
| starts with | Az oszlop értéke a szöveggel kezdődik (kis-/nagybetű érzéketlen) |
| not starts with | Az oszlop értéke nem a szöveggel kezdődik (kis-/nagybetű érzéketlen) |
| starts with (case-sensitive) | Az oszlop értéke a szöveggel kezdődik (kis-/nagybetű érzékeny) |
| not starts with (case-sensitive) | Az oszlop értéke nem a szöveggel kezdődik (kis-/nagybetű érzékeny) |
| ends with | Az oszlop értéke a szöveggel végződik (kis-/nagybetű érzéketlen) |
| not ends with | Az oszlop értéke nem a szöveggel végződik (kis-/nagybetű érzéketlen) |
| ends with (case-sensitive) | Az oszlop értéke a szöveggel végződik (kis-/nagybetű érzékeny) |
| not ends with (case-sensitive) | Az oszlop értéke nem a szöveggel végződik (kis-/nagybetű érzékeny) |
| in list | Az oszlop értéke szerepel egy vesszővel elválasztott listában (kis-/nagybetű érzékeny) |
| not in list | Az oszlop értéke nem szerepel a vesszővel elválasztott listában (kis-/nagybetű érzékeny) |
| in list (ignore case) | Az oszlop értéke szerepel egy vesszővel elválasztott listában (kis-/nagybetű érzéketlen) |
| not in list (ignore case) | Az oszlop értéke nem szerepel a vesszővel elválasztott listában (kis-/nagybetű érzéketlen) |
| is null | Nincs tárolt érték |
| is not null | Van tárolt érték |
| is empty | Üres szöveg van tárolva |
| is not empty | Nem üres szöveg van tárolva |

#### Numerikus operátorok

| Operátor | Jelentés |
|---|---|
| = equals | Pontos numerikus egyezés |
| ≠ not equals | Pontos numerikus nem-egyezés |
| > greater than | Szigorúan nagyobb |
| < less than | Szigorúan kisebb |
| ≥ at least | Nagyobb vagy egyenlő |
| ≤ at most | Kisebb vagy egyenlő |
| in list | Az érték szerepel egy vesszővel elválasztott számlistában |
| not in list | Az érték nem szerepel a vesszővel elválasztott számlistában |
| is null | Nincs tárolt érték |
| is not null | Van tárolt érték |

#### Dátum / idő operátorok

| Operátor | Jelentés |
|---|---|
| equals | Pontos dátumegyezés (`ÉÉÉÉ-HH-NN`) |
| not equals | Bármely dátum, kivéve ezt |
| after | Szigorúan ezen dátum után |
| before | Szigorúan ezen dátum előtt |
| on or after | Ugyanezen a napon vagy később |
| on or before | Ugyanezen a napon vagy korábban |
| year equals | A dátum évrésze egyezik a megadott négy jegyű évvel |
| between | A dátum egy tartományon belül esik (határokat is beleértve) — add meg a kezdő és záró dátumot `ÉÉÉÉ-HH-NN` formátumban |
| not between | A dátum egy tartományon kívül esik — add meg a kezdő és záró dátumot `ÉÉÉÉ-HH-NN` formátumban |
| between days (MM-DD) | Az éven belüli nap visszatérő időszakra esik, az évet figyelmen kívül hagyva — add meg a kezdő és záró dátumot `HH-NN` formátumban (pl. `04-15`-től `08-10`-ig). Támogatja az éven átnyúló tartományokat is (pl. `12-01`-től `02-28`-ig). |
| not between days (MM-DD) | Az éven belüli nap visszatérő időszakon kívül esik — add meg a kezdő és záró dátumot `HH-NN` formátumban |
| year in list | Az év rész egyezik valamelyik vesszővel elválasztott évvel (pl. `2022, 2023, 2024`) |
| month equals (1-12) | A hónap száma egyezik (1 = január … 12 = december) |
| month in list | A hónap száma egyezik valamelyik vesszővel elválasztott értékkel (pl. `3, 6, 9, 12`) |
| day of month (1-31) | A hónap napjának száma egyezik |
| day of week (0-6) | A hét napjának száma egyezik (0 = vasárnap, 6 = szombat) |
| day of year (1-366) | Az év napjának száma egyezik |
| is in past | A dátum a mai nap előtt van |
| is in future | A dátum a mai nap után van |
| is today | A dátum a mai nap |
| is null | Nincs tárolt dátum |
| is not null | Van tárolt dátum |

#### Logikai (boolean) operátorok

| Operátor | Jelentés |
|---|---|
| equals | Egyezik `true` vagy `false` értékkel |
| not equals | Az ellentétes érték |
| is null | Nincs tárolt érték |
| is not null | Van tárolt érték |

#### Tömb (array) operátorok

A tömboszlopok egyetlen mezőben több értéket tárolnak (pl. megjegyzéscímkék listája). Ezek az operátorok akkor érhetők el, ha egy oszlop tömb típusú (az adatbázissémában `text[]` vagy hasonló jelöléssel jelenik meg).

| Operátor | Jelentés |
|---|---|
| contains (case-sensitive) | A tömb tartalmazza a megadott értéket (kis-/nagybetű érzékeny) |
| not contains (case-sensitive) | A tömb nem tartalmazza a megadott értéket (kis-/nagybetű érzékeny) |
| contains all (case-sensitive) | A tömb tartalmazza a lista összes értékét (kis-/nagybetű érzékeny) |
| contains any (case-sensitive) | A tömb tartalmazza a lista legalább egy értékét (kis-/nagybetű érzékeny) |
| contains none (case-sensitive) | A tömb a lista egyik értékét sem tartalmazza (kis-/nagybetű érzékeny) |
| contains (ignore case) | A tömb tartalmazza a megadott értéket (kis-/nagybetű érzéketlen) |
| not contains (ignore case) | A tömb nem tartalmazza a megadott értéket (kis-/nagybetű érzéketlen) |
| contains all (ignore case) | A tömb tartalmazza a lista összes értékét (kis-/nagybetű érzéketlen) |
| contains any (ignore case) | A tömb tartalmazza a lista legalább egy értékét (kis-/nagybetű érzéketlen) |
| contains none (ignore case) | A tömb a lista egyik értékét sem tartalmazza (kis-/nagybetű érzéketlen) |
| is null | Nincs tárolt érték (maga a mező NULL) |
| is not null | Van tárolt érték |
| is empty | A tömb üres (nulla elem) |
| is not empty | A tömbben legalább egy elem van |

**Értékbevitel tömb operátoroknál:**

- **Egyértékes operátorok** (`contains`, `not contains`, `contains (ignore case)`, `not contains (ignore case)`) — adj meg egy értéket a szövegmezőben, pl. `jóváhagyott`.
- **Listás operátorok** (`contains all`, `contains any`, `contains none`, és ezek kis-/nagybetű érzéketlen változatai) — vesszővel elválasztott értékeket adj meg, pl. `felülvizsgált, végleges, jóváhagyott`.
- **Értéket nem igénylő operátorok** (`is null`, `is not null`, `is empty`, `is not empty`) — nem jelenik meg értékmező.

---

**Érték** — a beviteli mező a kiválasztott operátortól függően változik:

- **Szöveg / szám / dátum** — szabad szöveges mező jelenik meg. Dátumok esetén a formátum `ÉÉÉÉ-HH-NN`. Listák esetén (`in list`, `not in list`, `in list (ignore case)`, `not in list (ignore case)`) vesszővel elválasztva add meg az értékeket, pl. `veréb, pinty, cinege`.
- **Tartomány** (`between`, `not between`, `between days`, `not between days`) — két beviteli mező jelenik meg: **Kezdő** és **Záró**. Dátumtartomány operátoroknál `ÉÉÉÉ-HH-NN`, naptartomány operátoroknál `HH-NN` formátumban add meg az értékeket.
- **Egész szám** (`month equals`, `day of month`, `day of week`, `day of year`) — egyetlen számmező jelenik meg.
- **Egész számok listája** (`year in list`, `month in list`) — vesszővel elválasztott számokat adj meg, pl. `2022, 2023, 2024`.
- **Logikai (boolean)** — legördülő lista jelenik meg `true` és `false` opcióval.
- **Értéket nem igénylő operátorok** (`is null`, `is not null`, `is empty`, `is not empty`, `is in past`, `is in future`, `is today`) — nem jelenik meg értékmező.

**NEM jelölőnégyzet** — logikai NOT-ba csomagolja a feltételt, megfordítva az eredményt. Például a `contains "róka"` NEM bejelölve azt jelenti: „nem tartalmazza: róka".

**Eltávolítás gomb** — törli a feltételsort.

---

### Csoportok

A csoport feltételek gyűjteménye, saját belső AND/OR logikával, amely egyetlen elemként viselkedik a gyökérszinten.

```
Csoport: [ OR ▼ ]  [ NEM □ ]  [ Csoport eltávolítása ]
  ┌─────────────────────────────────────────┐
  │  [ Mező ▼ ]  [ Operátor ▼ ]  [ Érték ] │
  │  [ NEM □ ]   [ Eltávolítás ]           │
  │─────────────────────────────────────────│
  │  [ Mező ▼ ]  [ Operátor ▼ ]  [ Érték ] │
  │  [ NEM □ ]   [ Eltávolítás ]           │
  └─────────────────────────────────────────┘
  [ + Feltétel hozzáadása ]
```

- **Csoportlogika legördülő** (`AND` / `OR`) — meghatározza, hogy a csoporton belüli feltételek hogyan kapcsolódnak egymáshoz.
- **NEM jelölőnégyzet a csoporton** — megfordítja az egész csoport eredményét.
- **+ Feltétel hozzáadása** — új feltételsort ad a csoporthoz.
- **Csoport eltávolítása** — törli az egész csoportot az összes feltételével együtt.

---

## Hogyan kapcsolódnak a feltételek és csoportok

Minden gyökérszintű feltétel és csoport az eszköztárban kiválasztott **gyökérlogika** (AND/OR) alapján kapcsolódik egymáshoz.

**Példa — AND gyökér OR csoporttal:**

> *„Töltsd le azokat a rekordokat, ahol a faj tartalmazza az 'abax' szót ÉS (az élőhely 'erdő' VAGY 'gyep')"*

Konfiguráció:
- Gyökérlogika: `AND`
- 1. feltétel: `species` → `contains` → `abax`
- Csoport (OR logika):
  - A feltétel: `habitat` → `equals` → `erdő`
  - B feltétel: `habitat` → `equals` → `gyep`

Ez a következő szűrőt állítja elő:
```json
{
  "AND": [
    { "species": { "ilike": "abax" } },
    {
      "OR": [
        { "habitat": { "equals": "erdő" } },
        { "habitat": { "equals": "gyep" } }
      ]
    }
  ]
}
```

---

## Gyakorlati példák

### Csak egy adott évből származó megfigyelések letöltése

- Gyökérlogika: `AND`
- Feltétel: `date` → `year equals` → `2023`

### Hiányzó megfigyelő nélküli rekordok kizárása

- Gyökérlogika: `AND`
- Feltétel: `observer` → `is not null`

### Meghatározott fajok rövid listájának letöltése

- Gyökérlogika: `AND`
- Feltétel: `species` → `in list` → `Carabus coriaceus, Carabus granulatus, Abax parallelepipedus`

### Az aktuális szezon rekordjai (április 1. után, október előtt)

- Gyökérlogika: `AND`
- 1. feltétel: `date` → `on or after` → `2024-04-01`
- 2. feltétel: `date` → `before` → `2024-10-01`

### Több évet átfogó dátumtartomány

- Gyökérlogika: `AND`
- Feltétel: `date` → `between` → Kezdő: `2022-01-01`, Záró: `2024-12-31`

### Szezonális szűrő — tavaszi és nyári rekordok, évtől függetlenül

- Gyökérlogika: `AND`
- Feltétel: `date` → `between days (MM-DD)` → Kezdő: `04-01`, Záró: `08-31`

### Éven átnyúló téli időszak rekordjai

- Gyökérlogika: `AND`
- Feltétel: `date` → `between days (MM-DD)` → Kezdő: `11-01`, Záró: `02-28`

### Rekordok meghatározott évekből

- Gyökérlogika: `AND`
- Feltétel: `date` → `year in list` → `2021, 2022, 2023`

### Rekordok meghatározott hónapokból (pl. költési időszak)

- Gyökérlogika: `AND`
- Feltétel: `date` → `month in list` → `4, 5, 6, 7`

### Hétvégén rögzített megfigyelések

- Gyökérlogika: `OR`
- 1. feltétel: `date` → `day of week (0-6)` → `0`
- 2. feltétel: `date` → `day of week (0-6)` → `6`

### Két megfigyelő bármelyike, de csak ha a faj nem hiányzik

- Gyökérlogika: `AND`
- Csoport (OR logika):
  - A feltétel: `observer` → `equals` → `Kovács János`
  - B feltétel: `observer` → `equals` → `Nagy Mária`
- Feltétel: `species` → `is not null`

### Adott megjegyzéscímkét tartalmazó rekordok

- Gyökérlogika: `AND`
- Feltétel: `obm_comments` → `contains (case-sensitive)` → `jóváhagyott`

### Minden kötelező címkét tartalmazó rekordok

- Gyökérlogika: `AND`
- Feltétel: `obm_comments` → `contains all (case-sensitive)` → `felülvizsgált, végleges`

### Nem kívánt címkék egyikét sem tartalmazó rekordok

- Gyökérlogika: `AND`
- Feltétel: `obm_comments` → `contains none (case-sensitive)` → `piszkozat, hiányos, duplikált`

---

## Tippek

- Ha nincs megadva feltétel, a tábla összes rekordja letöltésre kerül (nincs szűrés).
- Az üres értékmezővel rendelkező feltételek csendesen ki vannak hagyva — nem korlátozzák a letöltést.
- A szűrő szerveroldali érvényesítéssel működik az átvitel előtt, tehát csak az egyező rekordok kerülnek az eszközre.
- Az adattábla megváltoztatása automatikusan törli az összes feltételt és csoportot.
