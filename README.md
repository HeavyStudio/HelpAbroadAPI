# HelpAbroadAPI

[![JSON Validation](https://github.com/HeavyStudio/HelpAbroadAPI/actions/workflows/json-validator.yml/badge.svg)](https://github.com/HeavyStudio/HelpAbroadAPI/actions)
[![API Version](https://img.shields.io/badge/API-v1-blue.svg)](./v1/)
[![Pages](https://img.shields.io/badge/hosted%20on-GitHub%20Pages-181717.svg)](https://heavystudio.github.io/HelpAbroadAPI/)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

This repository serves as the single source of truth (SSOT) for the **HelpAbroad** application ecosystem. It contains curated, high-availability, offline-first datasets encompassing international emergency dispatch numbers and UI localization packages.

The primary objective of this architecture is to provide **zero-network overhead dependency structures** for native mobile clients, allowing seamless deserialization and full offline reliability in critical situations.

## Base URL

All endpoints are served as static JSON via GitHub Pages:

```
https://heavystudio.github.io/HelpAbroadAPI/
```

The `v1/` namespace is **immutable**: any breaking change will be released under a new version prefix (`v2/`, `v3/`, ...) so existing clients never break.

## Endpoints

| Resource              | Path                          | Description                                      |
| --------------------- | ----------------------------- | ------------------------------------------------ |
| Countries registry    | `v1/global_countries.json`    | Emergency contacts and metadata for every country |
| Locale (English)      | `v1/locales/en.json`          | Source language / fallback                       |
| Locale (French)       | `v1/locales/fr.json`          | French translation matrix                        |
| Locale (German)       | `v1/locales/de.json`          | German translation matrix                        |
| Locale (Spanish)      | `v1/locales/es.json`          | Spanish translation matrix                       |
| Locale (Italian)      | `v1/locales/it.json`          | Italian translation matrix                       |

## Manifest & Caching

`v1/manifest.json` is the entry point for clients that want to avoid re-downloading unchanged data. Fetch it first, compare against your local cache, and only download resources whose `sha256` (or `updated_at`) has changed.

```json
{
  "api_version": "1.0.0",
  "generated_at": "2026-05-23T13:27:00Z",
  "resources": {
    "global_countries.json": {
      "updated_at": "2026-05-23T12:26:00Z",
      "sha256": "<hex-encoded SHA-256 of the file contents>"
    },
    "locales/en.json": { "updated_at": "…", "sha256": "…" },
    "locales/fr.json": { "updated_at": "…", "sha256": "…" }
  }
}
```

**Recommended client flow:**

1. `GET v1/manifest.json` (small, fast).
2. For each entry in `resources`, compare `sha256` against the cached value.
3. Only `GET` resources whose checksum changed.
4. Persist the new manifest atomically once all downloads succeed.

`api_version` follows semver: a major bump (`2.0.0`) means breaking schema changes and will only ever ship under a new `vN/` prefix. Minor / patch bumps remain backward-compatible within `v1/`.

> **Tip:** GitHub Pages also serves `ETag` and `Last-Modified` headers, so you can additionally send `If-None-Match` on each resource request to receive a `304 Not Modified` and skip the body entirely.

## Usage

### Kotlin Multiplatform (Ktor + kotlinx.serialization)

The primary consumer of this API is the HelpAbroad KMP client. Add the dependencies to your shared module:

```kotlin
// build.gradle.kts (commonMain)
dependencies {
    implementation("io.ktor:ktor-client-core:<latest>")
    implementation("io.ktor:ktor-client-content-negotiation:<latest>")
    implementation("io.ktor:ktor-serialization-kotlinx-json:<latest>")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:<latest>")
}
```

Define the data models:

```kotlin
@Serializable
data class Country(
    val id: String,
    @SerialName("iso_3") val iso3: String,
    val prefix: String,
    val continent: String,
    @SerialName("member_112") val member112: Boolean,
    val emergency: Emergency,
    val geo: Geo,
)

@Serializable
data class Emergency(
    val police: List<String>,
    val medical: List<String>,
    val firefighters: List<String>,
)

@Serializable
data class Geo(
    val latitude: Double,
    val longitude: Double
)

@Serializable
data class Locale(
    val police: String,
    val medical: String,
    val firefighters: String,
    val dispatch: String
)
```

Fetch from `commonMain`:

```kotlin
private const val BASE = "https://heavystudio.github.io/HelpAbroadAPI/v1"

class HelpAbroadClient {
    private val http = HttpClient {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true })
        }
    }

    suspend fun countries(): Map<String, Country> = http.get("$BASE/global_countries.json").body()

    suspend fun locale(lang: String): Locale = http.get("$BASE/locales/$lang.json").body()
}
```

> **Tip:** because the dataset is offline-first, cache the JSON locally on first fetch and refresh in the background. The `v1/` namespace is immutable, so cached payloads stay schema-compatible.

### cURL

```sh
curl -s https://heavystudio.github.io/HelpAbroadAPI/v1/global_countries.json | jq '.FR'
curl -s https://heavystudio.github.io/HelpAbroadAPI/v1/locales/fr.json
```

### JavaScript / TypeScript

```ts
const BASE = "https://heavystudio.github.io/HelpAbroadAPI/v1";

const [countries, locale] = await Promise.all([
    fetch(`${BASE}/global_countries.json`).then(r => r.json()),
    fetch(`${BASE}/locales/fr.json`).then(r => r.json()),
]);

console.log(locale.police, countries.FR.emergency.police);
```

### Swift (iOS)

```swift
let url = URL(string: "https://heavystudio.github.io/HelpAbroadAPI/v1/global_countries.json")!
let (data, _) = try await URLSession.shared.data(from: url)
let countries = try JSONDecoder().decode([String: Country].self, from: data)
```

## Data Schemas

### `global_countries.json`

Keyed by ISO 3166-1 alpha-2 country code:

```json
{
    "FR": {
        "id": "FR",
        "iso_3": "FRA",
        "prefix": "+33",
        "continent": "europe",
        "member_112": true,
        "emergency": {
            "police": ["17"],
            "medical": ["15"],
            "firefighters": ["18"]
        },
        "geo": {
            "latitude": 46.2276,
            "longitude": 2.2137
        }
    }
}
```

| Field          | Type             | Notes                                                |
| -------------- | ---------------- | ---------------------------------------------------- |
| `id`           | string           | ISO 3166-1 alpha-2                                   |
| `iso_3`        | string           | ISO 3166-1 alpha-3                                   |
| `prefix`       | string           | International dialing prefix                         |
| `continent`    | string           | `africa` \| `americas` \| `asia` \| `europe` \| `oceania` |
| `member_112`   | boolean          | Whether 112 is a recognized emergency number         |
| `emergency.*`  | array of strings | Empty array = data not yet curated                   |
| `geo`          | object           | Approximate country centroid                         |

### `locales/{lang}.json`

Flat key/value dictionary of UI strings. `en.json` is the source of truth — every other locale mirrors its keys.

```json
{
    "police": "Police",
    "medical": "Medical Emergencies",
    "firefighters": "Firefighters",
    "dispatch": "General Emergency"
}
```

## Repository Architecture

```text
.github/
└── workflows/
    └── json-validator.yml     # GitHub Actions CI syntax linter
v1/                            # API Namespace Version 1 (Immutable)
├── locales/                   # Client-side UI string localizations
│   ├── de.json
│   ├── en.json                # Source / Fallback language
│   ├── es.json
│   ├── fr.json
│   └── it.json
└── global_countries.json      # Global emergency contacts registry
README.md
```

## Versioning Policy

- `v1/` is **frozen** in terms of structure. Additive, backward-compatible changes (new countries, new locale keys, filled-in `emergency` arrays) are allowed.
- Any breaking change (field rename, type change, removed key) ships under a new `vN/` prefix.

## Contributing

PRs are welcome — especially to fill in missing emergency numbers. All JSON files must pass the CI syntax check (`jq empty`). For locale changes, mirror the full key set of `v1/locales/en.json`.

## License

This dataset and its accompanying tooling are released under the [Creative Commons Attribution 4.0 International License](LICENSE) (**CC-BY-4.0**).

You are free to share and adapt the material for any purpose — including commercial use — as long as you give appropriate credit.

**Suggested attribution:**

> Emergency dispatch data sourced from [HelpAbroadAPI](https://github.com/HeavyStudio/HelpAbroadAPI), © HeavyStudio, licensed under CC-BY-4.0.

The license covers both the curated dataset (`v1/**/*.json`) and the glue code in this repository (`scripts/`, `.github/workflows/`). The underlying *facts* (e.g., the number "112" being a European emergency line) are not themselves copyrightable; the license applies to the selection, structuring, and presentation of those facts as a coherent dataset.