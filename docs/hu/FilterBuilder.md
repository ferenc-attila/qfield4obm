# Szűrőkészítő — Felhasználói útmutató

A Szűrőkészítő segítségével meghatározhatod, hogy mely rekordokat töltse le a plugin az OpenBioMaps szerverről, mielőtt szinkronizálja a réteget az eszközödre. Ahelyett, hogy egy tábla összes rekordját letöltenéd, feltételek és logikai csoportok segítségével leírod, milyen adatokra van szükséged — és csak az egyező rekordok kerülnek átvitelre.

---

## A Szűrőkészítő elérése

A Szűrőkészítő a **rétegletöltési párbeszédablak** részeként jelenik meg. Miután kiválasztottál egy OBM projektet és megnyomtad a „Réteg letöltése" gombot, a párbeszédablak megnyílik, és a szűrőpanel a tábla- és rétegválasztók alatt látható.

---

## 1. lépés — Adattábla kiválasztása

A **Adattábla kiválasztása** legördülő lista az aktuális projekthez tartozó összes elérhető adattáblát felsorolja az OBM szerveren. Amikor kiválasztasz egy táblát, a plugin automatikusan lekéri az oszlopok definícióit a szerverről. Az oszlopok betöltése után:

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
| not equals | Pontos nem-egyezés |
| equals (ignore case) | Pontos egyezés, kis-/nagybetű figyelmen kívül hagyásával |
| contains | Az oszlop értéke tartalmazza a szöveget (kis-/nagybetű érzéketlen) |
| not contains | Az oszlop értéke nem tartalmazza a szöveget |
| starts with | Az oszlop értéke a szöveggel kezdődik (kis-/nagybetű érzéketlen) |
| ends with | Az oszlop értéke a szöveggel végződik (kis-/nagybetű érzéketlen) |
| in list | Az oszlop értéke szerepel egy vesszővel elválasztott listában |
| not in list | Az oszlop értéke nem szerepel a vesszővel elválasztott listában |
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

---

**Érték** — a beviteli mező a kiválasztott operátortól függően változik:

- **Szöveg / szám / dátum** — szabad szöveges mező jelenik meg. Dátumok esetén a formátum `ÉÉÉÉ-HH-NN`. Listák esetén (`in list`, `not in list`) vesszővel elválasztva add meg az értékeket, pl. `veréb, pinty, cinege`.
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

### Két megfigyelő bármelyike, de csak ha a faj nem hiányzik

- Gyökérlogika: `AND`
- Csoport (OR logika):
  - A feltétel: `observer` → `equals` → `Kovács János`
  - B feltétel: `observer` → `equals` → `Nagy Mária`
- Feltétel: `species` → `is not null`

---

## Tippek

- Ha nincs megadva feltétel, a tábla összes rekordja letöltésre kerül (nincs szűrés).
- Az üres értékmezővel rendelkező feltételek csendesen ki vannak hagyva — nem korlátozzák a letöltést.
- A szűrő szerveroldali érvényesítéssel működik az átvitel előtt, tehát csak az egyező rekordok kerülnek az eszközre.
- Az adattábla megváltoztatása automatikusan törli az összes feltételt és csoportot.