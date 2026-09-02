# TalentAI n8n

TalentAI یک سامانهٔ قابل ممیزی برای پشتیبانی از فرایند جذب و ارزیابی فنی
کاندیدهاست. این Repository زیرساخت داده، Workflowهای n8n، قراردادهای
نسخه‌بندی‌شده، آزمون‌ها و ابزارهای عملیاتی سامانه را نگه‌داری می‌کند و با
توسعهٔ قابلیت‌های بعدی پروژه تکامل می‌یابد.

این Repository فقط منابع قابل‌اشتراک پروژه را نگه می‌دارد. Credentialها، کلیدهای API، فایل‌های رزومه، داده‌های اجرای n8n، خروجی خام Package و اطلاعات محلی در Git قرار نمی‌گیرند.

## وضعیت فعلی پیاده‌سازی

مسیر عملیاتی موجود شامل چهار Workflow وابسته است:

| Workflow | مسئولیت |
| --- | --- |
| `TAI-01 Resume Intake & Extraction v2` | دریافت رزومه، استخراج متن، تولید و اعتبارسنجی پروفایل کاندید، ذخیره Extraction و هماهنگ‌کردن مراحل بعدی |
| `TAI-02 Grade Guide Resolver v1` | دریافت `extractionId`، بازیابی Extraction و Grade Guide فعال و ساخت ورودی استاندارد Grade Engine |
| `TAI-03 Evidence Scoring & Deterministic Grade Engine v1` | امتیازدهی مبتنی بر شواهد، اجرای قواعد قطعی، ذخیره Assessment و تولید خروجی نهایی |
| `TAI-04 Candidate Interview & Final Grade v1` | دریافت `extractionId` از فرم، خواندن پروفایل، Grade Guide و آخرین گرید رزومه، دو مرحله مصاحبه با فرم داینامیک (سوالات مرحله دوم از دل پاسخ‌های مرحله اول) و تعیین گرید نهایی کارجو |

جریان کلی:

```text
Resume PDF
  -> TAI-01: extraction and profile persistence
  -> TAI-02: extraction and grade-guide resolution
  -> TAI-03: evidence scoring and deterministic decision
  -> talentai.grade_assessment
  -> TAI-04: two-round candidate interview (dynamic forms) and final grade
```

LLM فقط برای استخراج اطلاعات، امتیازدهی شواهد، طراحی سوالات مصاحبه و امتیازدهی پاسخ‌های تشریحی استفاده می‌شود. محاسبه امتیاز نهایی، کنترل حداقل امتیاز، بررسی حداقل سطح Dimensionهای اجباری و انتخاب گرید نهایی توسط منطق قطعی انجام می‌شود. در TAI-04، گرید نهایی فقط بر اساس پاسخ‌های مصاحبه تعیین می‌شود و گرید رزومه صرفاً برای مقایسه نمایش داده می‌شود.

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
│   │   ├── V003__create_grade_assessment.sql
│   │   ├── V004__grant_talentai_runtime_permissions.sql
│   │   ├── V005__create_assessment_execution.sql
│   │   └── V006__link_grade_assessment_to_execution.sql
│   ├── queries
│   │   ├── Q001__select_active_grade_guide.sql
│   │   ├── Q002__resolve_grade_engine_input.sql
│   │   ├── Q003__persist_grade_assessment.sql
│   │   ├── Q004__claim_assessment_execution.sql
│   │   ├── Q005__advance_assessment_execution.sql
│   │   ├── Q006__attach_resume_extraction.sql
│   │   ├── Q007__complete_assessment_execution.sql
│   │   ├── Q008__fail_assessment_execution.sql
│   │   ├── Q009__load_completed_assessment_execution.sql
│   │   └── Q010__persist_operational_grade_assessment.sql
│   ├── seeds
│       └── R001__seed_java_backend_grade_guide_v1.sql
│   └── tests
│       ├── T001__assessment_execution_contract.sql
│       └── T002__assessment_execution_queries.sql
├── docs
│   └── releases
│       └── v1.0.0.md
├── prompts
│   └── evidence-scoring-v1.md
├── schemas
│   └── grade-evidence-scoring-v1.schema.json
├── scripts
│   ├── apply-database.sh
│   ├── bootstrap-local.sh
│   ├── build-phase1-release-package.sh
│   ├── build-step3b-upgrade-package.sh
│   ├── create-local-env.sh
│   ├── export-phase1-workflows.sh
│   ├── test-assessment-execution-contract.sh
│   ├── test-assessment-execution-queries.sh
│   ├── test-phase1-operational-workflows.sh
│   ├── transform-phase1-step3b.mjs
│   └── verify-phase1.sh
└── workflows
    └── phase-1
        ├── TAI-01-resume-intake-extraction-v2.json
        ├── TAI-02-grade-guide-resolver-v1.json
        ├── TAI-03-evidence-scoring-grade-engine-v1.json
        ├── TAI-04-candidate-interview-final-grade-v1.json
        └── manifest.json
```

## پورت‌ها، Databaseها و Roleها

| کاربرد | مقدار محلی پیش‌فرض |
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

`N8N_EDITOR_BASE_URL` و `N8N_WEBHOOK_URL` در Compose از `N8N_HOST_PORT` ساخته می‌شوند. بنابراین اگر برای یک محیط ایزوله پورت n8n را مثلاً به `5688` تغییر دهید، لینک Test Form نیز به‌صورت خودکار با همان پورت ساخته می‌شود؛ پورت داخلی کانتینر همچنان `5678` باقی می‌ماند.

## مسیر سریع نصب محلی

اگر پورت‌های پیش‌فرض `5678` و `5434` آزاد هستند، مسیر پیشنهادی نصب تازه این است:

```bash
git clone <repository-url>
cd tosan-n8n-talent-ai

chmod +x init-data.sh scripts/*.sh
./scripts/bootstrap-local.sh
```

Bootstrap به‌صورت خودکار:

1. در نبود `.env`، Secretهای محلی را ایجاد می‌کند؛
2. Compose را اعتبارسنجی و Imageها را دریافت می‌کند؛
3. PostgreSQL، n8n و Task Runner را اجرا می‌کند؛
4. تا سالم‌شدن n8n منتظر می‌ماند؛
5. همه Migrationها، Seedها و Runtime Permissionها را اعمال می‌کند؛
6. ساختار Workflowها، دیتابیس، Grade Guide و Permissionهای `talentai_app` را بررسی می‌کند.

اگر `.env` از قبل وجود داشته باشد، Bootstrap آن را تغییر نمی‌دهد و کلید رمزنگاری، Passwordها و Portهای فعلی حفظ می‌شوند.

اگر یکی از پورت‌ها اشغال است، قبل از Bootstrap فایل محلی را ایجاد کنید:

```bash
./scripts/create-local-env.sh
```

سپس Portهای لازم را در `.env` تغییر دهید؛ برای نمونه:

```dotenv
N8N_HOST_PORT=5688
POSTGRES_HOST_PORT=5435
```

و اجرا کنید:

```bash
./scripts/bootstrap-local.sh
```

بعد از موفقیت Bootstrap، مراحل «ورود اولیه به n8n»، «Credentialهای موردنیاز n8n»، «Import کردن Workflowها» و «اجرای تست End-to-End» را انجام دهید.

## راه‌اندازی برای اولین بار

### ۱. دریافت Repository

```bash
git clone <repository-url>
cd tosan-n8n-talent-ai
```

به‌جای `<repository-url>` آدرس Repository تیم را قرار دهید.

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

اگر می‌خواهید Port پیش‌فرض را تغییر دهید، همین‌جا و پیش از اولین `docker compose up` مقدار `N8N_HOST_PORT` یا `POSTGRES_HOST_PORT` را در `.env` اصلاح کنید. URL عمومی Editor و Form Trigger از `N8N_HOST_PORT` مشتق می‌شود و نیاز به تنظیم جداگانه ندارد.

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
TALENTAI_N8N_ENDPOINT="$(docker compose port n8n 5678)"
TALENTAI_N8N_HEALTHY=false

for attempt in {1..30}; do
  if curl -fsS "http://$TALENTAI_N8N_ENDPOINT/healthz"; then
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

unset TALENTAI_N8N_HEALTHY TALENTAI_N8N_ENDPOINT
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
5. اعطای Permissionهای پایه از طریق `V004` و Permissionهای Execution Contract از طریق `V005`؛
6. اتصال یکتای Assessment به Request از طریق `V006`؛
7. اجرای Seedهای idempotent موجود در `database/seeds`.

Volumeهای زیر داده‌ها را بین Recreate کانتینرها نگه می‌دارند:

```text
db_storage
n8n_storage
```

از `docker compose down -v` استفاده نکنید، مگر اینکه حذف کامل و آگاهانه همه داده‌های محلی هدف شما باشد.

### ۶. بررسی خودکار نصب

هم در نصب تازه و هم برای Volume موجود، ابتدا Database State را با Repository همگام کنید:

```bash
./scripts/apply-database.sh
```

سپس Verification کامل را اجرا کنید:

```bash
./scripts/verify-phase1.sh
```

Verification علاوه بر وجود جدول‌ها و Grade Guide، مجوزهای واقعی Role زیر و تست‌های Rollback-safe قرارداد اجرا را کنترل می‌کند:

```text
USAGE  -> schema talentai
SELECT -> resume_extraction, grade_guide, grade_assessment, assessment_execution
INSERT -> resume_extraction, grade_assessment, assessment_execution
UPDATE -> assessment_execution
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
TALENTAI_N8N_ENDPOINT="$(docker compose port n8n 5678)"
curl -fsS "http://$TALENTAI_N8N_ENDPOINT/healthz"
unset TALENTAI_N8N_ENDPOINT
```

این عملیات Volumeها را حذف نمی‌کند.

## ورود اولیه به n8n

آدرس واقعی Editor را بگیرید:

```bash
docker compose port n8n 5678
```

مرورگر را با همان Host و Port باز کنید. مقدار پیش‌فرض:

```text
http://127.0.0.1:5678
```

در نصب جدید، Owner محلی n8n را ایجاد کنید. اطلاعات این حساب در Volume n8n ذخیره می‌شود و نباید در Repository قرار گیرد.

## Credentialهای موردنیاز n8n

Workflowها بدون Credential Reference commit می‌شوند. هر عضو تیم باید Credentialهای محیط خودش را در n8n ایجاد و به Nodeهای مربوط متصل کند.

### Credential مربوط به TalentAI PostgreSQL

یک Credential از نوع `Postgres` با نام پیشنهادی `TalentAI PostgreSQL` بسازید:

| Field | Value |
| --- | --- |
| Host | `postgres` |
| Port | `5432` |
| Database | `talentai` |
| User | `talentai_app` |
| Password | مقدار محلی `TALENTAI_DB_PASSWORD` |
| SSL | Disabled در شبکه محلی Docker |

از `127.0.0.1:5434` داخل Nodeهای n8n استفاده نکنید؛ n8n باید از نام Service یعنی `postgres:5432` استفاده کند.

در macOS می‌توانید Password را بدون چاپ‌شدن در Terminal مستقیماً از `.env` در Clipboard قرار دهید:

```bash
awk -F= '
  $1 == "TALENTAI_DB_PASSWORD" {
    sub(/^[^=]*=/, "")
    printf "%s", $0
  }
' .env | pbcopy
```

گزینه `Test connection` فقط اتصال و احراز هویت را ثابت می‌کند؛ برای اطمینان از مجوز `INSERT` باید `./scripts/apply-database.sh` و سپس `./scripts/verify-phase1.sh` موفق باشند.

### OpenAI API Credential

یک Credential از نوع `OpenAI API` با نام پیشنهادی `TalentAI OpenAI` بسازید و API Key محیط خودتان را فقط در بخش Credentials وارد کنید. اگر محیط تیم از Endpoint سازگار با OpenAI استفاده می‌کند، Base URL و Model را مطابق همان Provider تنظیم کنید؛ Secret همچنان فقط باید در Credential Store قرار گیرد.

API Key نباید در این مکان‌ها قرار گیرد:

- Workflow JSON؛
- `.env.example`؛
- Prompt؛
- Git history؛
- Screenshot یا پیام تیمی.

پس از Import، Credentialها را دقیقاً به Nodeهای زیر اختصاص دهید:

| Workflow | Node | Credential |
| --- | --- | --- |
| TAI-01 | `Save Resume Extraction` | `TalentAI PostgreSQL` |
| TAI-01 | `OpenAI Chat Model` | `TalentAI OpenAI` |
| TAI-02 | `Resolve Extraction and Grade Guide` | `TalentAI PostgreSQL` |
| TAI-03 | `Persist Grade Assessment` | `TalentAI PostgreSQL` |
| TAI-03 | `GapGPT Evidence Scoring Model` | `TalentAI OpenAI` یا Credential سازگار Provider تیم |
| TAI-04 | `Resolve Candidate and Resume Grade` | `TalentAI PostgreSQL` |
| TAI-04 | `GapGPT Interview Question Model` | `TalentAI OpenAI` یا Credential سازگار Provider تیم |
| TAI-04 | `GapGPT Follow-up Question Model` | `TalentAI OpenAI` یا Credential سازگار Provider تیم |
| TAI-04 | `GapGPT Answer Scoring Model` | `TalentAI OpenAI` یا Credential سازگار Provider تیم |

پس از اتصال Credentialها، همه Workflowها را Save کنید؛ برای Smoke Test لازم نیست آن‌ها را Publish یا Activate کنید.

## Import کردن Workflowها در محیط جدید

در محیط منبع، چهار Workflow باید داخل Folder زیر قرار گیرند:

```text
TalentAI - Phase 1
```

فایل‌های Commit‌شده در حالت غیرفعال‌اند و Credential Reference یا Pin Data ندارند.

### مسیر پیشنهادی: Import کردن Package انتشار

Package انتشار چهار Workflow و وابستگی Sub-workflowها را با هم منتقل و IDهای مقصد را هنگام Import تطبیق می‌دهد. فایل متناظر با Tag پروژه را از GitHub Release دریافت کنید؛ برای نسخه `v1.0.0` نام مورد انتظار این است:

```text
TalentAI-phase-1-v1.0.0.n8np
```

در n8n مقصد ابتدا Owner محلی را ایجاد کنید، سپس از مسیر `Settings -> n8n API` یک API Key موقت برای CLI بسازید و اجرا کنید:

```bash
n8n-cli login

n8n-cli package import \
  --file=TalentAI-phase-1-v1.0.0.n8np \
  --workflow-conflict-policy=fail \
  --format=json
```

در ورود تعاملی، URL واقعی محیط مانند `http://127.0.0.1:5678` یا `http://127.0.0.1:5688` و API Key همان محیط را وارد کنید. API Key را در Command، README یا Git قرار ندهید.

فهرست Import را کنترل کنید:

```bash
n8n-cli workflow list \
  --format=json \
| jq -r '
    .[]
    | select(.name | startswith("TAI-"))
    | [.id, .name, .active]
    | @tsv
  '
```

باید دقیقاً چهار Workflow زیر را در حالت `false` ببینید:

```text
TAI-01 Resume Intake & Extraction v2
TAI-02 Grade Guide Resolver v1
TAI-03 Evidence Scoring & Deterministic Grade Engine v1
TAI-04 Candidate Interview & Final Grade v1
```

Package خام محلی در `exports/private` فقط ورودی Release Builder است و نباید مستقیماً Import، commit یا منتشر شود.

### مسیر جایگزین: Import دستی JSONهای standalone

اگر Package انتشار در دسترس نیست، JSONها را به این ترتیب Import کنید:

1. `TAI-02-grade-guide-resolver-v1.json`؛
2. `TAI-03-evidence-scoring-grade-engine-v1.json`؛
3. `TAI-04-candidate-interview-final-grade-v1.json`؛
4. `TAI-01-resume-intake-extraction-v2.json`.

در این مسیر باید دو Node زیر را در TAI-01 باز کنید و Workflow مقصد را دستی انتخاب کنید:

| Node | Workflow مقصد |
| --- | --- |
| `Resolve Grade Engine Input` | TAI-02 |
| `Run Deterministic Grade Engine` | TAI-03 |

در n8n Community، Workflowها در ریشه Personal Project وارد می‌شوند. در نسخه‌ای که قابلیت Folder دارد، می‌توانید پس از Import آن‌ها را به Folder `TalentAI - Phase 1` منتقل کنید.

پس از هر دو روش Import:

1. Credentialهای جدول بخش قبل را متصل کنید؛
2. دو Sub-workflow Reference در TAI-01 را کنترل کنید؛
3. هر چهار Workflow را Save کنید؛
4. ابتدا یک اجرای دستی End-to-End انجام دهید؛
5. فقط پس از موفقیت تست، Entry Workflow را برای استفاده موردنظر Publish یا Activate کنید.

Folder `TalentAI - Phase 1` فقط برای سازمان‌دهی و Export در محیط منبع استفاده می‌شود. چون Import کردن Folder به License پشتیبان Folder نیاز دارد، Artifact انتشار به‌صورت Flat و بدون Folder ساخته می‌شود تا روی n8n Community قابل Import باشد. پس از Import می‌توان Workflowها را در نسخه‌های دارای Folder به‌صورت دستی گروه‌بندی کرد.

قبل از Import در محیط مشترک، حتماً Manifest، تعداد Workflowها و Credential Requirementهای Package را بررسی کنید.

## اجرای تست End-to-End

برای تست کامل، از یک رزومه غیرحساس یا نمونه ساختگی استفاده کنید. فایل‌های رزومه را زیر `samples/private` نگه دارید تا توسط Git نادیده گرفته شوند.

قبل از تست، این دو دستور باید موفق باشند:

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

سپس:

1. TAI-01 را باز کنید؛
2. `Execute workflow` را بزنید تا Form Trigger در حالت انتظار قرار گیرد؛
3. در Node با نام `On form submission`، گزینه بازکردن `Test URL` را انتخاب کنید؛
4. یک PDF ساختگی یا غیرحساس و ورودی‌های زیر را ارسال کنید.

| Field | Example |
| --- | --- |
| Resume | یک PDF تست غیرحساس |
| `positionCode` | `JAVA_BACKEND` |
| `targetGradeCode` | `SENIOR` |
| `jobDescription` | شرح شغل هم‌راستا با Position و Target Grade |

نمونه شرح شغل:

```text
Senior Java Backend Developer with experience in Java, Spring Boot,
PostgreSQL, Kafka, testing, observability and architecture.
```

اجرای موفق باید از Nodeهای `Save Resume Extraction`، TAI-02 و `Persist Grade Assessment` عبور کند و با پیام `TalentAI assessment completed` پایان یابد.

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
        -> assessment_execution
```

## مسئولیت جدول‌ها

| Table | مسئولیت |
| --- | --- |
| `talentai.resume_extraction` | پروفایل ساخت‌یافته استخراج‌شده، اطلاعات منبع، Model و Schema Version |
| `talentai.grade_guide` | Grade Guide نسخه‌بندی‌شده، Dimensionها، Weightها و Decision Policy |
| `talentai.grade_assessment` | Dimension Assessmentها، امتیاز نهایی، نتیجه قواعد قطعی و اطلاعات Audit |
| `talentai.assessment_execution` | هویت Request، Fingerprint، Stage، Attempt، نتیجه و Failure Contract اجرای ارزیابی |

داده‌های Runtime داخل Volume PostgreSQL قرار دارند و جزئی از commit نیستند. Git فقط Migration، Seed و Queryهای قابل‌بازتولید را نگه می‌دارد.

## قرارداد عملیاتی اجرای ارزیابی

Migration `V005` چرخه اجرای عملیاتی را ایجاد می‌کند و `V006` هر Assessment عملیاتی را با `request_id` یکتا به همان چرخه متصل می‌کند. این اتصال از ایجاد Assessment دوم در Retry پس از یک قطع‌شدن بین Persistence و Completion جلوگیری می‌کند. هر درخواست با `request_id` یکتا و `input_fingerprint` ثبت می‌شود و فقط یکی از وضعیت‌های زیر را دارد:

```text
RUNNING -> COMPLETED
RUNNING -> FAILED -> RUNNING (only when retryable)
```

Stageهای مجاز از `INTAKE` تا `ASSESSMENT_PERSISTENCE` فقط رو به جلو حرکت می‌کنند. Queryهای `Q004` تا `Q008` عملیات Claim، تغییر Stage، اتصال Extraction، Completion و Failure را به‌صورت اتمیک انجام می‌دهند. `Q009` نتیجه تکمیل‌شده را برای Replay می‌خواند و `Q010` Assessment را نسبت به `request_id` به‌صورت idempotent ذخیره می‌کند. خروجی Claim یکی از وضعیت‌های پایدار زیر است:

```text
CLAIMED_NEW
CLAIMED_RETRY
ALREADY_RUNNING
COMPLETED_REPLAY
IDEMPOTENCY_CONFLICT
FAILED_NOT_RETRYABLE
```

Failure فقط با Category و Code پایدار و پیام کوتاه و پاک‌سازی‌شده ثبت می‌شود؛ متن رزومه، Prompt، پاسخ خام Provider و Credential نباید وارد `failure_message` شوند.

تست‌های زیر داخل Transaction اجرا و در پایان Rollback می‌شوند:

```bash
./scripts/test-assessment-execution-contract.sh
./scripts/test-assessment-execution-queries.sh
./scripts/test-phase1-operational-workflows.sh
```

تست نخست Schema، Constraint، Lifecycle و Permissionها را کنترل می‌کند. تست دوم Queryهای Runtime را با سناریوهای Claim، Duplicate، Conflict، Persistence idempotent، Completion، Replay، Failure و Retry اجرا می‌کند. تست سوم اتصال Queryها و Code nodeها به TAI-01، TAI-02 و TAI-03، مسیرهای branch و idempotent بودن Transformer را بررسی می‌کند.

قرارداد عملیاتی در Workflowها به این شکل متصل است:

- TAI-01 پس از استخراج متن PDF و پیش از فراخوانی AI، Request را Claim می‌کند؛
- `CLAIMED_RETRY` در صورت وجود Extraction قبلی، مرحله Profile Extraction را تکرار نمی‌کند؛
- `COMPLETED_REPLAY` نتیجه ذخیره‌شده را بدون فراخوانی AI برمی‌گرداند؛
- TAI-02 و TAI-03، `requestId`، Execution ریشه و Attempt را حمل و Stageها را ثبت می‌کنند؛
- TAI-03 ذخیره Assessment و Completion چرخه اجرا را به Request متصل می‌کند.

Form یک فیلد اختیاری `requestId` دارد. در اجرای اول آن را خالی بگذارید و شناسه بازگشتی را نگه دارید. برای Replay یا Retry امن، همان شناسه و دقیقاً همان Resume، Position، Target Grade و Job Description را ارسال کنید. استفاده از همان شناسه با ورودی متفاوت به `IDEMPOTENCY_CONFLICT` منجر می‌شود.

### ارتقای سه Workflow موجود بدون حذف Credentialها

ابتدا Migrationها و تست‌ها را اجرا کنید:

```bash
./scripts/apply-database.sh
./scripts/test-assessment-execution-contract.sh
./scripts/test-assessment-execution-queries.sh
./scripts/test-phase1-operational-workflows.sh
```

سپس Package ارتقا را از سه Workflow فعلی محیط بسازید. Transformer، Credential referenceهای موجود را نگه می‌دارد و Source تبدیل‌شده را با JSONهای commit‌شده مقایسه می‌کند:

```bash
./scripts/build-step3b-upgrade-package.sh
```

Package خروجی خصوصی است و نباید commit یا منتشر شود:

```text
exports/private/TalentAI-phase-1-step3.1B.n8np
```

آن را در همان Projectی Import کنید که سه Workflow فعلی را در اختیار دارد:

```bash
TALENTAI_PROJECT_ID='<existing-n8n-project-id>'

n8n-cli package import \
  --file=exports/private/TalentAI-phase-1-step3.1B.n8np \
  --project-id="$TALENTAI_PROJECT_ID" \
  --workflow-conflict-policy=new-version \
  --workflow-id-policy=source \
  --workflow-publishing-policy=preserve-published-state \
  --credential-matching-mode=id-only \
  --credential-missing-mode=must-preexist \
  --missing-node-type-mode=fail

unset TALENTAI_PROJECT_ID
```

خروجی Import باید هر سه Workflow را با `status: updated` و Credentialها را در `matched` نشان دهد؛ `stubbed` باید خالی باشد. پس از Import، Sourceها را از Runtime دوباره Export و Source Drift را کنترل کنید:

```bash
./scripts/export-phase1-workflows.sh 1.0.0
./scripts/test-phase1-operational-workflows.sh
git diff --check
git status --short --branch
```

بسته 3.1C مسیر خطای سراسری را در Workflow ریشه اضافه می‌کند. خطاهای بعد از Claim با Category و Code پایدار در `assessment_execution` ثبت می‌شوند؛ پیام ذخیره‌شده شامل رزومه، Prompt، پاسخ خام Provider یا Credential نیست. خطاهای پیش از Claim و شکست خود عملیات ثبت خطا با `Failure Recorded: NO` و شناسهٔ Workflow execution برگردانده می‌شوند تا اپراتور بتواند آن‌ها را پیگیری کند.

Retry فقط برای Failureهای موقت Provider و Failureهای قابل‌بازیابی Persistence/Orchestration فعال است. Validation و Configuration غیرقابل Retry هستند. Query ثبت Failure همچنین مالکیت `claim_owner_workflow_execution_id` را کنترل می‌کند تا اجرای قدیمی نتواند وضعیت Claim جدید را تغییر دهد. این مرحله resilience پایهٔ MVP را فراهم می‌کند.

### Timeout، Retry محدود و Observability

Workflow ریشه حداکثر ۳۰۰ ثانیه، Grade Guide Resolver حداکثر ۶۰ ثانیه و Grade Engine حداکثر ۲۴۰ ثانیه زمان اجرا دارند. دو Node متصل به Provider حداکثر سه تلاش داخلی با فاصلهٔ ثابت دو ثانیه انجام می‌دهند. تلاش داخلی Node با `attempt_count` متفاوت است؛ این ستون فقط Claim و Retry کامل درخواست را می‌شمارد.

اگر n8n اجرای Workflow را به علت Timeout متوقف کند، اجرای دیتابیسی ممکن است موقتاً `RUNNING` بماند. پیش از Claim بعدی، اجراهایی که بیش از ۳۶۰ ثانیه به‌روزرسانی نشده‌اند با Code پایدار `EXECUTION_TIMEOUT`، Category برابر `ORCHESTRATION` و `retryable = true` منقضی می‌شوند. فاصلهٔ ۶۰ ثانیه‌ای میان Timeout ریشه و stale threshold از منقضی‌شدن اجرای سالم جلوگیری می‌کند.

View زیر وضعیت عملیاتی، مدت اجرا و stale بودن را بدون Resume، Prompt، پاسخ خام Provider یا Credential نمایش می‌دهد:

```text
talentai.assessment_execution_observability
```

برای مشاهدهٔ ۲۰ اجرای اخیر:

```bash
./scripts/show-assessment-executions.sh
```

برای مشاهدهٔ حداکثر ۵۰ Failure اخیر:

```bash
./scripts/show-assessment-executions.sh FAILED 50
```

## Export کردن Sourceهای Workflow

Folder موجود در n8n برای نظم تیمی باید شامل چهار Workflow فاز اول باشد و Workflow تست یا Backup داخل آن قرار نگیرد.

```text
TalentAI - Phase 1
├── TAI-01 Resume Intake & Extraction v2
├── TAI-02 Grade Guide Resolver v1
├── TAI-03 Evidence Scoring & Deterministic Grade Engine v1
└── TAI-04 Candidate Interview & Final Grade v1
```

Export قابل‌انتشار به Folder ID وابسته نیست. اسکریپت شناسه دقیق چهار Workflow مجاز را از `workflows/phase-1/manifest.json` می‌خواند و با چهار `--workflow-id` صریح Export می‌کند:

```bash
./scripts/export-phase1-workflows.sh 1.0.0
```

اسکریپت این کنترل‌ها را انجام می‌دهد:

- Manifest کامیت‌شده دقیقاً چهار Workflow مورد انتظار و چهار ID معتبر داشته باشد؛
- Package خام Flat با Export صریح همان چهار Workflow ID تولید شود؛
- نام و ID هر چهار Workflow خروجی با allow-list کامیت‌شده برابر باشد؛
- Folder، Workflow تستی یا Backup وارد Package نشود؛
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
| `exports/private/TalentAI-phase-1-v*.flat.raw.n8np` | ورودی خصوصی و schema-valid برای Release Builder؛ ignored |
| `workflows/phase-1/TAI-*.json` | Source پاک‌سازی‌شده و قابل commit |
| `workflows/phase-1/manifest.json` | Manifest قابل commit |

بعد از Export اجرا کنید:

```bash
./scripts/verify-phase1.sh
```

## ساخت Package امن برای Release

Package خام حاصل از Export ممکن است Metadata یا Credential Referenceهای محلی Workflowها را همراه داشته باشد و فقط برای پردازش محلی در `exports/private` نگه‌داری می‌شود. Release Builder از فایل `*.flat.raw.n8np` استفاده می‌کند؛ این فایل مستقیماً توسط n8n-cli و با سه `--workflow-id` ساخته شده است، بنابراین Workflowهای داخل آن schema مخصوص Package را دارند.

برای ساخت Artifact انتشار اجرا کنید:

```bash
./scripts/build-phase1-release-package.sh 1.0.0
```

این اسکریپت:

- Manifest و ساختار Package خام Flat را کنترل می‌کند؛
- وجود دقیقاً چهار Workflow مورد انتظار و نبود Folder را کنترل می‌کند؛
- `versionId` و سایر فیلدهای schema مخصوص Package را از Export رسمی n8n حفظ می‌کند؛
- با نرمال‌سازی Package Workflow و Source قابل‌commit، نبود Source Drift را کنترل می‌کند؛
- Credential Referenceها را فقط از Nodeهای Package Workflow حذف می‌کند؛
- Credential و Variable Entityها و Requirementهای محلی را از Manifest انتشار حذف می‌کند؛
- وابستگی‌های TAI-01 به TAI-02 و TAI-03 را نگه می‌دارد؛
- تعداد Entityها، نبود Secret و SHA-256 خروجی را بررسی می‌کند.

خروجی:

```text
dist/TalentAI-phase-1-v1.0.0.n8np
```

پوشه `dist` تولیدشدنی است و وارد Git نمی‌شود. Artifact نهایی باید به GitHub Release پیوست شود.

خلاصه Manifest مورد انتظار:

```json
{
  "packageFormatVersion": "1",
  "sourceN8nVersion": "2.36.8",
  "workflowCount": 4,
  "folderCount": 0,
  "credentialEntityCount": 0,
  "credentialRequirementCount": 0,
  "workflowDependencyCount": 2,
  "variableEntityCount": 0,
  "variableRequirementCount": 0
}
```

Credential Entity و Credential Requirement عمداً صفر هستند، زیرا Credential Referenceها از Workflowهای انتشار حذف شده‌اند. پس از Import، Credentialهای PostgreSQL و OpenAI محیط مقصد باید به‌صورت دستی انتخاب شوند.

Folder Count نیز عمداً صفر است تا Artifact روی n8n Community به License مربوط به Folder وابسته نباشد. Folder تیمی همچنان در محیط منبع و فرایند Export حفظ می‌شود.

فایل‌های `workflows/phase-1/*.json` قالب standalone و قابل‌commit دارند و شامل `active: false` هستند. فایل‌های `workflow.json` داخل `.n8np` قالب Package دارند، باید `versionId` داشته باشند و نباید با JSONهای standalone جایگزین شوند. Release Builder این دو قالب را فقط برای کنترل Source Drift نرمال می‌کند و Artifact نهایی را از entityهای Package می‌سازد. Folder `TalentAI - Phase 1` صرفاً ابزار سازمان‌دهی محیط منبع است و نبود دسترسی API به آن، فرایند Release را متوقف نمی‌کند.

## Tag و GitHub Release

قبل از Tag، تمام تست‌ها و وضعیت Git را کنترل کنید:

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
git diff --check
git status --short --branch
```

پس از Commit و Push تغییرات Release Tooling:

```bash
git tag -a v1.0.0 \
  -m "TalentAI n8n Phase 1 v1.0.0"

git push origin v1.0.0
```

ساخت GitHub Release و پیوست Package امن:

```bash
gh release create v1.0.0 \
  dist/TalentAI-phase-1-v1.0.0.n8np \
  --title "TalentAI n8n Phase 1 v1.0.0" \
  --notes-file docs/releases/v1.0.0.md \
  --verify-tag
```

پس از انتشار، SHA-256 نمایش‌داده‌شده توسط اسکریپت را در توضیحات Release یا کانال تیم قرار دهید.

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
workflows/phase-1/TAI-04-candidate-interview-final-grade-v1.json
workflows/phase-1/manifest.json
```

کنترل فایل‌های حساس:

```bash
git check-ignore -v .env
git check-ignore -v exports/private/TalentAI-phase-1-v1.0.0.flat.raw.n8np
```

هیچ‌کدام از موارد زیر نباید Stage یا Commit شوند:

- `.env`؛
- API Key، Password، Token و Authorization Header؛
- فایل رزومه و اطلاعات خصوصی کاندید؛
- `exports/private`؛
- Pin Data و Execution Sample؛
- Volume یا Backup دیتابیس؛
- `.DS_Store`، فایل‌های AppleDouble با الگوی `._*` و فایل‌های IDE.

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

### Form Trigger در حالت انتظار می‌ماند یا Test Form باز نمی‌شود

Form Trigger تا زمان Submit شدن فرم عمداً در حالت انتظار می‌ماند. اگر Browser فرم را باز نمی‌کند، Test URL را در Node `On form submission` بررسی کنید. Origin باید با Port واقعی Editor یکسان باشد؛ برای نمونه:

```text
http://127.0.0.1:5688/form-test/...
```

Compose فعلی `N8N_EDITOR_BASE_URL` و `N8N_WEBHOOK_URL` را از `N8N_HOST_PORT` می‌سازد. اگر `.env` یا Compose override را تغییر داده‌اید، n8n را Recreate کنید:

```bash
docker compose config --quiet
docker compose up -d --force-recreate n8n
docker compose restart n8n-runner
TALENTAI_N8N_ENDPOINT="$(docker compose port n8n 5678)"
curl -fsS "http://$TALENTAI_N8N_ENDPOINT/healthz"
unset TALENTAI_N8N_ENDPOINT
```

پس از Refresh کردن Editor، دوباره `Execute workflow` را بزنید؛ Test URL فقط هنگام Listening معتبر است.

### `permission denied for table resume_extraction`

موفق‌بودن `Test connection` در Credential به معنی داشتن مجوز `INSERT` نیست. Workflow باید با Role محدود `talentai_app` اجرا شود و Migration `V004` مجوزهای لازم را اعمال کند:

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

برای اعمال GRANT نیازی به Restart کردن PostgreSQL یا n8n نیست. اجرای شکست‌خورده را Resume نکنید؛ Smoke Test تازه‌ای از Form Trigger آغاز کنید. Credential را برای دورزدن خطا به Role مدیریتی `admin` تغییر ندهید.

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

## محدودیت‌های نسخهٔ فعلی

- اطلاعات رزومه ادعای کاندید است و اعتبار بیرونی آن بررسی نمی‌شود؛
- امتیاز Evidence Scoring ممکن است به‌علت رفتار LLM کمی تغییر کند؛
- Decision Engine فقط براساس Grade Guide و Dimension Scoreهای تولیدشده تصمیم می‌گیرد؛
- Grade Guide فعلی مربوط به `JAVA_BACKEND` و نسخه `1.0.0` است؛
- این فاز UI اختصاصی TalentAI ندارد و از Form و Editor مربوط به n8n استفاده می‌کند؛
- Production hardening، Backup policy، HTTPS، SSO، Queue scaling و Monitoring خارج از محدوده این فاز هستند.

## منابع رسمی

- [n8n Docker Compose deployment](https://docs.n8n.io/deploy/host-n8n/install-options/use-a-cloud-provider/use-docker-compose/)
- [n8n encryption key configuration](https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/configuration-examples/set-a-custom-encryption-key/)
- [n8n endpoint environment variables](https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/use-environment-variables/endpoints/)
- [n8n Form Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.formtrigger/)
- [n8n packages](https://docs.n8n.io/build/manage-workflows/n8n-packages/)
- [Export an n8n package](https://docs.n8n.io/build/manage-workflows/n8n-packages/export-a-package/)
- [Import an n8n package](https://docs.n8n.io/build/manage-workflows/n8n-packages/import-a-package/)
- [n8n CLI](https://docs.n8n.io/connect/n8n-cli/)
- [PostgreSQL JSON functions](https://www.postgresql.org/docs/current/functions-json.html)

## مجوز و مالکیت

این پروژه برای استفاده داخلی تیم TalentAI تهیه شده است. پیش از انتشار عمومی، سیاست مالکیت کد، مجوز استفاده، داده‌های نمونه و الزامات حریم خصوصی سازمان باید مشخص شوند.
