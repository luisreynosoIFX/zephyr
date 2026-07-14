# Twister Build-Only Summary — PSE84 CM55

| Field | Value |
|---|---|
| **Board** | `kit_pse84_eval/pse846gps2dbzc4a/m55` |
| **Zephyr version** | `v4.4.0-7935-gcde0a961d820` |
| **Toolchain** | `zephyr/gnu` |
| **Commit date** | 2026-07-09 |
| **Run date** | 2026-07-10 |
| **Mode** | Build-only (`--build-only`) |

## Overall Results

| Metric | Count |
|---|---|
| Total test suites | **655** |
| Successfully built | **655** |
| Total test cases | **6 745** |
| Samples | 136 |
| Tests | 519 |

All 655 suites compiled successfully. No build failures. Test cases are marked
`not run` — expected for a build-only run (no hardware execution).

Build time: min 99.5 s · max 323.0 s · avg 198.5 s · total ≈ 36 h (parallel)

---

## Samples (136 suites)

| Category | Suites |
|---|---|
| `samples/subsys` | 82 |
| `samples/philosophers` | 9 |
| `samples/basic` | 8 |
| `samples/drivers` | 7 |
| `samples/sensor` | 6 |
| `samples/kernel` | 5 |
| `samples/cpp` | 3 |
| `samples/userspace` | 3 |
| `samples/psa` | 2 |
| `samples/data_structures` | 2 |
| `samples/net` | 2 |
| `samples/modules` | 2 |
| `samples/hello_world` | 1 |
| `samples/application_development` | 1 |
| `samples/arch` | 1 |
| `samples/boards` | 1 |
| `samples/synchronization` | 1 |

---

## Tests (519 suites)

| Category | Suites |
|---|---|
| `tests/lib` | 139 |
| `tests/kernel` | 125 |
| `tests/subsys` | 115 |
| `tests/drivers` | 55 |
| `tests/arch` | 24 |
| `tests/benchmarks` | 32 |
| `tests/ztest` | 9 |
| `tests/misc` | 5 |
| `tests/application_development` | 5 |
| `tests/cmake` | 2 |
| `tests/kconfig` | 2 |
| `tests/modules` | 2 |
| `tests/net` | 2 |
| `tests/crypto` | 1 |
| `tests/integration` | 1 |

---

## Files

| File | Description |
|---|---|
| `twister.json` | Full machine-readable results (all 655 suites) |
| `twister.xml` | JUnit XML |
| `twister_report.xml` | Twister-format XML report |
| `twister_suite_report.xml` | Suite-level XML report |
