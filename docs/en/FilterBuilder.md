# Filter Builder — User Guide

The Filter Builder lets you define which records are downloaded from the OpenBioMaps server before syncing a layer to your device. Instead of pulling every record in a table, you describe the data you need using conditions and logical groups — and only the matching records are transferred. That will reduce the network traffic and the mobile device battery consumption.

---

## Accessing the Filter Builder

The Filter Builder appears as part of the **layer download dialog**. After selecting an OBM project and tapping "Download Layer", the dialog opens and the filter panel is shown below the table and layer selectors.

---

## Step 1 — Select a Data Table

The **Select Data Table** drop-down lists all available data tables, grouped by geometry type, on the OBM server for the current project. When you pick a table, the plugin automatically fetches its column definitions from the server. Once the columns are loaded:

- The **Select Virtual Layer** drop-down appears, where you choose the geometry type (Points, Lines, Polygons) or the attribute-only view.
- The filter panel becomes active with one empty condition row pre-filled.

If the table cannot be loaded (network error, permission issue), an error message appears in red beneath the selector.

---

## Step 2 — Build Your Filter

### The toolbar

At the top of the filter section you will find three controls:

| Control | Purpose |
|---|---|
| **AND / OR** combo | Sets the **root logic** — how all top-level conditions and groups are combined. `AND` means every top-level item must be satisfied. `OR` means at least one must be satisfied. |
| **+ Condition** button | Adds a new single-field condition at the root level. |
| **+ Group** button | Adds a logical group that can contain its own conditions with an independent AND/OR logic. |

---

### Condition rows

Each condition row has three parts:

```
[ Field ▼ ]  [ Operator ▼ ]  [ Value ]
[ NOT □ ]    [ Remove ]
```

**Field** — selects which column to filter on. The list is populated from the table's columns. Geometry columns are excluded (spatial filters are handled separately during layer selection).

**Operator** — the comparison to apply. The available operators depend on the column's data type:

#### String operators

| Operator | Meaning |
|---|---|
| equals | Exact match (case-sensitive) |
| not equals | Exact non-match (case-sensitive) |
| equals (ignore case) | Exact match, case-insensitive |
| not equals (ignore case) | Exact non-match, case-insensitive |
| contains | Column value contains the text (case-insensitive) |
| not contains | Column value does not contain the text (case-insensitive) |
| like (pattern) | SQL LIKE pattern match (case-sensitive; use `%` for any sequence, `_` for any single character) |
| not like (pattern) | SQL NOT LIKE pattern (case-sensitive) |
| starts with | Column value begins with the text (case-insensitive) |
| not starts with | Column value does not begin with the text (case-insensitive) |
| starts with (case-sensitive) | Column value begins with the text (case-sensitive) |
| not starts with (case-sensitive) | Column value does not begin with the text (case-sensitive) |
| ends with | Column value ends with the text (case-insensitive) |
| not ends with | Column value does not end with the text (case-insensitive) |
| ends with (case-sensitive) | Column value ends with the text (case-sensitive) |
| not ends with (case-sensitive) | Column value does not end with the text (case-sensitive) |
| in list | Column value is one of a comma-separated list (case-sensitive) |
| not in list | Column value is not any of a comma-separated list (case-sensitive) |
| in list (ignore case) | Column value is one of a comma-separated list (case-insensitive) |
| not in list (ignore case) | Column value is not any of a comma-separated list (case-insensitive) |
| is null | No value stored |
| is not null | Any value stored |
| is empty | Empty string stored |
| is not empty | Non-empty string stored |

#### Numeric operators

| Operator | Meaning |
|---|---|
| = equals | Exact numeric match |
| ≠ not equals | Exact numeric non-match |
| > greater than | Strictly larger |
| < less than | Strictly smaller |
| ≥ at least | Greater than or equal |
| ≤ at most | Less than or equal |
| in list | Value is one of a comma-separated list of numbers |
| not in list | Value is not in a comma-separated list of numbers |
| is null | No value stored |
| is not null | Any value stored |

#### Date / time operators

| Operator | Meaning |
|---|---|
| equals | Exact date match (`YYYY-MM-DD`) |
| not equals | Any date except this one |
| after | Strictly after a date |
| before | Strictly before a date |
| on or after | Same day or later |
| on or before | Same day or earlier |
| year equals | The year part of the date matches a four-digit year |
| between | Date falls within a range (inclusive) — enter start and end as `YYYY-MM-DD` |
| not between | Date falls outside a range — enter start and end as `YYYY-MM-DD` |
| between days (MM-DD) | Day-of-year falls within a recurring period, ignoring the year — enter start and end as `MM-DD` (e.g. `04-15` to `08-10`). Supports wrap-around ranges that cross the year boundary (e.g. `12-01` to `02-28`). |
| not between days (MM-DD) | Day-of-year falls outside a recurring period — enter start and end as `MM-DD` |
| year in list | Year part matches one of a comma-separated list of years (e.g. `2022, 2023, 2024`) |
| month equals (1-12) | Month number matches (1 = January … 12 = December) |
| month in list | Month number matches one of a comma-separated list (e.g. `3, 6, 9, 12`) |
| day of month (1-31) | Day-of-month number matches |
| day of week (0-6) | Day-of-week matches (0 = Sunday, 6 = Saturday) |
| day of year (1-366) | Day-of-year number matches |
| is in past | Date is before today |
| is in future | Date is after today |
| is today | Date is today |
| is null | No date stored |
| is not null | Any date stored |

#### Boolean operators

| Operator | Meaning |
|---|---|
| equals | Matches `true` or `false` |
| not equals | The opposite value |
| is null | No value stored |
| is not null | Any value stored |

#### Array operators

Array columns store multiple values in a single field (e.g. a list of comment tags). These operators are available when a column has an array type (shown as `text[]` or similar in the database schema).

| Operator | Meaning |
|---|---|
| contains (case-sensitive) | Array contains the given value (exact case match) |
| not contains (case-sensitive) | Array does not contain the given value (exact case match) |
| contains all (case-sensitive) | Array contains every value in the comma-separated list |
| contains any (case-sensitive) | Array contains at least one value from the comma-separated list |
| contains none (case-sensitive) | Array contains none of the values in the comma-separated list |
| contains (ignore case) | Array contains the given value (case-insensitive) |
| not contains (ignore case) | Array does not contain the given value (case-insensitive) |
| contains all (ignore case) | Array contains every value in the list (case-insensitive) |
| contains any (ignore case) | Array contains at least one value from the list (case-insensitive) |
| contains none (ignore case) | Array contains none of the values in the list (case-insensitive) |
| is null | No value stored (the field itself is NULL) |
| is not null | Any value stored |
| is empty | Array has no elements |
| is not empty | Array has at least one element |

**Value input for array operators:**

- **Single-value operators** (`contains`, `not contains`, `contains (ignore case)`, `not contains (ignore case)`) — enter one value in the text field, e.g. `approved`.
- **List operators** (`contains all`, `contains any`, `contains none`, and their ignore-case variants) — enter comma-separated values, e.g. `approved, reviewed, final`.
- **No-value operators** (`is null`, `is not null`, `is empty`, `is not empty`) — no value input is shown.

---

**Value** — the input field changes based on the selected operator:

- **Text / number / date** — a free-text input appears. For dates enter the value as `YYYY-MM-DD`. For lists (`in list`, `not in list`, `in list (ignore case)`, `not in list (ignore case)`) enter values separated by commas, e.g. `sparrow, finch, robin`.
- **Range** (`between`, `not between`, `between days`, `not between days`) — two inputs appear: **Start** and **End**. Use `YYYY-MM-DD` for date range operators and `MM-DD` for day-of-year range operators.
- **Integer** (`month equals`, `day of month`, `day of week`, `day of year`) — a single number input appears.
- **Integer list** (`year in list`, `month in list`) — enter numbers separated by commas, e.g. `2022, 2023, 2024`.
- **Boolean** — a drop-down shows `true` and `false`.
- **No-value operators** (`is null`, `is not null`, `is empty`, `is not empty`, `is in past`, `is in future`, `is today`) — no value input is shown.

**NOT checkbox** — wraps the condition in a logical NOT, inverting the result. For example, `contains "fox"` with NOT checked means "does not contain fox".

**Remove button** — deletes the condition row.

---

### Groups

A group is a set of conditions with its own internal AND/OR logic, treated as a single item at the root level.

```
Group: [ OR ▼ ]  [ NOT □ ]  [ Remove Group ]
  ┌─────────────────────────────────────────┐
  │  [ Field ▼ ]  [ Operator ▼ ]  [ Value ] │
  │  [ NOT □ ]    [ Remove ]                │
  │─────────────────────────────────────────│
  │  [ Field ▼ ]  [ Operator ▼ ]  [ Value ] │
  │  [ NOT □ ]    [ Remove ]                │
  └─────────────────────────────────────────┘
  [ + Add Condition ]
```

- **Group logic combo** (`AND` / `OR`) — determines how the conditions inside the group are combined.
- **NOT checkbox on the group** — inverts the entire group result.
- **+ Add Condition** — adds another condition row inside the group.
- **Remove Group** — deletes the entire group and all its conditions.

---

## How conditions and groups are combined

All top-level conditions and groups are combined using the **root logic** (AND/OR) selected in the toolbar.

**Example — AND root with an OR group:**

> *"Download records where species contains 'abax' AND (habitat is 'forest' OR habitat is 'grassland')"*

Configuration:
- Root logic: `AND`
- Condition 1: `species` → `contains` → `abax`
- Group (OR logic):
  - Condition A: `habitat` → `equals` → `forest`
  - Condition B: `habitat` → `equals` → `grassland`

This produces the filter:
```json
{
  "AND": [
    { "species": { "ilike": "abax" } },
    {
      "OR": [
        { "habitat": { "equals": "forest" } },
        { "habitat": { "equals": "grassland" } }
      ]
    }
  ]
}
```

---

## Practical examples

### Download only records with observations from a specific year

- Root logic: `AND`
- Condition: `date` → `year equals` → `2023`

### Exclude records with missing observer

- Root logic: `AND`
- Condition: `observer` → `is not null`

### Download a short list of specific species

- Root logic: `AND`
- Condition: `species` → `in list` → `Carabus coriaceus, Carabus granulatus, Abax parallelepipedus`

### Records from this season (after April 1, not yet in October)

- Root logic: `AND`
- Condition 1: `date` → `on or after` → `2024-04-01`
- Condition 2: `date` → `before` → `2024-10-01`

### Records from a specific date range across multiple years

- Root logic: `AND`
- Condition: `date` → `between` → Start: `2022-01-01`, End: `2024-12-31`

### Seasonal filter — spring and summer records regardless of year

- Root logic: `AND`
- Condition: `date` → `between days (MM-DD)` → Start: `04-01`, End: `08-31`

### Records from a winter period that crosses the year boundary

- Root logic: `AND`
- Condition: `date` → `between days (MM-DD)` → Start: `11-01`, End: `02-28`

### Records from specific years

- Root logic: `AND`
- Condition: `date` → `year in list` → `2021, 2022, 2023`

### Records from specific months (e.g. breeding season)

- Root logic: `AND`
- Condition: `date` → `month in list` → `4, 5, 6, 7`

### Records observed on weekends

- Root logic: `OR`
- Condition 1: `date` → `day of week (0-6)` → `0`
- Condition 2: `date` → `day of week (0-6)` → `6`

### Any of two observers, but not if species is missing

- Root logic: `AND`
- Group (OR logic):
  - Condition A: `observer` → `equals` → `John`
  - Condition B: `observer` → `equals` → `Maria`
- Condition: `species` → `is not null`

### Records that have a specific comment tag

- Root logic: `AND`
- Condition: `obm_comments` → `contains (case-sensitive)` → `approved`

### Records that have all of a set of required tags

- Root logic: `AND`
- Condition: `obm_comments` → `contains all (case-sensitive)` → `reviewed, final`

### Records that have none of a set of unwanted tags

- Root logic: `AND`
- Condition: `obm_comments` → `contains none (case-sensitive)` → `draft, incomplete, duplicate`

---

## Tips

- If no conditions are configured, all records in the table are downloaded (no filter is applied).
- Conditions with an empty value field are silently skipped — they do not restrict the download.
- The filter is applied server-side before transfer, so only records that match are sent to the device.
- Changing the selected table clears all conditions and groups automatically.
