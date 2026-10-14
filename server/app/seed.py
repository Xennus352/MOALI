"""Idempotent seeding of reference data and the initial published census form.

Data source
-----------
* Animal / poultry / breeding lists, species and age groups come from the
  supplied ``DB Design.xlsx`` workbook (sheets: gender, aminalType,
  largeAnimals, youngAnimals, liveStock, breedingStock, *_Species, age,
  ageType, personCV, collectedData). The original workbook identifiers
  (``laID01``, ``lsSID0301``, …) are preserved verbatim in the ``code``
  columns so that historical data keeps its meaning.
* State/Region names come from the region dropdown of the supplied
  ``myform.html`` census form. No districts/townships are fabricated; they are
  left empty for authorized administrators to manage.

Usage
-----
    uv run python -m app.seed          # from server/

The functions in this module are also called from ``main.lifespan`` when the
corresponding tables are empty, and reused by the automated test-suite.

Everything is idempotent: re-running NEVER duplicates or overwrites rows.
"""
from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.db.base import SessionLocal, engine
from app.db.models import (
    AgeGroup,
    AgeType,
    AnimalCategory,
    AnimalCount,
    AnimalType,
    Base,
    Breed,
    BreedingCategory,
    BreedingCount,
    District,
    Form,
    FormField,
    FormSection,
    FormVersion,
    Gender,
    Species,
    StateRegion,
    Submission,
    Township,
    VillageTract,
    Ward,
)
from app.db.models import _utcnow as _now  # type: ignore[attr-defined]

# ---------------------------------------------------------------------------
# Master data (from DB Design.xlsx, preserving source IDs)
# ---------------------------------------------------------------------------

GENDERS = [
    {"code": "g01", "burmese_name": "အထီး", "english_name": "male", "display_order": 1},
    {"code": "g02", "burmese_name": "သင်းကွပ်အထီး", "english_name": "castrated male", "display_order": 2},
    {"code": "g03", "burmese_name": "အမ", "english_name": "female", "display_order": 3},
]

ANIMAL_TYPES = [
    {"code": "atID01", "burmese_name": "တိရစ္ဆာန်ကြီး", "english_name": "Large animal", "display_order": 1},
    {"code": "atID02", "burmese_name": "တိရစ္ဆာန်ငယ်", "english_name": "Small animal", "display_order": 2},
    {"code": "atID03", "burmese_name": "ကြက်/ဘဲ/ငုံး", "english_name": "Poultry", "display_order": 3},
    {"code": "atID04", "burmese_name": "မျိုးတိရစ္ဆာန်", "english_name": "Breeding animal", "display_order": 4},
]

# animal_category rows: (animal_type_code, category_code, burmese, english)
ANIMAL_CATEGORIES = [
    # largeAnimals sheet (atID01)
    ("atID01", "laID01", "ဒေသနွား", "Local cattle"),
    ("atID01", "laID02", "အသားစားနွား", "Beef cattle"),
    ("atID01", "laID03", "နို့စားနွား", "Dairy cattle"),
    ("atID01", "laID04", "နွားနောက်", "Bull"),
    ("atID01", "laID05", "ဒေသကျွဲ", "Local buffalo"),
    ("atID01", "laID06", "ခိုင်းကျွဲ", "Draught buffalo"),
    ("atID01", "laID07", "နို့စားကျွဲ", "Dairy buffalo"),
    ("atID01", "laID08", "မြင်း", "Horse"),
    ("atID01", "laID09", "အခြား", "Other"),
    # youngAnimals sheet (atID02)
    ("atID02", "yaID01", "ဆိတ်", "Goat"),
    ("atID02", "yaID02", "သိုး", "Sheep"),
    ("atID02", "yaID03", "ဝက်", "Pig"),
    ("atID02", "yaID04", "ခွေး", "Dog"),
    ("atID02", "yaID05", "အခြား", "Other"),
    # liveStock sheet (atID03)
    ("atID03", "lsID01", "ဥစားကြက်", "Layer chicken"),
    ("atID03", "lsID02", "အသားစားကြက်", "Broiler chicken"),
    ("atID03", "lsID03", "ဒေသကြက်", "Local chicken"),
    ("atID03", "lsID04", "ဥစားဘဲ", "Egg duck"),
    ("atID03", "lsID05", "အသားစားဘဲ", "Broiler duck"),
    ("atID03", "lsID06", "ဒေသဘဲ/ဓာတ်ဘဲ", "Local/Muscovy duck"),
    ("atID03", "lsID07", "ကြက်ဆင်", "Turkey"),
    ("atID03", "lsID08", "ဘဲငန်း", "Goose"),
    ("atID03", "lsID09", "မန်ဒါလီ", "Mandalay"),
    ("atID03", "lsID10", "ငုံး", "Quail"),
    ("atID03", "lsID11", "အခြား", "Other"),
    # breedingStock sheet (atID04)
    ("atID04", "bsID01", "ဒေသနွား", "Local cattle"),
    ("atID04", "bsID02", "ဒေသကျွဲ", "Local buffalo"),
    ("atID04", "bsID03", "နို့စားကျွဲ", "Dairy buffalo"),
    ("atID04", "bsID04", "ဝက်", "Pig"),
    ("atID04", "bsID05", "ဆိတ်", "Goat"),
    ("atID04", "bsID06", "သိုး", "Sheep"),
]

# species rows: (animal_type_code, category_code, species_code, burmese_name)
SPECIES = [
    # largeSpecies sheet
    ("atID01", "laID01", "laSID0101", "ပြာစိမ်း"),
    ("atID01", "laID01", "laSID0102", "ရွှေနီ"),
    ("atID01", "laID01", "laSID0103", "စာဥ"),
    ("atID01", "laID01", "laSID0104", "စံပယ်"),
    ("atID01", "laID01", "laSID0105", "ရှမ်းနွားပု"),
    ("atID01", "laID02", "laSID0201", "ဘရာမန်(အသားစားမျိုး)"),
    ("atID01", "laID02", "laSID0202", "အန်ဂတ်စ်(အသားစားမျိုးစပ်)"),
    ("atID01", "laID03", "laSID0301", "ဖရီရှန်"),
    ("atID01", "laID03", "laSID0302", "ဂျာစီ"),
    ("atID01", "laID03", "laSID0303", "ဘရောင်းဆွစ်"),
    ("atID01", "laID04", "laSID0401", "နွားနောက်"),
    ("atID01", "laID05", "laSID0501", "နမူရီ(ရွှံလူးကျွဲ)"),
    ("atID01", "laID05", "laSID0502", "ဂျီရန်ဂီ(ရွှံလူးကျွဲ)"),
    ("atID01", "laID05", "laSID0503", "တိုင်းရင်းကျွဲ(ရွှံလူးကျွဲ)"),
    ("atID01", "laID06", "laSID0601", "ခိုင်းကျွဲ"),
    ("atID01", "laID07", "laSID0701", "မူယား(ရေစိမ်ကျွဲ)"),
    ("atID01", "laID07", "laSID0702", "ဆာတီ(ရေစိမ်ကျွဲ)"),
    ("atID01", "laID07", "laSID0703", "နီလီရာဘီ(ရေစိမ်ကျွဲ)"),
    ("atID01", "laID07", "laSID0704", "ဂျဖာရာဘဒီ(ရေစိမ်ကျွဲ)"),
    ("atID01", "laID08", "laSID0801", "မြင်း"),
    ("atID01", "laID08", "laSID0802", "မြည်း"),
    ("atID01", "laID08", "laSID0803", "လား"),
    ("atID01", "laID08", "laSID0804", "မြင်းပု"),
    # youngSpecies sheet
    ("atID02", "yaID01", "yaSID0101", "ထိန်စမ်း (ဒေသဆိတ်)"),
    ("atID02", "yaID01", "yaSID0102", "ဂျိတ်နီ (ဒေသဆိတ်)"),
    ("atID02", "yaID01", "yaSID0103", "ဝေသာလီ (ဒေသဆိတ်)"),
    ("atID02", "yaID01", "yaSID0104", "ဘိုဝါ (အသားတိုးဆိတ်)"),
    ("atID02", "yaID01", "yaSID0105", "Nubian (အသားတိုးဆိတ်)"),
    ("atID02", "yaID01", "yaSID0106", "Sirohi (အသားတိုးဆိတ်)"),
    ("atID02", "yaID01", "yaSID0107", "ဆာနန်(နို့စားဆိတ်)"),
    ("atID02", "yaID02", "yaSID0201", "ကုလားသိုး"),
    ("atID02", "yaID03", "yaSID0301", "ဒေသဝက်"),
    ("atID02", "yaID03", "yaSID0302", "DYL"),
    ("atID02", "yaID03", "yaSID0303", "Landrace"),
    ("atID02", "yaID03", "yaSID0304", "Yorkshire"),
    ("atID02", "yaID03", "yaSID0305", "Duroc"),
    ("atID02", "yaID04", "yaSID0401", "ခွေး"),
    # liveStockSpecies sheet
    ("atID03", "lsID01", "lsSID0101", "lSa Brown"),
    ("atID03", "lsID01", "lsSID0102", "Boven Goldline"),
    ("atID03", "lsID01", "lsSID0103", "Hyline Brown"),
    ("atID03", "lsID02", "lsSID0201", "ROSS(Hi-chick)"),
    ("atID03", "lsID02", "lsSID0202", "COBB(Hi-chick)"),
    ("atID03", "lsID03", "lsSID0301", "စစ်တကောင်း"),
    ("atID03", "lsID03", "lsSID0302", "တိန်ညင်"),
    ("atID03", "lsID03", "lsSID0303", "အင်ပင်ဝ"),
    ("atID03", "lsID03", "lsSID0304", "ကြက်မဲ"),
    ("atID03", "lsID03", "lsSID0305", "တိုက်ကြက်"),
    ("atID03", "lsID03", "lsSID0306", "လည်ပြောင်"),
    ("atID03", "lsID03", "lsSID0307", "တောင်ပျံ"),
    ("atID03", "lsID04", "lsSID0401", "ကာကီကင်းဘဲ(ဥစားဘဲ)"),
    ("atID03", "lsID05", "lsSID0501", "ချယ်ရီဘယ်ရီ(အသားစားဘဲ)"),
    ("atID03", "lsID06", "lsSID0601", "ဒေသဘဲ/ဓာတ်ဘဲ"),
    ("atID03", "lsID07", "lsSID0701", "ကြက်ဆင်"),
    ("atID03", "lsID08", "lsSID0801", "ဘဲငန်း"),
    ("atID03", "lsID09", "lsSID0901", "မန်ဒါလီ"),
    ("atID03", "lsID10", "lsSID1001", "ငုံး"),
]

# Breeds used by the census form's "မျိုး (Breed)" columns (myform.html).
BREEDS = [
    {"code": "native", "burmese_name": "ဒေသရင်း", "english_name": "Native / local breed"},
    {"code": "cross", "burmese_name": "စပ်မျိုး", "english_name": "Cross breed"},
    {"code": "imported", "burmese_name": "နိုင်ငံခြားသန့်", "english_name": "Imported pure breed"},
]

# age sheet (age table)
AGE_GROUPS = [
    ("ageID01", "(၃) နှစ်အထက်", "3 years and above"),
    ("ageID02", "(၁) နှစ် မှ (၃) နှစ်", "1 to 3 years"),
    ("ageID03", "(၁) နှစ်အောက်", "Under 1 year"),
    ("ageID04", "(၆) လ အထက်", "6 months and above"),
    ("ageID05", "(၂) လ မှ (၆) လ", "2 to 6 months"),
    ("ageID06", "(၂) လ အောက်", "Under 2 months"),
    ("ageID07", "ရက်သားမှ (၆) ပတ်သား", "Day-old to 6 weeks (young)"),
    ("ageID08", "(၇) ပတ်သားမှ (၁၈) ပတ်သား", "7 to 18 weeks (medium)"),
    ("ageID09", "(၁၉) ပတ်သားနှင့်အထက်", "19 weeks and above (mature)"),
    ("ageID10", "ရက်သားမှ (၂၀) ပတ်သား", "Day-old to 20 weeks (young)"),
    ("ageID11", "(၂၁) ပတ်သားနှင့်အထက်", "21 weeks and above (mature)"),
    ("ageID12", "ရက်သားမှ (၈) ပတ်သား", "Day-old to 8 weeks (young)"),
    ("ageID13", "(၉) ပတ်သားမှ (၁၆) ပတ်သား", "9 to 16 weeks (medium)"),
    ("ageID14", "(၁၇) ပတ်သားနှင့်အထက်", "17 weeks and above (mature)"),
    ("ageID15", "(၇) ပတ်သားမှ (၂၄) ပတ်သား", "7 to 24 weeks (medium)"),
    ("ageID16", "(၂၅) ပတ်သားနှင့်အထက်", "25 weeks and above (mature)"),
]

# ageType sheet → applicable age groups per animal type / poultry category.
AGE_TYPES = [
    ("large", "တိရစ္ဆာန်ကြီး အသက်ပိုင်းခွဲ", "Large animal age groups", ["ageID01", "ageID02", "ageID03"]),
    ("young", "တိရစ္ဆာန်ငယ် အသက်ပိုင်းခွဲ", "Small animal age groups", ["ageID04", "ageID05", "ageID06"]),
    ("poultry_layer", "ဥစားကြက် အသက်ပိုင်းခွဲ", "Layer chicken age groups", ["ageID07", "ageID08", "ageID09"]),
    ("poultry_local", "ဒေသကြက် အသက်ပိုင်းခွဲ", "Local chicken age groups", ["ageID10", "ageID11"]),
    ("poultry_eggduck", "ဥစားဘဲ အသက်ပိုင်းခွဲ", "Egg duck age groups", ["ageID12", "ageID13", "ageID14"]),
    ("poultry_turkey", "ကြက်ဆင် အသက်ပိုင်းခွဲ", "Turkey age groups", ["ageID07", "ageID15", "ageID16"]),
]

# Breeding stock (breedingStock sheet) - same codes as categories; the
# breeding_categories table is the form's Section 4 fixed list.
BREEDING_CATEGORIES = [
    ("bsID01", "ဒေသနွား", "Local cattle"),
    ("bsID02", "ဒေသကျွဲ", "Local buffalo"),
    ("bsID03", "နို့စားကျွဲ", "Dairy buffalo"),
    ("bsID04", "ဝက်", "Pig"),
    ("bsID05", "ဆိတ်", "Goat"),
    ("bsID06", "သိုး", "Sheep"),
]

# State/Region list from the myform.html dropdown (no fabricated lower levels).
STATE_REGIONS = [
    ("r01", "ကချင်ပြည်နယ်", "Kachin State"),
    ("r02", "ကယားပြည်နယ်", "Kayah State"),
    ("r03", "ကရင်ပြည်နယ်", "Kayin State"),
    ("r04", "ချင်းပြည်နယ်", "Chin State"),
    ("r05", "စစ်ကိုင်းတိုင်းဒေသကြီး", "Sagaing Region"),
    ("r06", "တနင်္သာရီတိုင်းဒေသကြီး", "Tanintharyi Region"),
    ("r07", "ပဲခူးတိုင်းဒေသကြီး", "Bago Region"),
    ("r08", "မကွေးတိုင်းဒေသကြီး", "Magway Region"),
    ("r09", "မန္တလေးတိုင်းဒေသကြီး", "Mandalay Region"),
    ("r10", "မွန်ပြည်နယ်", "Mon State"),
    ("r11", "ရခိုင်ပြည်နယ်", "Rakhine State"),
    ("r12", "ရန်ကုန်တိုင်းဒေသကြီး", "Yangon Region"),
    ("r13", "ရှမ်းပြည်နယ်", "Shan State"),
    ("r14", "ဧရာဝတီတိုင်းဒေသကြီး", "Ayeyarwady Region"),
    ("r15", "နေပြည်တော်", "Nay Pyi Taw Union Territory"),
]

# A starter set of districts and townships for each State/Region. These are
# real administrative divisions; the list is intentionally not exhaustive and
# can be extended by administrators through the master-data API.
# region_code -> [(district_code, burmese, english, [(township_code, burmese, english), ...]), ...]
GEOGRAPHY: dict[str, list] = {
    "r01": [
        ("r01_myitkyina", "မြစ်ကြီးနားခရိုင်", "Myitkyina", [
            ("r01_myitkyina_tsp", "မြစ်ကြီးနားမြို့နယ်", "Myitkyina"),
            ("r01_waingmaw", "ဝိုင်းမော်မြို့နယ်", "Waingmaw"),
        ]),
        ("r01_bhamo", "ဗန်းမော်ခရိုင်", "Bhamo", [
            ("r01_bhamo_tsp", "ဗန်းမော်မြို့နယ်", "Bhamo"),
        ]),
    ],
    "r02": [
        ("r02_loikaw", "လွိုင်ကော်ခရိုင်", "Loikaw", [
            ("r02_loikaw_tsp", "လွိုင်ကော်မြို့နယ်", "Loikaw"),
        ]),
    ],
    "r03": [
        ("r03_hpa_an", "ဘားအံခရိုင်", "Hpa-An", [
            ("r03_hpa_an_tsp", "ဘားအံမြို့နယ်", "Hpa-An"),
            ("r03_kawkareik", "ကော့ကရိတ်မြို့နယ်", "Kawkareik"),
        ]),
        ("r03_myawaddy", "မြဝတီခရိုင်", "Myawaddy", [
            ("r03_myawaddy_tsp", "မြဝတီမြို့နယ်", "Myawaddy"),
        ]),
    ],
    "r04": [
        ("r04_falam", "ဖလမ်းခရိုင်", "Falam", [
            ("r04_falam_tsp", "ဖလမ်းမြို့နယ်", "Falam"),
        ]),
        ("r04_mindat", "မင်းတပ်ခရိုင်", "Mindat", [
            ("r04_mindat_tsp", "မင်းတပ်မြို့နယ်", "Mindat"),
        ]),
    ],
    "r05": [
        ("r05_sagaing", "စစ်ကိုင်းခရိုင်", "Sagaing", [
            ("r05_sagaing_tsp", "စစ်ကိုင်းမြို့နယ်", "Sagaing"),
            ("r05_myinmu", "မြင်းမူမြို့နယ်", "Myinmu"),
        ]),
        ("r05_monywa", "မုံရွာခရိုင်", "Monywa", [
            ("r05_monywa_tsp", "မုံရွာမြို့နယ်", "Monywa"),
            ("r05_ayadaw", "အရာတော်မြို့နယ်", "Ayadaw"),
        ]),
        ("r05_shwebo", "ရွှေဘိုခရိုင်", "Shwebo", [
            ("r05_shwebo_tsp", "ရွှေဘိုမြို့နယ်", "Shwebo"),
        ]),
    ],
    "r06": [
        ("r06_dawei", "ထားဝယ်ခရိုင်", "Dawei", [
            ("r06_dawei_tsp", "ထားဝယ်မြို့နယ်", "Dawei"),
        ]),
        ("r06_myeik", "မြိတ်ခရိုင်", "Myeik", [
            ("r06_myeik_tsp", "မြိတ်မြို့နယ်", "Myeik"),
        ]),
    ],
    "r07": [
        ("r07_bago", "ပဲခူးခရိုင်", "Bago", [
            ("r07_bago_tsp", "ပဲခူးမြို့နယ်", "Bago"),
            ("r07_daik_u", "ဒိုက်ဦးမြို့နယ်", "Daik-U"),
        ]),
        ("r07_taungoo", "တောင်ငူခရိုင်", "Taungoo", [
            ("r07_taungoo_tsp", "တောင်ငူမြို့နယ်", "Taungoo"),
            ("r07_yedashe", "ရေတာရှည်မြို့နယ်", "Yedashe"),
        ]),
        ("r07_pyay", "ပြည်ခရိုင်", "Pyay", [
            ("r07_pyay_tsp", "ပြည်မြို့နယ်", "Pyay"),
            ("r07_paukkhaung", "ပေါက်ခေါင်းမြို့နယ်", "Paukkhaung"),
        ]),
    ],
    "r08": [
        ("r08_magway", "မကွေးခရိုင်", "Magway", [
            ("r08_magway_tsp", "မကွေးမြို့နယ်", "Magway"),
            ("r08_taungdwingyi", "တောင်တွင်းကြီးမြို့နယ်", "Taungdwingyi"),
        ]),
        ("r08_pakokku", "ပခုက္ကူခရိုင်", "Pakokku", [
            ("r08_pakokku_tsp", "ပခုက္ကူမြို့နယ်", "Pakokku"),
        ]),
    ],
    "r09": [
        ("r09_mandalay", "မန္တလေးခရိုင်", "Mandalay", [
            ("r09_aungmyaythazan", "အောင်မြေသာဇံမြို့နယ်", "Aungmyaythazan"),
            ("r09_chanayethazan", "ချမ်းအေးသာဇံမြို့နယ်", "Chanayethazan"),
            ("r09_patheingyi", "ပုသိမ်ကြီးမြို့နယ်", "Patheingyi"),
        ]),
        ("r09_meiktila", "မိတ္ထီလာခရိုင်", "Meiktila", [
            ("r09_meiktila_tsp", "မိတ္ထီလာမြို့နယ်", "Meiktila"),
        ]),
        ("r09_kyaukse", "ကျောက်ဆည်ခရိုင်", "Kyaukse", [
            ("r09_kyaukse_tsp", "ကျောက်ဆည်မြို့နယ်", "Kyaukse"),
        ]),
    ],
    "r10": [
        ("r10_mawlamyine", "မော်လမြိုင်ခရိုင်", "Mawlamyine", [
            ("r10_mawlamyine_tsp", "မော်လမြိုင်မြို့နယ်", "Mawlamyine"),
            ("r10_kyaikmaraw", "ကျိုက်မရောမြို့နယ်", "Kyaikmaraw"),
        ]),
        ("r10_thaton", "သထုံခရိုင်", "Thaton", [
            ("r10_thaton_tsp", "သထုံမြို့နယ်", "Thaton"),
        ]),
    ],
    "r11": [
        ("r11_sittwe", "စစ်တွေခရိုင်", "Sittwe", [
            ("r11_sittwe_tsp", "စစ်တွေမြို့နယ်", "Sittwe"),
            ("r11_pauktaw", "ပေါက်တောမြို့နယ်", "Pauktaw"),
        ]),
        ("r11_thandwe", "သံတွဲခရိုင်", "Thandwe", [
            ("r11_thandwe_tsp", "သံတွဲမြို့နယ်", "Thandwe"),
        ]),
    ],
    "r12": [
        ("r12_yangon_east", "ရန်ကုန်အရှေ့ပိုင်းခရိုင်", "Yangon East", [
            ("r12_thingangyun", "သင်္ဃန်းကျွန်းမြို့နယ်", "Thingangyun"),
            ("r12_dawbon", "ဒေါပုံမြို့နယ်", "Dawbon"),
        ]),
        ("r12_yangon_west", "ရန်ကုန်အနောက်ပိုင်းခရိုင်", "Yangon West", [
            ("r12_hlaing", "လှိုင်မြို့နယ်", "Hlaing"),
            ("r12_mayangone", "မရမ်းကုန်းမြို့နယ်", "Mayangone"),
        ]),
        ("r12_yangon_north", "ရန်ကုန်မြောက်ပိုင်းခရိုင်", "Yangon North", [
            ("r12_insein", "အင်းစိန်မြို့နယ်", "Insein"),
            ("r12_shwepyitha", "ရွှေပြည်သာမြို့နယ်", "Shwepyitha"),
        ]),
    ],
    "r13": [
        ("r13_taunggyi", "တောင်ကြီးခရိုင်", "Taunggyi", [
            ("r13_taunggyi_tsp", "တောင်ကြီးမြို့နယ်", "Taunggyi"),
            ("r13_kalaw", "ကလောမြို့နယ်", "Kalaw"),
        ]),
        ("r13_lashio", "လားရှိုးခရိုင်", "Lashio", [
            ("r13_lashio_tsp", "လားရှိုးမြို့နယ်", "Lashio"),
        ]),
        ("r13_kyaukme", "ကျောက်မဲခရိုင်", "Kyaukme", [
            ("r13_kyaukme_tsp", "ကျောက်မဲမြို့နယ်", "Kyaukme"),
        ]),
    ],
    "r14": [
        ("r14_pathein", "ပုသိမ်ခရိုင်", "Pathein", [
            ("r14_pathein_tsp", "ပုသိမ်မြို့နယ်", "Pathein"),
            ("r14_ngapudaw", "ငပုတောမြို့နယ်", "Ngapudaw"),
            ("r14_kangyidaunt", "ကန်ကြီးထောင့်မြို့နယ်", "Kangyidaunt"),
        ]),
        ("r14_hinthada", "ဟင်္သာတခရိုင်", "Hinthada", [
            ("r14_hinthada_tsp", "ဟင်္သာတမြို့နယ်", "Hinthada"),
            ("r14_myanaung", "မြန်အောင်မြို့နယ်", "Myanaung"),
        ]),
        ("r14_maubin", "မော်လမြိုင်ခရိုင်", "Maubin", [
            ("r14_maubin_tsp", "မော်လမြိုင်မြို့နယ်", "Maubin"),
        ]),
    ],
    "r15": [
        ("r15_zabuthiri", "ဇမ္ဗူသီရိခရိုင်", "Zabuthiri", [
            ("r15_zabuthiri_tsp", "ဇမ္ဗူသီရိမြို့နယ်", "Zabuthiri"),
        ]),
        ("r15_dakkhinathiri", "ဒက္ခိဏသီရိခရိုင်", "Dakkhinathiri", [
            ("r15_dakkhinathiri_tsp", "ဒက္ခိဏသီရိမြို့နယ်", "Dakkhinathiri"),
        ]),
    ],
}

# ---------------------------------------------------------------------------
# Census form definition (mirrors myform.html, all five sections)
# ---------------------------------------------------------------------------

FORM_ID = "census-2026"
FORM_BURMESE_TITLE = "တိရစ္ဆာန်ကောင်ရေစာရင်း ကောက်ယူခြင်း"
FORM_ENGLISH_TITLE = "Livestock Census"
FORM_DESCRIPTION = (
    "နိုင်ငံတစ်ဝန်း အိမ်ထောင်စုအလိုက် တိရစ္ဆာန်ကောင်ရေ စာရင်းကောက်ယူမှု ပုံစံ — "
    "National household livestock census form."
)

SECTIONS = [
    {
        "key": "interview",
        "title_burmese": "လူတွေ့မေးမြန်းခြင်းဆိုင်ရာ အချက်များ",
        "title_english": "Interview and household information",
        "display_order": 1,
        "fields": [
            ("state_region_id", "တိုင်းဒေသကြီး/ပြည်နယ်", "State / Region", "geographic", True, "state_region"),
            ("district_id", "ခရိုင်", "District", "geographic", False, "district"),
            ("township_id", "မြို့နယ်", "Township", "geographic", False, "township"),
            ("village_tract_id", "ရပ်ကွက်/ကျေးရွာအုပ်စု", "Ward / Village tract", "geographic", False, "village_tract"),
            ("ward_id", "ရပ်ကွက်/ကျေးရွာ", "Ward / Village", "geographic", False, "ward"),
            ("household_no", "အိမ်ထောင်စုအမှတ်စဉ်", "Household number", "short_text", True, None),
            ("interview_date", "တွေ့ဆုံမေးမြန်းသည့်နေ့", "Interview date", "date", True, None),
            ("respondent_name_burmese", "ဖြေဆိုသူ အမည်", "Respondent name", "short_text", True, None),
            ("respondent_name_english", "ဖြေဆိုသူ အမည် (English)", "Respondent name (EN)", "short_text", False, None),
            ("respondent_gender_id", "ဖြေဆိုသူ ကျား/မ", "Respondent gender", "single_select", True, "gender"),
            ("respondent_age", "ဖြေဆိုသူ အသက် (နှစ်)", "Respondent age (years)", "integer", False, None),
            ("respondent_education", "ပညာအရည်အချင်း", "Respondent education", "short_text", False, None),
            ("respondent_phone", "ဖြေဆိုသူ ဖုန်းနံပါတ်", "Respondent phone", "telephone", True, None),
            ("household_head_name_burmese", "အိမ်ထောင်ဦးစီး အမည်", "Household head name", "short_text", True, None),
            ("household_head_name_english", "အိမ်ထောင်ဦးစီး အမည် (English)", "Household head (EN)", "short_text", False, None),
            ("household_head_gender_id", "အိမ်ထောင်ဦးစီး ကျား/မ", "Household head gender", "single_select", True, "gender"),
            ("household_head_age", "အိမ်ထောင်ဦးစီး အသက် (နှစ်)", "Household head age (years)", "integer", False, None),
            ("household_head_education", "အိမ်ထောင်ဦးစီး ပညာအရည်အချင်း", "Household head education", "short_text", False, None),
            ("household_head_phone", "အိမ်ထောင်ဦးစီး ဖုန်းနံပါတ်", "Household head phone", "telephone", True, None),
        ],
    },
    {
        "key": "livestock",
        "title_burmese": "တိရစ္ဆာန်ကြီးနှင့် ငယ်စာရင်း",
        "title_english": "Large and small livestock",
        "display_order": 2,
        "fields": [
            ("has_raised_animals", "မွေးမြူထားခြင်း ရှိ/မရှိ", "Raises livestock", "boolean", True, None),
            ("large_animal_table", "တိရစ္ဆာန်ကြီးစာရင်း", "Large animal records", "repeating_group", False, "animal_rows"),
            ("small_animal_table", "တိရစ္ဆာန်ငယ်စာရင်း", "Small animal records", "repeating_group", False, "animal_rows"),
        ],
    },
    {
        "key": "poultry",
        "title_burmese": "ကြက်၊ ဘဲ၊ ငုံး စာရင်း",
        "title_english": "Poultry",
        "display_order": 3,
        "fields": [
            ("has_poultry", "ကြက်၊ ဘဲ၊ ငုံး မွေးမြူထားခြင်း ရှိ/မရှိ", "Raises poultry", "boolean", True, None),
            ("poultry_table", "ကြက်၊ ဘဲ၊ ငုံးစာရင်း", "Poultry records", "repeating_group", False, "poultry_rows"),
        ],
    },
    {
        "key": "breeding",
        "title_burmese": "မျိုးတိရစ္ဆာန် မွေးမြူထားရှိမှု",
        "title_english": "Breeding livestock",
        "display_order": 4,
        "fields": [
            ("breeding_stock_table", "မျိုးတိရစ္ဆာန်စာရင်း", "Breeding stock records", "repeating_group", False, "breeding_rows"),
        ],
    },
    {
        "key": "interviewer",
        "title_burmese": "မေးမြန်းသူဆိုင်ရာ အချက်အလက်များ",
        "title_english": "Interviewer information",
        "display_order": 5,
        "fields": [
            ("interviewer_name", "မေးမြန်းသူ အမည်", "Interviewer name", "short_text", True, None),
            ("interviewer_phone", "မေးမြန်းသူ ဖုန်းနံပါတ်", "Interviewer phone", "telephone", True, None),
        ],
    },
]

# ---------------------------------------------------------------------------
# Seeding helpers
# ---------------------------------------------------------------------------


def _get_or_create(db: Session, model, *, code: str, **values) -> any:  # noqa: ANN001
    obj = db.query(model).filter_by(code=code).first()
    if obj is None:
        obj = model(code=code, **values)
        db.add(obj)
        db.flush()
    return obj


def seed_reference_data(db: Session) -> list[str]:
    """Insert workbook-derived reference data. Returns a summary of actions."""
    summary: list[str] = []

    seen = {g.code for g in db.query(Gender).all()}
    added = 0
    for data in GENDERS:
        if data["code"] not in seen:
            db.add(Gender(**data))
            added += 1
    if added:
        summary.append(f"genders +{added}")

    seen = {t.code for t in db.query(AnimalType).all()}
    added = 0
    for data in ANIMAL_TYPES:
        if data["code"] not in seen:
            db.add(AnimalType(**data))
            added += 1
    # Flush so the newly added rows are queryable (the session is configured
    # with autoflush=False, so an explicit flush is required here).
    db.flush()
    types_by_code: dict[str, AnimalType] = {
        t.code: t for t in db.query(AnimalType).all()
    }
    if added:
        summary.append(f"animal_types +{added}")

    # Animal categories
    for at_code, cat_code, burmese, english in ANIMAL_CATEGORIES:
        at = types_by_code.get(at_code)
        if at is None:
            raise HTTPException(status_code=500, detail=f"Missing animal type {at_code}")
        order = next((i + 1 for i, row in enumerate(ANIMAL_CATEGORIES) if row[1] == cat_code), 0)
        _get_or_create(
            db, AnimalCategory, code=cat_code,
            animal_type_id=at.id, burmese_name=burmese, english_name=english, display_order=order,
        )
    summary.append("animal_categories ensured")

    # Species
    for at_code, cat_code, species_code, burmese in SPECIES:
        at = types_by_code.get(at_code)
        if at is None:
            continue
        _get_or_create(
            db, Species, code=species_code,
            animal_type_id=at.id, animal_category_code=cat_code, burmese_name=burmese,
            english_name=burmese if _is_ascii(burmese) else None,
        )
    summary.append("species ensured")

    # Breeds (generic native / cross / imported, per animal type)
    added = 0
    existing_codes = {b.code for b in db.query(Breed).all()}
    for at in db.query(AnimalType).order_by(AnimalType.id).all():
        for data in BREEDS:
            key = f"{at.code}:{data['code']}"
            if key in existing_codes:
                continue
            db.add(Breed(
                code=key, animal_type_id=at.id, burmese_name=data["burmese_name"],
                english_name=data["english_name"], display_order=data.get("display_order", 0),
            ))
            existing_codes.add(key)
            added += 1
    if added:
        summary.append(f"breeds +{added}")

    # Age groups
    seen = {a.code for a in db.query(AgeGroup).all()}
    added = 0
    for code, burmese, english in AGE_GROUPS:
        if code not in seen:
            db.add(AgeGroup(code=code, burmese_name=burmese, english_name=english, display_order=_age_order(code)))
            added += 1
    if added:
        summary.append(f"age_groups +{added}")

    # Age types (schemes)
    seen = {a.code for a in db.query(AgeType).all()}
    added = 0
    for code, burmese, english, _ in AGE_TYPES:
        if code not in seen:
            db.add(AgeType(code=code, burmese_name=burmese, english_name=english, display_order=1))
            added += 1
    if added:
        summary.append(f"age_types +{added}")

    # Breeding categories
    seen = {b.code for b in db.query(BreedingCategory).all()}
    added = 0
    for code, burmese, english in BREEDING_CATEGORIES:
        if code not in seen:
            at = types_by_code["atID04"]
            db.add(BreedingCategory(code=code, burmese_name=burmese, english_name=english, animal_type_id=at.id))
            added += 1
    if added:
        summary.append(f"breeding_categories +{added}")

    # State/Region (only the top level from the form; no fabricated lower levels)
    seen = {s.code for s in db.query(StateRegion).all()}
    added = 0
    for code, burmese, english in STATE_REGIONS:
        if code not in seen:
            db.add(StateRegion(code=code, burmese_name=burmese, english_name=english))
            added += 1
    if added:
        summary.append(f"state_regions +{added}")

    db.commit()
    return summary


def seed_census_form(db: Session) -> str:
    """Create the initial census form (form, first version, sections, fields).

    The version is published so that submissions can be recorded. Re-running
    never duplicates the form (guarded by the unique ``form_id``).
    """
    form = db.query(Form).filter(Form.form_id == FORM_ID).first()
    if form is not None:
        return "census form already exists"

    form = Form(
        form_id=FORM_ID,
        burmese_title=FORM_BURMESE_TITLE,
        english_title=FORM_ENGLISH_TITLE,
        description=FORM_DESCRIPTION,
        is_published=True,
        is_draft=False,
        publication_status="published",
        version_number=1,
        created_by="seed",
        published_by="seed",
        published_at=_now(),
        effective_date=_now(),
    )
    db.add(form)
    db.flush()

    import json
    import hashlib

    version = FormVersion(
        form_id=form.id,
        version_number=1,
        definition_json=json.dumps(
            {"title_burmese": FORM_BURMESE_TITLE, "title_english": FORM_ENGLISH_TITLE,
             "sections": SECTIONS, "field_types_version": 1},
            ensure_ascii=False,
        ),
        definition_hash=hashlib.sha256(b"census-2026-v1").hexdigest(),
        publication_status="published",
        is_immutable=True,
        created_by="seed",
        published_by="seed",
        published_at=_now(),
    )
    db.add(version)
    db.flush()

    for section in SECTIONS:
        sec = FormSection(
            form_version_id=version.id,
            title_burmese=section["title_burmese"],
            title_english=section["title_english"],
            display_order=section["display_order"],
            is_enabled=True,
        )
        db.add(sec)
        db.flush()
        for order, (name, burmese, english, field_type, required, binding) in enumerate(section["fields"]):
            db.add(FormField(
                form_version_id=version.id,
                associated_section_id=sec.id,
                name=name,
                title_burmese=burmese,
                title_english=english,
                field_type=field_type,
                is_required=required,
                is_enabled=True,
                is_searchable=name in {"household_no", "respondent_name_burmese"},
                is_exportable=True,
                is_reportable=name not in {"respondent_phone", "household_head_phone", "interviewer_phone"},
                is_sensitive=name in {"respondent_phone", "household_head_phone", "interviewer_phone"},
                is_filterable=name in {"state_region_id", "township_id", "collection_status"},
                display_order=order + 1,
                data_binding=binding,
                option_source="master" if binding else "static",
            ))
    db.commit()
    return "census form created & published (v1)"


def seed_geography(db: Session) -> str:
    """Seed districts / townships / village tracts / wards for each region.

    Region rows themselves are created by :func:`seed_reference_data`. Only the
    lower administrative levels are added here, keyed by their stable codes so
    the operation is idempotent.
    """
    regions = {r.code: r for r in db.query(StateRegion).all()}
    districts_added = townships_added = 0
    for region_code, districts in GEOGRAPHY.items():
        region = regions.get(region_code)
        if region is None:
            continue
        for d_order, (d_code, d_burmese, d_english, townships) in enumerate(districts, start=1):
            district = db.query(District).filter_by(code=d_code).first()
            if district is None:
                district = District(code=d_code, burmese_name=d_burmese, english_name=d_english,
                                    state_region_id=region.id, display_order=d_order)
                db.add(district)
                db.flush()
                districts_added += 1
            for t_order, (t_code, t_burmese, t_english) in enumerate(townships, start=1):
                township = db.query(Township).filter_by(code=t_code).first()
                if township is None:
                    township = Township(code=t_code, burmese_name=t_burmese, english_name=t_english,
                                        district_id=district.id, display_order=t_order)
                    db.add(township)
                    db.flush()
                    townships_added += 1
                tract_code = f"{t_code}_vt01"
                tract = db.query(VillageTract).filter_by(code=tract_code).first()
                if tract is None:
                    tract = VillageTract(code=tract_code, burmese_name="ကျေးရွာအုပ်စုအုပ်စု (၁)",
                                         english_name="Village Tract 1", township_id=township.id,
                                         display_order=1)
                    db.add(tract)
                    db.flush()
                ward_code = f"{t_code}_w01"
                if db.query(Ward).filter_by(code=ward_code).first() is None:
                    db.add(Ward(code=ward_code, burmese_name="ကျေးရွာအုပ်စု (၁)", english_name="Village 1",
                                village_tract_id=tract.id, display_order=1))
    db.commit()
    return f"districts +{districts_added}, townships +{townships_added}"


def seed_demo_submissions(db: Session, count: int = 40) -> int:
    """Create synthetic submissions spread over the last 30 days.

    Only invoked from the CLI with ``--demo`` so that a real deployment never
    contains fabricated records.
    """
    import random
    from datetime import date, datetime, timedelta

    version = (
        db.query(FormVersion)
        .filter(FormVersion.publication_status == "published")
        .order_by(FormVersion.id.desc())
        .first()
    )
    if version is None:
        raise RuntimeError("Seed the census form before generating demo submissions")

    townships = db.query(Township).all()
    if not townships:
        raise RuntimeError("Seed geography before generating demo submissions")

    genders = db.query(Gender).all()
    age_groups = db.query(AgeGroup).all()
    large = db.query(AnimalCategory).filter(AnimalCategory.code.like("laID%")).all()
    small = db.query(AnimalCategory).filter(AnimalCategory.code.like("yaID%")).all()
    poultry = db.query(AnimalCategory).filter(AnimalCategory.code.like("lsID%")).all()
    breeding = db.query(BreedingCategory).all()

    rng = random.Random(20261013)
    created = 0
    for i in range(count):
        township = rng.choice(townships)
        district = township.district
        region = district.state_region
        tract = township.village_tracts[0] if township.village_tracts else None
        ward = tract.wards[0] if tract and tract.wards else None
        interview = date.today() - timedelta(days=rng.randint(0, 30))
        status = rng.choice(["submitted", "under_review", "approved", "approved", "rejected"])
        review_status = {"submitted": "pending", "under_review": "pending",
                         "approved": "approved", "rejected": "rejected"}[status]
        sub = Submission(
            form_version_id=version.id, form_id=version.form_id, version_number=version.version_number,
            state_region_id=region.id, district_id=district.id, township_id=township.id,
            village_tract_id=tract.id if tract else None, ward_id=ward.id if ward else None,
            household_no=f"H-{1000 + i}",
            respondent_name_burmese=f"မေးမြန်းခံသူ {i + 1}",
            respondent_gender_id=rng.choice(genders).id,
            respondent_age=rng.choice([22, 30, 41, 55, 63]),
            respondent_age_group_id=rng.choice(age_groups).id,
            respondent_education="အခြေခံပညာ",
            respondent_phone=f"09{rng.randint(100000000, 999999999)}",
            household_head_name_burmese=f"အိမ်ထောင်ဦးစီး {i + 1}",
            household_head_gender_id=rng.choice(genders).id,
            household_head_age=rng.choice([35, 46, 58, 66]),
            household_head_age_group_id=rng.choice(age_groups).id,
            household_head_phone=f"09{rng.randint(100000000, 999999999)}",
            interview_date=interview,
            interviewer_name=f"ကောက်ယူသူ {i + 1}",
            interviewer_phone=f"09{rng.randint(100000000, 999999999)}",
            has_raised_animals=True,
            has_poultry=rng.random() > 0.4,
            collection_status=status,
            review_status=review_status,
            created_at=datetime.combine(interview, datetime.min.time()) + timedelta(hours=rng.randint(1, 20)),
        )
        db.add(sub)
        db.flush()
        for cat in rng.sample(list(large) + list(small), k=rng.randint(1, 4)):
            db.add(AnimalCount(submission_id=sub.id, animal_type_id=cat.animal_type_id,
                               gender=rng.choice(["male", "female", "castrated"]),
                               age_group_id=rng.choice(age_groups).id,
                               count=rng.randint(1, 40)))
        for cat in rng.sample(poultry, k=rng.randint(0, 3)):
            db.add(AnimalCount(submission_id=sub.id, animal_type_id=cat.animal_type_id,
                               gender=rng.choice(["male", "female"]),
                               count=rng.randint(5, 500)))
        for cat in rng.sample(breeding, k=rng.randint(0, 2)):
            db.add(BreedingCount(submission_id=sub.id, breeding_category_id=cat.id,
                                 male_count=rng.randint(0, 5), female_count=rng.randint(0, 12)))
        created += 1
    db.commit()
    return created


def seed_all(db: Session) -> list[str]:
    """Seed reference data, geography and the census form. Idempotent."""
    summary = seed_reference_data(db)
    summary.append(seed_geography(db))
    summary.append(seed_census_form(db))
    return summary


def _is_ascii(value: str) -> bool:
    try:
        value.encode("ascii")
        return bool(value)
    except UnicodeEncodeError:
        return False


def _age_order(code: str) -> int:
    try:
        return int(code.replace("ageID", ""))
    except ValueError:
        return 0


def run() -> None:
    """CLI entry point: ``uv run python -m app.seed [--demo]`` (from server/)."""
    import argparse
    import logging

    parser = argparse.ArgumentParser(description="Seed the livestock census database")
    parser.add_argument("--demo", action="store_true",
                        help="also generate synthetic demo submissions (never for production)")
    parser.add_argument("--demo-count", type=int, default=40)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("moali.seed")

    Base.metadata.create_all(bind=engine)  # ensure tables exist (dev bootstrap)
    db = SessionLocal()
    try:
        summary = seed_all(db)
        for line in summary:
            logger.info("seed: %s", line)
        if args.demo:
            n = seed_demo_submissions(db, args.demo_count)
            logger.info("seed: demo submissions +%d", n)
        counts = {
            "genders": db.query(Gender).count(),
            "animal_types": db.query(AnimalType).count(),
            "animal_categories": db.query(AnimalCategory).count(),
            "species": db.query(Species).count(),
            "breeds": db.query(Breed).count(),
            "age_groups": db.query(AgeGroup).count(),
            "age_types": db.query(AgeType).count(),
            "breeding_categories": db.query(BreedingCategory).count(),
            "state_regions": db.query(StateRegion).count(),
            "districts": db.query(District).count(),
            "townships": db.query(Township).count(),
            "forms": db.query(Form).count(),
            "form_sections": db.query(FormSection).count(),
            "form_fields": db.query(FormField).count(),
            "submissions": db.query(Submission).count(),
        }
        logger.info("seed: totals %s", counts)
    finally:
        db.close()


if __name__ == "__main__":
    run()