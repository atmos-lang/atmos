# What Electronic Arts Has Open Sourced

Source: [github.com/electronicarts](https://github.com/electronicarts) — 60 public repositories total (confirmed via the GitHub API `public_repos` count), fetched 2026-07-05.

**Scope of this report:** the 52 repositories that are original EA projects, ordered by original creation date (ascending). The 8 repos below are excluded because they are forks of external projects (EA-maintained patches on someone else's code, not EA-authored):
`autoscaler`, `kops` (both forks of Kubernetes tooling, created 2017-09-07), `p4-plugin`, `pipeline-utility-steps-plugin` (Jenkins plugin forks, 2018-08-30), `flite` (2019-02-06), `eigen-git-mirror` (2019-02-28), `kubernetes` (2019-09-05), `FFmpeg` (2021-11-30).

**Line counts** are real counts from [`cloc`](https://github.com/AlDanial/cloc) run against a fresh shallow clone of each repo (code lines, i.e. excluding blank lines and comments). "Total lines" is every line in every tracked file (includes docs, data, generated/vendored assets — useful context for repos that are mostly non-code). One repo (`gigi-techniques`) has a very large single generated file that made `cloc`'s line-classification pass impractically slow to complete safely; for that repo only, "Code lines" reports the raw total-line count with a note.

| # | Repo | Created | Status | Primary Language | Code Lines | Total Lines |
|---|------|---------|--------|-------------------|-----------:|-------------:|
| 1 | [awsudo](https://github.com/electronicarts/awsudo) | 2015-09-01 | active | Ruby | 732 | 1,021 |
| 2 | [EASTL](https://github.com/electronicarts/EASTL) | 2015-12-15 | active | C++ | 129,800 | 202,428 |
| 3 | [gatling-aws-maven-plugin](https://github.com/electronicarts/gatling-aws-maven-plugin) | 2015-12-21 | active | Java | 1,393 | 2,439 |
| 4 | [ea-async](https://github.com/electronicarts/ea-async) | 2015-12-22 | active | Java | 7,260 | 10,520 |
| 5 | [ea-agent-loader](https://github.com/electronicarts/ea-agent-loader) | 2015-12-22 | archived | Java | 1,172 | 2,318 |
| 6 | [orbit](https://github.com/electronicarts/orbit) | 2016-03-31 | archived | — | 2 | 2 |
| 7 | [NetTAP](https://github.com/electronicarts/NetTAP) | 2017-02-21 | active | C# | 1,135 | 1,716 |
| 8 | [RenderWare3Docs](https://github.com/electronicarts/RenderWare3Docs) | 2017-02-23 | active | — (docs) | 77 | 43,161 |
| 9 | [ava-capture](https://github.com/electronicarts/ava-capture) | 2017-08-15 | active | Python | 35,369 | 54,871 |
| 10 | [EAAssert](https://github.com/electronicarts/EAAssert) | 2019-01-22 | active | C++ | 1,024 | 1,530 |
| 11 | [EAMain](https://github.com/electronicarts/EAMain) | 2019-01-22 | active | C++ | 2,897 | 4,292 |
| 12 | [EAStdC](https://github.com/electronicarts/EAStdC) | 2019-01-22 | active | C++ | 46,944 | 72,676 |
| 13 | [EAThread](https://github.com/electronicarts/EAThread) | 2019-01-22 | active | C++ | 22,922 | 38,373 |
| 14 | [EABase](https://github.com/electronicarts/EABase) | 2019-01-22 | active | C++ | 8,425 | 14,682 |
| 15 | [EATest](https://github.com/electronicarts/EATest) | 2019-01-22 | active | C++ | 2,084 | 4,284 |
| 16 | [dem-bones](https://github.com/electronicarts/dem-bones) | 2019-02-06 | active | C++ | 16,925 | 131,062 |
| 17 | [interactive_training](https://github.com/electronicarts/interactive_training) | 2019-06-28 | active | Jupyter Notebook | 388 | 4,542 |
| 18 | [EACopy](https://github.com/electronicarts/EACopy) | 2019-07-16 | active | C++ | 11,260 | 14,378 |
| 19 | [siggraph-asia-2019-gata](https://github.com/electronicarts/siggraph-asia-2019-gata) | 2019-09-03 | active | Python | 1,692 | 2,455 |
| 20 | [CnC_Remastered_Collection](https://github.com/electronicarts/CnC_Remastered_Collection) | 2020-03-30 | archived | C++ | 362,071 | 717,830 |
| 21 | [SimpleTeamSportsSimulator](https://github.com/electronicarts/SimpleTeamSportsSimulator) | 2020-05-04 | active | Python | 1,775 | 3,127 |
| 22 | [kara](https://github.com/electronicarts/kara) | 2020-08-20 | active | Scala | 2,311 | 4,219 |
| 23 | [harmony](https://github.com/electronicarts/harmony) | 2020-09-11 | active | Java | 13,251 | 17,532 |
| 24 | [character-motion-vaes](https://github.com/electronicarts/character-motion-vaes) | 2021-02-02 | active | Python | 4,213 | 66,708 |
| 25 | [MELE_ModdingSupport](https://github.com/electronicarts/MELE_ModdingSupport) | 2021-05-19 | active | C | 796 | 159,806 |
| 26 | [Tunable-Colorblindness-Solution](https://github.com/electronicarts/Tunable-Colorblindness-Solution) | 2021-08-17 | active | HLSL | 128 | 399 |
| 27 | [minicoros](https://github.com/electronicarts/minicoros) | 2022-06-14 | active | C++ | 3,039 | 3,901 |
| 28 | [fonttik](https://github.com/electronicarts/fonttik) | 2022-07-04 | active | C++ | 7,284 | 1,838,768 |
| 29 | [helmci](https://github.com/electronicarts/helmci) | 2022-12-06 | active | Rust | 6,368 | 13,084 |
| 30 | [fastnoise](https://github.com/electronicarts/fastnoise) | 2023-05-01 | active | C++ | 30,695 | 348,197 |
| 31 | [cpp-ml-intro](https://github.com/electronicarts/cpp-ml-intro) | 2023-10-11 | active | C++ | 124,217 | 283,731 |
| 32 | [IRIS](https://github.com/electronicarts/IRIS) | 2023-11-16 | active | C++ | 6,748 | 15,330 |
| 33 | [CNC_TS_and_RA2_Mission_Editor](https://github.com/electronicarts/CNC_TS_and_RA2_Mission_Editor) | 2024-03-05 | active | C++ | 62,989 | 512,743 |
| 34 | [rig-inversion](https://github.com/electronicarts/rig-inversion) | 2024-03-08 | active | Python | 316 | 546 |
| 35 | [gigi](https://github.com/electronicarts/gigi) | 2024-06-12 | active | C | 3,150,305 | 10,500,262 |
| 36 | [pbmpm](https://github.com/electronicarts/pbmpm) | 2024-07-08 | active | JavaScript | 4,012 | 190,716 |
| 37 | [CnC_Tiberian_Dawn](https://github.com/electronicarts/CnC_Tiberian_Dawn) | 2024-08-22 | archived | C++ | 99,300 | 229,447 |
| 38 | [CnC_Red_Alert](https://github.com/electronicarts/CnC_Red_Alert) | 2024-08-22 | archived | C++ | 215,980 | 815,264 |
| 39 | [CnC_Renegade](https://github.com/electronicarts/CnC_Renegade) | 2024-08-22 | archived | C++ | 653,770 | 1,293,894 |
| 40 | [CnC_Generals_Zero_Hour](https://github.com/electronicarts/CnC_Generals_Zero_Hour) | 2024-08-22 | archived | C++ | 1,298,323 | 2,291,557 |
| 41 | [IRIS-Unreal-Plugin](https://github.com/electronicarts/IRIS-Unreal-Plugin) | 2024-11-18 | active | C++ | 156,087 | 286,833 |
| 42 | [texturesets](https://github.com/electronicarts/texturesets) | 2024-12-11 | active | C++ | 7,971 | 22,978 |
| 43 | [CnC_Modding_Support](https://github.com/electronicarts/CnC_Modding_Support) | 2025-01-14 | archived | HLSL | 22,612,669 | 33,373,076 |
| 44 | [gigi-techniques](https://github.com/electronicarts/gigi-techniques) | 2025-01-24 | active | C++ | 25,724,007 † | 25,724,007 |
| 45 | [texturesets-demo](https://github.com/electronicarts/texturesets-demo) | 2025-03-14 | active | C++ | 755 | 1,273 |
| 46 | [mesh2splat](https://github.com/electronicarts/mesh2splat) | 2025-03-24 | active | C++ | 378,725 | 637,386 |
| 47 | [importance-sampled-FAST-noise](https://github.com/electronicarts/importance-sampled-FAST-noise) | 2025-03-28 | active | C++ | 4,314,587 | 14,436,931 |
| 48 | [tiny-voice2face](https://github.com/electronicarts/tiny-voice2face) | 2025-07-25 | active | JavaScript | 2,696 | 792,006 |
| 49 | [ShaderToHuman](https://github.com/electronicarts/ShaderToHuman) | 2025-09-03 | active | HLSL | 13,110 | 40,667 |
| 50 | [marling](https://github.com/electronicarts/marling) | 2026-02-06 | active | Python | 37,874 | 1,316,374 |
| 51 | [doltdb-operator](https://github.com/electronicarts/doltdb-operator) | 2026-02-27 | active | Go | 24,798 | 37,909 |
| 52 | [grpc-studio](https://github.com/electronicarts/grpc-studio) | 2026-05-26 | active | TypeScript | 38,447 | 52,692 |

† `gigi-techniques`: `cloc`'s code/comment/blank classification pass did not complete in a safe time/memory budget on this repo's content; the figure shown is the raw total line count across all tracked files, not a code-only count.

## Notable observations

- **EA's oldest open-source releases** are small infra/tooling utilities: `awsudo` (2015, AWS credential helper) and `EASTL` (2015, EA's STL-compatible C++ template library — still one of their most widely used open-source projects).
- **The EA "container" family** (`EAAssert`, `EAMain`, `EAStdC`, `EAThread`, `EABase`, `EATest`) was all released the same day, 2019-01-22 — a coordinated open-sourcing of the EASTL-adjacent core libraries.
- **Command & Conquer classics** were open-sourced in two waves: `CnC_Remastered_Collection` (2020) and then `CnC_Tiberian_Dawn`, `CnC_Red_Alert`, `CnC_Renegade`, `CnC_Generals_Zero_Hour` all on the same day, 2024-08-22.
- **Largest repos by code volume** are graphics/tooling projects with heavy generated or vendored content: `gigi-techniques`, `CnC_Modding_Support`, `gigi`, `importance-sampled-FAST-noise`, and `CnC_Generals_Zero_Hour`/`CnC_Renegade` (full game source).
- **Most recent releases** (2025-2026) skew toward graphics/rendering research (`mesh2splat`, `importance-sampled-FAST-noise`, `ShaderToHuman`) and internal developer tooling (`marling`, `doltdb-operator`, `grpc-studio`).
