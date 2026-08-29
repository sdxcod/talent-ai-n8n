# TalentAI n8n — Phase 1

TalentAI Phase 1 یک خط پردازش قابل ممیزی برای تحلیل رزومه و ارزیابی سطح فنی کاندید است. این فاز رزومه را به پروفایل ساخت‌یافته تبدیل می‌کند، راهنمای امتیازدهی نسخه‌بندی‌شده را بارگذاری می‌کند، شواهد رزومه را با LLM امتیاز می‌دهد و تصمیم نهایی را با قواعد قطعی در PostgreSQL ثبت می‌کند.

این Repository فقط منابع قابل‌اشتراک پروژه را نگه می‌دارد. Credentialها، کلیدهای API، فایل‌های رزومه، داده‌های اجرای n8n، خروجی خام Package و اطلاعات محلی در Git قرار نمی‌گیرند.

## وضعیت فاز اول

فاز اول شامل سه Workflow وابسته است:

| Workflow | مسئولیت |
| --- | --- |
| `TAI-01 Resume Intake & Extraction v2` | دریافت رزومه، استخراج متن، تولید و اعتبارسنجی پروفایل کاندید، ذخیره Extraction و هماهنگ‌کردن مراحل بعدی |
| `TAI-02 Grade Guide Resolver v1` | دریافت `extractionId`، بازیابی Extraction و Grade Guide فعال و ساخت ورودی استاندارد Grade Engine |
| `TAI-03 Evidence Scoring & Deterministic Grade Engine v1` | امتیازدهی مبتنی بر شواهد، اجرای قواعد قطعی، ذخیره Assessment و تولید خروجی نهایی |

جریان کلی:

```text
Resume PDF
  -> TAI-01: extraction and profile persistence
  -> TAI-02: extraction and grade-guide resolution
  -> TAI-03: evidence scoring and deterministic decision
  -> talentai.grade_assessment
```

LLM فقط برای استخراج اطلاعات و امتیازدهی شواهد استفاده می‌شود. محاسبه امتیاز نهایی، کنترل حداقل امتیاز و بررسی حداقل سطح Dimensionهای اجباری توسط منطق قطعی انجام می‌شود.

## فناوری‌ها و نسخه‌های آزموده‌شده

| ابزار | نسخه آزموده‌شده |
| --- | --- |
| n8n | `2.36.8` |
| PostgreSQL | `18.6` |
| Docker Engine | `28.3.2` |
| Docker Compose | `2.39.1` |
| Node.js | `25.2.1` |
| npm | `11.6.2` |
| `@n8n/cli` | `0.16.0` |

نسخه‌های n8n و PostgreSQL در `.env` ثابت می‌شوند تا اعضای تیم محیط قابل تکراری داشته باشند. ارتقای نسخه‌ها باید آگاهانه، در یک تغییر مستقل و پس از تهیه پشتیبان انجام شود.

## پیش‌نیازها

برای اجرای محلی نیاز است:

- Docker Desktop یا Docker Engine به‌همراه Docker Compose؛
- `curl`؛
- `jq`؛
- `ripgrep` با فرمان `rg`؛
- `openssl`؛
- `tar`؛
- دسترسی به یک OpenAI API Credential سازگار با Modelهای Workflow.

Node.js، npm و `@n8n/cli` فقط برای Export یا Import کردن n8n Package لازم‌اند و برای اجرای عادی Stack الزامی نیستند.

بررسی ابزارها:

```bash
docker --version
docker compose version
curl --version
jq --version
rg --version
openssl version
tar --version
```

برای نصب CLI مربوط به Packageهای n8n:

```bash
npm install -g @n8n/cli
n8n-cli --version
```

## ساختار Repository

```text
.
├── .env.example
├── .gitignore
├── README.md
├── docker-compose.yml
├── docker-compose.override.yml
├── init-data.sh
├── database
│   ├── migrations
│   │   ├── V001__create_resume_extraction.sql
│   │   ├── V002__create_grade_guide.sql
│   │   └── V003__create_grade_assessment.sql
│   ├── queries
│   │   ├── Q001__select_active_grade_guide.sql
│   │   ├── Q002__resolve_grade_engine_input.sql
│   │   └── Q003__persist_grade_assessment.sql
│   └── seeds
│       └── R001__seed_java_backend_grade_guide_v1.sql
├── prompts
│   └── evidence-scoring-v1.md
├── schemas
│   └── grade-evidence-scoring-v1.schema.json
├── scripts
│   ├── apply-database.sh
│   ├── create-local-env.sh
│   ├── export-phase1-workflows.sh
│   └── verify-phase1.sh
└── workflows
    └── phase-1
        ├── TAI-01-resume-intake-extraction-v2.json
        ├── TAI-02-grade-guide-resolver-v1.json
        ├── TAI-03-evidence-scoring-grade-engine-v1.json
        └── manifest.json
```

## پورت‌ها، Databaseها و Roleها

| کاربرد | مقدار محلی |
| --- | --- |
| n8n Editor | `http://127.0.0.1:5678` |
| n8n health endpoint | `http://127.0.0.1:5678/healthz` |
| PostgreSQL از سیستم میزبان | `127.0.0.1:5434` |
| PostgreSQL از شبکه Docker | `postgres:5432` |
| n8n metadata database | `n8n` |
| TalentAI application database | `talentai` |
| PostgreSQL administrator | `admin` |
| n8n runtime role | `n8n_app` |
| TalentAI runtime role | `talentai_app` |
| TalentAI schema | `talentai` |

PostgreSQL فقط روی `127.0.0.1` منتشر شده و از شبکه عمومی قابل دسترسی نیست.

## راه‌اندازی برای اولین بار

### ۱. دریافت Repository

```bash
git clone https://github.com/sdxcod/talent-ai-n8n.git
cd talent-ai-n8n
```

### ۲. ایجاد `.env` محلی

فقط در یک نصب کاملاً جدید اجرا کنید:

```bash
chmod +x init-data.sh scripts/*.sh
./scripts/create-local-env.sh
```

این اسکریپت رمزهای تصادفی و مستقل تولید می‌کند، آن‌ها را چاپ نمی‌کند و فایل `.env` را با Permission برابر `600` می‌سازد.

بررسی نام متغیرها بدون نمایش مقدارها:

```bash
awk -F= '
  /^[A-Za-z_][A-Za-z0-9_]*=/ {
    print $1
  }
' .env | sort
```

متغیرهای مورد انتظار:

```text
GENERIC_TIMEZONE
N8N_ENCRYPTION_KEY
N8N_HOST_PORT
N8N_VERSION
POSTGRES_DB
POSTGRES_HOST_PORT
POSTGRES_NON_ROOT_PASSWORD
POSTGRES_NON_ROOT_USER
POSTGRES_PASSWORD
POSTGRES_USER
POSTGRES_VERSION
RUNNERS_AUTH_TOKEN
TALENTAI_DB_PASSWORD
```

فایل `.env` را commit، ارسال یا در پیام‌ها Paste نکنید.

### ۳. اعتبارسنجی Compose

```bash
docker compose config --quiet
docker compose config --images
```

Imageهای مورد انتظار:

```text
docker.n8n.io/n8nio/n8n:2.36.8
n8nio/runners:2.36.8
postgres:18.6
```

### ۴. دریافت Imageها و اجرای Stack

```bash
docker compose pull
docker compose up -d
docker compose ps
```

منتظر آماده‌شدن n8n بمانید:

```bash
TALENTAI_N8N_HEALTHY=false

for attempt in {1..30}; do
  if curl -fsS http://127.0.0.1:5678/healthz; then
    echo
    TALENTAI_N8N_HEALTHY=true
    break
  fi

  sleep 2
done

if [ "$TALENTAI_N8N_HEALTHY" != true ]; then
  echo 'n8n did not become healthy in 60 seconds.' >&2
  unset TALENTAI_N8N_HEALTHY
  false
fi

unset TALENTAI_N8N_HEALTHY
```

خروجی سالم:

```json
{"status":"ok"}
```

بررسی نسخه و PostgreSQL:

```bash
docker compose exec -T n8n n8n --version

docker compose exec -T postgres sh -c '
  pg_isready -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB"
'
```

### ۵. عملکرد اولین راه‌اندازی PostgreSQL

`init-data.sh` فقط هنگام ایجاد اولیه Volume دیتابیس اجرا می‌شود و این کارها را انجام می‌دهد:

1. ایجاد Role محدود `n8n_app`؛
2. ایجاد Database مستقل `talentai`؛
3. ایجاد Role محدود `talentai_app`؛
4. اجرای تمام فایل‌های `database/migrations`؛
5. اجرای Seedهای idempotent موجود در `database/seeds`.

Volumeهای زیر داده‌ها را بین Recreate کانتینرها نگه می‌دارند:

```text
db_storage
n8n_storage
```

از `docker compose down -v` استفاده نکنید، مگر اینکه حذف کامل و آگاهانه همه داده‌های محلی هدف شما باشد.

### ۶. بررسی خودکار نصب

```bash
./scripts/verify-phase1.sh
```

خروجی نهایی مطلوب:

```text
TalentAI Phase 1 repository and runtime verification passed.
```

## ارتقای یک محیط موجود

در محیطی که قبلاً n8n و Credential دارد، `create-local-env.sh` را اجرا نکنید.

### حفظ کلید رمزنگاری

`N8N_ENCRYPTION_KEY` باید دقیقاً همان کلیدی باشد که Credentialهای فعلی n8n با آن رمزنگاری شده‌اند. جایگزین‌کردن یا تولید دوباره این مقدار باعث ناخواناشدن Credentialهای موجود می‌شود.

قبل از Recreate کانتینرها بررسی کنید که متغیر در `.env` وجود دارد، اما مقدار آن را چاپ نکنید:

```bash
grep -q '^N8N_ENCRYPTION_KEY=' .env \
  && echo 'N8N_ENCRYPTION_KEY is configured.'
```

### اعمال Migration و Seed روی Volume موجود

Init Script روی Volume موجود دوباره اجرا نمی‌شود. برای اعمال تغییرات Repository اجرا کنید:

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

Migrationها و Seedهای فعلی idempotent هستند و اجرای مجدد آن‌ها نباید رکورد Grade Guide تکراری ایجاد کند.

### Recreate امن سرویس‌ها

```bash
docker compose config --quiet
docker compose up -d --force-recreate
docker compose ps
curl -fsS http://127.0.0.1:5678/healthz
```

این عملیات Volumeها را حذف نمی‌کند.

## ورود اولیه به n8n

مرورگر را باز کنید:

```text
http://127.0.0.1:5678
```

در نصب جدید، Owner محلی n8n را ایجاد کنید. اطلاعات این حساب در Volume n8n ذخیره می‌شود و نباید در Repository قرار گیرد.

## Credentialهای موردنیاز n8n

Workflowها بدون Credential Reference commit می‌شوند. هر عضو تیم باید Credentialهای محیط خودش را در n8n ایجاد و به Nodeهای مربوط متصل کند.

### Credential مربوط به TalentAI PostgreSQL

| Field | Value |
| --- | --- |
| Host | `postgres` |
| Port | `5432` |
| Database | `talentai` |
| User | `talentai_app` |
| Password | مقدار محلی `TALENTAI_DB_PASSWORD` |
| SSL | Disabled در شبکه محلی Docker |

از `127.0.0.1:5434` داخل Nodeهای n8n استفاده نکنید؛ n8n باید از نام Service یعنی `postgres:5432` استفاده کند.

### OpenAI API Credential

یک Credential از نوع `openAiApi` در n8n بسازید و API Key محیط خودتان را فقط در بخش Credentials وارد کنید.

API Key نباید در این مکان‌ها قرار گیرد:

- Workflow JSON؛
- `.env.example`؛
- Prompt؛
- Git history؛
- Screenshot یا پیام تیمی.

پس از Import، Credential را به تمام Nodeهای PostgreSQL و Model مربوط به TAI-01 و TAI-03 اختصاص دهید.

## Import کردن Workflowها در محیط جدید

سه Workflow باید داخل Folder زیر قرار گیرند:

```text
TalentAI - Phase 1
```

فایل‌های Commit‌شده در حالت غیرفعال‌اند و Credential Reference یا Pin Data ندارند.

برای Import دستی، این ترتیب را رعایت کنید:

1. `TAI-02-grade-guide-resolver-v1.json`؛
2. `TAI-03-evidence-scoring-grade-engine-v1.json`؛
3. `TAI-01-resume-intake-extraction-v2.json`.

پس از Import:

1. هر سه Workflow را به Folder `TalentAI - Phase 1` منتقل کنید؛
2. Credentialهای PostgreSQL و OpenAI را انتخاب کنید؛
3. در TAI-01، Nodeهای فراخوانی Sub-workflow را باز کنید؛
4. بررسی کنید که Resolver به TAI-02 و Grade Engine به TAI-03 اشاره می‌کنند؛
5. Workflowها را Save کنید؛
6. ابتدا یک اجرای دستی End-to-End انجام دهید؛
7. فقط پس از موفقیت تست، Entry Workflow را برای استفاده موردنظر Publish یا Activate کنید.

برای انتقال تیمی، n8n Package ترجیح داده می‌شود؛ Package می‌تواند Folder و وابستگی Sub-workflowها را همراه هم منتقل و Referenceها را هنگام Import تطبیق دهد. فایل Package خام محلی در `exports/private` نگه‌داری می‌شود و نباید مستقیماً commit شود.

نمونه Import یک Package بررسی‌شده:

```bash
n8n-cli login

n8n-cli package import \
  --file=TalentAI-phase-1-v1.0.0.n8np \
  --workflow-conflict-policy=fail
```

در ورود تعاملی، URL محیط مانند `http://127.0.0.1:5678` و API Key ساخته‌شده در `Settings -> n8n API` را وارد کنید. تنظیمات CLI خارج از Repository و با Permission محدود ذخیره می‌شوند. API Key را داخل README، Script یا Command History قرار ندهید.

قبل از Import در محیط مشترک، حتماً Manifest، تعداد Workflowها و Credential Requirementهای Package را بررسی کنید.

## اجرای تست End-to-End

برای تست کامل، از یک رزومه غیرحساس یا نمونه ساختگی استفاده کنید. فایل‌های رزومه را زیر `samples/private` نگه دارید تا توسط Git نادیده گرفته شوند.

TAI-01 را با ورودی‌هایی مشابه زیر اجرا کنید:

| Field | Example |
| --- | --- |
| Resume | یک PDF تست غیرحساس |
| `positionCode` | `JAVA_BACKEND` |
| `targetGradeCode` | `SENIOR` |
| `jobDescription` | شرح شغل هم‌راستا با Position و Target Grade |

خروجی نهایی باید حداقل این فیلدها را داشته باشد:

```text
assessmentId
extractionId
candidateName
positionCode
targetGradeCode
overallScore
minimumRequiredScore
thresholdMet
mandatoryDimensionsMet
decision
gradeGuideVersion
scoringModel
createdAt
```

مقدار دقیق امتیاز Evidence Scoring ممکن است بین اجراها کمی تغییر کند، زیرا آن بخش توسط LLM تولید می‌شود. بعد از تولید Dimension Scoreها، محاسبه امتیاز وزنی، کنترل Threshold، حداقل Dimensionها و Decision قطعی است.

## بررسی نتیجه در PostgreSQL

آخرین Assessment:

```bash
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U admin -d talentai <<'SQL'
SELECT
    ga.id AS assessment_id,
    ga.extraction_id,
    re.profile -> 'candidate' ->> 'fullName' AS candidate_name,
    re.position_code,
    ga.target_grade_code,
    ga.overall_score,
    ga.minimum_overall_score,
    ga.threshold_met,
    ga.mandatory_dimensions_met,
    ga.decision,
    ga.grade_guide_version,
    ga.scoring_model,
    ga.prompt_version,
    ga.engine_version,
    ga.status,
    ga.created_at
FROM talentai.grade_assessment AS ga
JOIN talentai.resume_extraction AS re
  ON re.id = ga.extraction_id
ORDER BY ga.created_at DESC
LIMIT 1;
SQL
```

بررسی Grade Guide فعال:

```bash
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U talentai_app -d talentai \
  < database/queries/Q001__select_active_grade_guide.sql
```

بررسی جدول‌ها:

```bash
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U admin -d talentai <<'SQL'
SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'talentai'
ORDER BY table_name;
SQL
```

## اتصال IntelliJ IDEA به PostgreSQL

در Database Tool Window یک PostgreSQL Data Source بسازید:

| Field | Value |
| --- | --- |
| Name | `TalentAI n8n Local` |
| Host | `127.0.0.1` |
| Port | `5434` |
| Database | `talentai` |
| User | `talentai_app` یا برای مدیریت محلی `admin` |
| Password | رمز متناظر در `.env` |
| SSL | Disabled |
| JDBC URL | `jdbc:postgresql://127.0.0.1:5434/talentai` |

در بخش Schemas، Schema با نام `talentai` را برای Introspection انتخاب و Data Source را Synchronize کنید.

مسیر مورد انتظار:

```text
TalentAI n8n Local
  -> talentai database
    -> talentai schema
      -> Tables
        -> resume_extraction
        -> grade_guide
        -> grade_assessment
```

## مسئولیت جدول‌ها

| Table | مسئولیت |
| --- | --- |
| `talentai.resume_extraction` | پروفایل ساخت‌یافته استخراج‌شده، اطلاعات منبع، Model و Schema Version |
| `talentai.grade_guide` | Grade Guide نسخه‌بندی‌شده، Dimensionها، Weightها و Decision Policy |
| `talentai.grade_assessment` | Dimension Assessmentها، امتیاز نهایی، نتیجه قواعد قطعی و اطلاعات Audit |

داده‌های Runtime داخل Volume PostgreSQL قرار دارند و جزئی از commit نیستند. Git فقط Migration، Seed و Queryهای قابل‌بازتولید را نگه می‌دارد.

## Export کردن Sourceهای Workflow

Folder موجود در n8n باید دقیقاً شامل سه Workflow تیمی فاز اول باشد و Workflow تست یا Backup داخل آن قرار نگیرد.

```text
TalentAI - Phase 1
├── TAI-01 Resume Intake & Extraction v2
├── TAI-02 Grade Guide Resolver v1
└── TAI-03 Evidence Scoring & Deterministic Grade Engine v1
```

Folder ID را از محیط n8n دریافت و اجرا کنید:

```bash
export TALENTAI_PHASE1_FOLDER_ID='<folder-id>'
./scripts/export-phase1-workflows.sh 1.0.0
```

اسکریپت این کنترل‌ها را انجام می‌دهد:

- Folder دقیقاً سه Workflow مورد انتظار داشته باشد؛
- Dependencyهای TAI-01 به TAI-02 و TAI-03 موجود باشند؛
- Variable خصوصی داخل Package نباشد؛
- Credential Reference حذف شود؛
- Pin Data و Static Data حذف شوند؛
- Workflowهای Commit‌شده غیرفعال باشند؛
- نودهای تست یا منسوخ وارد Source نشوند؛
- الگوهای رایج Secret در خروجی مشاهده نشود.

خروجی‌ها:

| مسیر | وضعیت Git |
| --- | --- |
| `exports/private/TalentAI-phase-1-v*.raw.n8np` | خصوصی و ignored |
| `workflows/phase-1/TAI-*.json` | Source پاک‌سازی‌شده و قابل commit |
| `workflows/phase-1/manifest.json` | Manifest قابل commit |

بعد از Export اجرا کنید:

```bash
./scripts/verify-phase1.sh
```

## تست‌های قبل از Commit

```bash
docker compose config --quiet
./scripts/apply-database.sh
./scripts/verify-phase1.sh
git status --short --branch
```

فایل‌های Workflow قابل commit باید دقیقاً این موارد باشند:

```text
workflows/phase-1/TAI-01-resume-intake-extraction-v2.json
workflows/phase-1/TAI-02-grade-guide-resolver-v1.json
workflows/phase-1/TAI-03-evidence-scoring-grade-engine-v1.json
workflows/phase-1/manifest.json
```

کنترل فایل‌های حساس:

```bash
git check-ignore -v .env
git check-ignore -v exports/private/TalentAI-phase-1-v1.0.0.raw.n8np
```

هیچ‌کدام از موارد زیر نباید Stage یا Commit شوند:

- `.env`؛
- API Key، Password، Token و Authorization Header؛
- فایل رزومه و اطلاعات خصوصی کاندید؛
- `exports/private`؛
- Pin Data و Execution Sample؛
- Volume یا Backup دیتابیس؛
- `.DS_Store` و فایل‌های IDE.

## عیب‌یابی

### `curl: (52) Empty reply from server`

n8n هنوز در حال Start یا اجرای Migrationهای داخلی است. وضعیت و Log را بررسی کنید:

```bash
docker compose ps
docker compose logs --tail=150 n8n n8n-runner postgres
```

سپس Health Check را تکرار کنید.

### Credential بعد از Recreate قابل خواندن نیست

معمولاً `N8N_ENCRYPTION_KEY` تغییر کرده یا به کانتینر ارسال نشده است. کانتینر را با کلید جدید اجرا نکنید و Credential را دوباره Save نکنید. ابتدا مقدار صحیح کلید محیط قبلی را بازیابی کنید.

### `INVALID_EXTRACTION_ID` یا `extractionId must be a valid UUID`

TAI-02 یک Sub-workflow است و باید از TAI-01 یک `extractionId` واقعی دریافت کند. اجرای مستقیم Trigger آن بدون ورودی معتبر خطا محسوب می‌شود و نشان‌دهنده خرابی Resolver نیست.

برای دریافت آخرین Extraction ID:

```bash
docker compose exec -T postgres \
  psql -U admin -d talentai <<'SQL'
SELECT
    id,
    position_code,
    target_grade_code,
    created_at
FROM talentai.resume_extraction
ORDER BY created_at DESC
LIMIT 5;
SQL
```

`grade_guide.id` را به‌جای `resume_extraction.id` استفاده نکنید.

### Resolver مقدار `RESOLVED` دارد اما IF به مسیر False می‌رود

Condition باید مقدار String زیر را بررسی کند:

```text
{{$json.resolutionStatus}} equals RESOLVED
```

اگر خروجی به ساختار نهایی Grade Engine تبدیل شده است، مسیر صحیح ممکن است این باشد:

```text
{{$json.resolution.status}} equals RESOLVED
```

Expression را با ساختار واقعی ورودی همان Node تطبیق دهید و از مقایسه Boolean با String خودداری کنید.

### `zsh: parse error near ')'`

SQL را مستقیماً در Shell اجرا نکنید. آن را با `psql` و Heredoc اجرا کنید:

```bash
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U admin -d talentai <<'SQL'
SELECT current_database(), current_user;
SQL
```

قرارگرفتن `'SQL'` داخل Quote باعث می‌شود Shell محتوای SQL را تفسیر نکند.

### `cannot get array length of a scalar`

ممکن است یک رکورد قدیمی فیلد JSON را به‌صورت String ذخیره کرده باشد. قبل از `jsonb_array_length` نوع را کنترل کنید:

```sql
CASE
  WHEN jsonb_typeof(profile -> 'skills') = 'array'
  THEN jsonb_array_length(profile -> 'skills')
  ELSE NULL
END
```

### جدول‌ها در IntelliJ نمایش داده نمی‌شوند

بررسی کنید:

1. Database اتصال `talentai` باشد؛
2. Schema با نام `talentai` برای Introspection انتخاب شده باشد؛
3. Data Source را Synchronize یا Force Refresh کرده باشید؛
4. Object Filter جدول‌ها را مخفی نکرده باشد.

وجود واقعی جدول:

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'talentai';
```

### `role ... does not exist`

مقادیر `.env` فقط روی Initial Setup اثر خودکار دارند. Init Script روی Volume موجود دوباره اجرا نمی‌شود. نام Role را با این دستور بررسی کنید:

```bash
docker compose exec -T postgres \
  psql -U admin -d postgres \
  -c '\du'
```

Volume را برای حل این خطا بدون پشتیبان حذف نکنید.

### Port اشغال است

```bash
lsof -nP -iTCP:5678 -sTCP:LISTEN
lsof -nP -iTCP:5434 -sTCP:LISTEN
```

در صورت نیاز، `N8N_HOST_PORT` یا `POSTGRES_HOST_PORT` را فقط در `.env` محلی تغییر دهید.

## سیاست امنیت و حریم خصوصی

- برای تست از رزومه ساختگی یا داده مجاز استفاده کنید؛
- متن رزومه و پروفایل استخراج‌شده را در Log یا Issue عمومی قرار ندهید؛
- Credentialها فقط در n8n Credential Store نگه‌داری شوند؛
- PostgreSQL روی `127.0.0.1` باقی بماند؛
- Admin database role فقط برای Migration و عیب‌یابی محلی استفاده شود؛
- Workflowها در Runtime با `talentai_app` کار کنند؛
- کلید رمزنگاری n8n پایدار، محرمانه و خارج از Git باشد؛
- قبل از اشتراک Package، Manifest و محتویات آن بررسی شود.

## محدودیت‌های فاز اول

- اطلاعات رزومه ادعای کاندید است و اعتبار بیرونی آن بررسی نمی‌شود؛
- امتیاز Evidence Scoring ممکن است به‌علت رفتار LLM کمی تغییر کند؛
- Decision Engine فقط براساس Grade Guide و Dimension Scoreهای تولیدشده تصمیم می‌گیرد؛
- Grade Guide فعلی مربوط به `JAVA_BACKEND` و نسخه `1.0.0` است؛
- این فاز UI اختصاصی TalentAI ندارد و از Form و Editor مربوط به n8n استفاده می‌کند؛
- Production hardening، Backup policy، HTTPS، SSO، Queue scaling و Monitoring خارج از محدوده این فاز هستند.

## منابع رسمی

- [n8n Docker Compose deployment](https://docs.n8n.io/deploy/host-n8n/install-options/use-a-cloud-provider/use-docker-compose/)
- [n8n encryption key configuration](https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/configuration-examples/set-a-custom-encryption-key/)
- [n8n packages](https://docs.n8n.io/build/manage-workflows/n8n-packages/)
- [Export an n8n package](https://docs.n8n.io/build/manage-workflows/n8n-packages/export-a-package/)
- [Import an n8n package](https://docs.n8n.io/build/manage-workflows/n8n-packages/import-a-package/)
- [n8n CLI](https://docs.n8n.io/connect/n8n-cli/)
- [PostgreSQL JSON functions](https://www.postgresql.org/docs/current/functions-json.html)

## مجوز و مالکیت

این پروژه برای استفاده داخلی تیم TalentAI تهیه شده است. پیش از انتشار عمومی، سیاست مالکیت کد، مجوز استفاده، داده‌های نمونه و الزامات حریم خصوصی سازمان باید مشخص شوند.
