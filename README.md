# TalentAI n8n

TalentAI یک سامانهٔ قابل ممیزی برای پشتیبانی از غربالگری رزومه، ارزیابی فنی
و مصاحبهٔ کاندیدهاست. این Repository زیرساخت داده، Workflowهای n8n،
قراردادهای نسخه‌بندی‌شده، آزمون‌ها و ابزارهای عملیاتی سامانه را نگه‌داری
می‌کند.

آخرین Release پایدار این مسیر، [`v3.1.0`](https://github.com/sdxcod/talent-ai-n8n/releases/tag/v3.1.0)
است و پنج Workflow فازهای ۱ تا ۵ را به‌همراه دعوت امن تحت کنترل HR و فرم‌های
راست‌به‌چپ ارائه می‌کند.

این Repository فقط منابع قابل‌اشتراک را نگه می‌دارد. Credentialها، کلیدهای
API، فایل‌های رزومه، Token دعوت، داده‌های اجرای n8n و Packageهای محلی نباید
در Git قرار گیرند.

## وضعیت فعلی پیاده‌سازی

| Workflow | نوع | مسئولیت |
| --- | --- | --- |
| `TAI-01 Resume Intake & Extraction v2` | فرم داخلی HR و Workflow ریشه | دریافت رزومه، استخراج و اعتبارسنجی پروفایل، ثبت چرخهٔ ارزیابی و نمایش نتیجه |
| `TAI-02 Grade Guide Resolver v1` | Sub-workflow | بازیابی Extraction و Grade Guide فعال و ساخت ورودی استاندارد Grade Engine |
| `TAI-03 Evidence Scoring & Deterministic Grade Engine v1` | Sub-workflow | امتیازدهی مبتنی بر شواهد، اجرای قواعد قطعی، ذخیره Assessment و Decision |
| `TAI-04 Candidate Interview & Final Grade v1` | فرم کاندید | Claim کردن دعوت معتبر، تولید و دریافت سؤال‌ها، ارزیابی پاسخ‌ها و ذخیره نتیجه نهایی |
| `TAI-05 Secure Interview Invitation v1` | فرم داخلی HR | صدور و لغو دعوت زمان‌دار و یک‌بارمصرف برای Assessment تکمیل‌شده |

جریان عملیاتی:

```text
Resume PDF
  -> TAI-01: intake, extraction and execution tracking
  -> TAI-02: grade-guide resolution
  -> TAI-03: evidence scoring and deterministic decision
  -> MEETS_TARGET: conditional HR action
  -> TAI-05: HR approval and secure invitation issuance
  -> TAI-04: one-time token claim, interview and final grade
```

مرز Assessment و Interview آگاهانه asynchronous است. TAI-01 اجرای انسانی
مصاحبه را باز نگه نمی‌دارد و TAI-04 را مستقیماً فراخوانی نمی‌کند. ارتباط
فازها از طریق دادهٔ persisted و شناسه‌های `requestId`، `assessmentId`،
`extractionId` و Invitation امن برقرار می‌شود.

LLM برای استخراج اطلاعات، امتیازدهی شواهد، تولید سؤال و ارزیابی پاسخ‌ها
استفاده می‌شود. محاسبهٔ امتیازهای وزنی، Threshold، Dimensionهای اجباری،
Decision اولیه و کنترل چرخهٔ اجرا توسط منطق قطعی انجام می‌شود.

## نقش‌ها، فرم‌ها و محدودهٔ دسترسی

در مثال‌های زیر، `N8N_BASE_URL` آدرس واقعی محیط است. مقدار محلی پیش‌فرض آن
`http://127.0.0.1:5678` است.

| مسیر Published | کاربر | کنترل دسترسی | کاربرد |
| --- | --- | --- | --- |
| `/form/talentai-hr-resume-assessment` | HR | ورود کاربر n8n و Execute Access | ثبت رزومه و اجرای Assessment |
| `/form/talentai-secure-interview-invitation` | HR | ورود کاربر n8n و Execute Access | صدور یا لغو دعوت مصاحبه |
| `/form/talentai-candidate-interview?invitationToken=...` | کاندید | Token معتبر، منقضی‌نشده، لغونشده و استفاده‌نشده | شروع و ادامه مصاحبه |

نمونهٔ محلی:

```text
http://127.0.0.1:5678/form/talentai-hr-resume-assessment
http://127.0.0.1:5678/form/talentai-secure-interview-invitation
http://127.0.0.1:5678/form/talentai-candidate-interview?invitationToken=<token>
```

نکات مهم:

- دکمهٔ دعوت در Form Ending مربوط به TAI-01 فقط برای Decision برابر
  `MEETS_TARGET` نمایش داده می‌شود؛
- نمایش دکمه به معنی صدور خودکار دعوت نیست؛ مسئول HR باید عملیات Issue را در
  TAI-05 تأیید کند؛
- Formهای HR با `n8nUserAuth` محافظت می‌شوند، اما محدودیت شبکه مسئولیت
  Deployment است؛ در محیط سازمانی این دو مسیر باید پشت Intranet، VPN،
  Firewall یا Reverse Proxy مناسب قرار گیرند؛
- Form کاندید می‌تواند از شبکه بیرونی قابل دسترسی باشد، اما فقط Token معتبر
  امکان شروع مصاحبه را می‌دهد؛
- URLهایی با مسیر `/form-waiting/...` و پارامتر `signature` به اجرای جاری
  وابسته‌اند و لینک دائمی یا قابل توزیع نیستند؛
- Test URL فقط هنگام `Execute workflow` معتبر است. برای استفاده عملیاتی از
  Published URL استفاده کنید؛
- Token دعوت یک Secret موقت است و نباید در Log، Screenshot، Issue عمومی یا
  پیام گروهی غیرمجاز قرار گیرد.

قرارداد Invitation نسخه `1.0.0` این محدودیت‌ها را اعمال می‌کند:

| ویژگی | مقدار |
| --- | --- |
| TTL پیش‌فرض | ۲۸۸۰ دقیقه (۴۸ ساعت) |
| حداقل TTL | ۱۵ دقیقه |
| حداکثر TTL | ۱۰۰۸۰ دقیقه (۷ روز) |
| Issue و Revoke | فقط HR از TAI-05 |
| Claim | اتمیک و یک‌بارمصرف در TAI-04 |
| Expired یا Revoked | غیرقابل استفاده برای کاندید |

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

نسخه‌های n8n و PostgreSQL در `.env` ثابت می‌شوند. ارتقای آن‌ها باید در یک
تغییر مستقل، پس از تهیه Backup و اجرای Verification انجام شود.

## پیش‌نیازها

- Docker Desktop یا Docker Engine به‌همراه Docker Compose؛
- `curl`، `jq`، `ripgrep`، `openssl` و `tar`؛
- Credential سازگار با OpenAI API و Modelهای Workflow؛
- Node.js، npm و `@n8n/cli` برای ساخت، Export یا Import Package.

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

نصب n8n CLI:

```bash
npm install -g @n8n/cli
n8n-cli --version
```

## ساختار Repository

ساختار سطح بالا عمداً خلاصه نمایش داده شده است. فهرست دقیق ابزارها و مسئولیت
آن‌ها در [`scripts/README.md`](scripts/README.md) قرار دارد.

```text
.
├── database
│   ├── bootstrap        # ساخت اولین Volume PostgreSQL
│   ├── migrations       # V001 تا V011
│   ├── queries          # Q001 تا Q025
│   ├── seeds            # Grade Guideهای مرجع
│   └── tests            # آزمون‌های SQL و Rollback-safe
├── docs
│   ├── releases
│   └── runbooks
├── prompts              # Promptهای نسخه‌بندی‌شده
├── schemas              # JSON Schema و قراردادهای داده
├── scripts              # Bootstrap، تست، تبدیل و Release build
└── workflows
    ├── phase-1          # TAI-01، TAI-02 و TAI-03
    └── phase-4-5        # TAI-04 و TAI-05
```

فایل‌های `database/bootstrap` دستور روزمرهٔ Host نیستند؛ Docker آن‌ها را فقط
هنگام ایجاد اولین Volume اجرا می‌کند. همگام‌سازی روزمرهٔ دیتابیس با
`scripts/apply-database.sh` انجام می‌شود.

مسیر رسمی Windows برای MVP، Docker Desktop همراه WSL2 است. این روش همان
فرمان‌های Bash مورد استفاده در Linux و CI را اجرا می‌کند. Helper موجود در
`scripts/windows` فقط برای عملیات محدود و Native دیتابیس است.

## پورت‌ها، Databaseها و Roleها

| کاربرد | مقدار محلی پیش‌فرض |
| --- | --- |
| n8n Editor و Formها | `http://127.0.0.1:5678` |
| n8n health endpoint | `http://127.0.0.1:5678/healthz` |
| PostgreSQL از Host | `127.0.0.1:5434` |
| PostgreSQL از شبکه Docker | `postgres:5432` |
| n8n metadata database | `n8n` |
| TalentAI application database | `talentai` |
| PostgreSQL administrator | `admin` |
| n8n runtime role | `n8n_app` |
| TalentAI runtime role | `talentai_app` |
| TalentAI schema | `talentai` |

PostgreSQL فقط روی Loopback منتشر می‌شود. `N8N_EDITOR_BASE_URL` و
`N8N_WEBHOOK_URL` از `N8N_HOST_PORT` ساخته می‌شوند؛ تغییر Port در `.env`
باعث تغییر URLهای محلی Editor و Form می‌شود و Port داخلی کانتینر همچنان
`5678` باقی می‌ماند.

## نصب محلی تازه

Repository را با نام پوشهٔ مورد استفاده در این راهنما دریافت کنید:

```bash
git clone \
  https://github.com/sdxcod/talent-ai-n8n.git \
  tosan-n8n-talent-ai

cd tosan-n8n-talent-ai
```

اگر Repository خصوصی باشد، GitHub باید قبلاً از طریق SSH، Credential Manager
یا `gh auth login` احراز هویت شده باشد.

Bootstrap استاندارد:

```bash
chmod +x database/bootstrap/*.sh scripts/*.sh
./scripts/bootstrap-local.sh
```

Bootstrap در نصب تازه:

1. در نبود `.env`، Secretهای محلی را بدون چاپ مقدار تولید می‌کند؛
2. Compose را اعتبارسنجی و Stack را اجرا می‌کند؛
3. PostgreSQL، n8n و Task Runner را آماده می‌کند؛
4. Migrationهای `V001` تا `V011` و Seedهای مرجع را اعمال می‌کند؛
5. Roleها و Permissionهای Runtime را بررسی می‌کند؛
6. Verification پایه را اجرا می‌کند.

اگر Port پیش‌فرض اشغال است، ابتدا فایل محلی را ایجاد و سپس فقط مقادیر لازم را
در `.env` تغییر دهید:

```bash
./scripts/create-local-env.sh
```

```dotenv
N8N_HOST_PORT=5688
POSTGRES_HOST_PORT=5435
```

فایل `.env` را Commit یا ارسال نکنید. در نصب موجود نیز
`create-local-env.sh` را دوباره اجرا نکنید، زیرا `N8N_ENCRYPTION_KEY` فعلی
برای خواندن Credentialهای ذخیره‌شده لازم است.

کنترل Stack:

```bash
docker compose config --quiet
docker compose ps

TALENTAI_N8N_ENDPOINT="$(docker compose port n8n 5678)"
curl -fsS "http://$TALENTAI_N8N_ENDPOINT/healthz"
unset TALENTAI_N8N_ENDPOINT
```

خروجی سالم Health Check:

```json
{"status":"ok"}
```

همگام‌سازی و Verification دیتابیس:

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

این فرمان‌ها برای نصب تازه و Volume موجود قابل استفاده‌اند. از
`docker compose down -v` استفاده نکنید، مگر اینکه حذف کامل و آگاهانهٔ تمام
داده‌های محلی هدف باشد.

## ورود اولیه و Credentialهای n8n

آدرس واقعی Editor را بگیرید:

```bash
docker compose port n8n 5678
```

در نصب تازه، Owner محلی n8n را ایجاد کنید. اطلاعات حساب و API Key مربوط به
n8n CLI نباید وارد Repository شوند.

دو نوع Credential لازم است:

| Credential | تنظیمات اصلی | مصرف‌کنندگان |
| --- | --- | --- |
| PostgreSQL | `postgres:5432`، Database برابر `talentai` و User برابر `talentai_app` | Nodeهای Persistence و Query در TAI-01 تا TAI-05 |
| OpenAI API-compatible | API Key، Base URL و Model مورد تأیید محیط | استخراج، Evidence Scoring، تولید سؤال و ارزیابی پاسخ |

از `127.0.0.1:5434` داخل Nodeهای n8n استفاده نکنید؛ این آدرس مخصوص Host است.
Workflow باید با Role محدود `talentai_app` اجرا شود و Role `admin` فقط برای
Migration و عیب‌یابی محلی استفاده شود.

API Key و Password نباید در Workflow JSON، `.env.example`، Prompt، Git
history، Screenshot یا پیام تیمی قرار گیرند.

## دریافت و Import کردن Release Package

روش استاندارد نصب و ارتقا استفاده از Package متناظر با GitHub Release است.
Import دستی JSONهای standalone بخشی از نصب عادی نیست؛ آن فایل‌ها Source
قابل‌ممیزی توسعه هستند و جزئیات Export و Transformation آن‌ها در
[`scripts/README.md`](scripts/README.md) نگه‌داری می‌شود.

دریافت `v3.1.0` با GitHub CLI:

```bash
mkdir -p exports/private

gh release download v3.1.0 \
  --repo sdxcod/talent-ai-n8n \
  --pattern 'TalentAI-phase45-mvp-v3.1.0.n8np' \
  --dir exports/private

TALENTAI_PACKAGE="$PWD/exports/private/TalentAI-phase45-mvp-v3.1.0.n8np"
test -s "$TALENTAI_PACKAGE"
shasum -a 256 "$TALENTAI_PACKAGE"
```

ابتدا با `n8n-cli login` به محیط مقصد متصل شوید و Project ID مقصد را تعیین
کنید.

### نصب در Project تازه

در محیط تازه می‌توان Placeholderهای خالی Credential را از Package ایجاد کرد
و سپس مقدار Secret آن‌ها را فقط در Credential Store تکمیل کرد:

```bash
TALENTAI_PROJECT_ID='<target-n8n-project-id>'

n8n-cli package import \
  --file="$TALENTAI_PACKAGE" \
  --project-id="$TALENTAI_PROJECT_ID" \
  --workflow-conflict-policy=fail \
  --workflow-id-policy=source \
  --workflow-publishing-policy=preserve-published-state \
  --credential-matching-mode=id-only \
  --credential-missing-mode=create-stub \
  --missing-node-type-mode=fail \
  --format=json
```

پس از Import، Credentialهای Stub باید قبل از اجرای Workflow با مقادیر صحیح
PostgreSQL و Provider تکمیل و Test شوند.

### ارتقای Project موجود

در محیطی که دو Credential موردنیاز از قبل با همان شناسه‌ها وجود دارند، مسیر
سخت‌گیرانهٔ آزموده‌شده استفاده می‌شود:

```bash
TALENTAI_PROJECT_ID='<existing-n8n-project-id>'

n8n-cli package import \
  --file="$TALENTAI_PACKAGE" \
  --project-id="$TALENTAI_PROJECT_ID" \
  --workflow-conflict-policy=new-version \
  --workflow-id-policy=source \
  --workflow-publishing-policy=preserve-published-state \
  --credential-matching-mode=id-only \
  --credential-missing-mode=must-preexist \
  --missing-node-type-mode=fail \
  --format=json
```

خروجی مطلوب Upgrade:

- پنج Workflow با وضعیت `updated`؛
- دو Credential در `matched`؛
- مقدار `stubbed` خالی؛
- Publishing state بدون تغییر.

پس از پایان عملیات:

```bash
unset TALENTAI_PACKAGE TALENTAI_PROJECT_ID
```

## ترتیب Publish و URLهای عملیاتی

به‌علت Dependencyهای TAI-01، Workflowها را به این ترتیب Save و Publish کنید:

1. `TAI-02 Grade Guide Resolver v1`؛
2. `TAI-03 Evidence Scoring & Deterministic Grade Engine v1`؛
3. `TAI-04 Candidate Interview & Final Grade v1`؛
4. `TAI-05 Secure Interview Invitation v1`؛
5. `TAI-01 Resume Intake & Extraction v2`.

اگر TAI-01 پیش از Sub-workflowهای آن Publish شود، n8n خطای Published نبودن
TAI-02 یا TAI-03 را نمایش می‌دهد.

پس از Publish، URL را از خود Form Trigger کپی و Host آن را با محیط مقصد کنترل
کنید. URLهای HR را عمومی اعلام نکنید. Candidate URL فقط پس از Issue موفق در
TAI-05 و همراه Token همان دعوت ساخته می‌شود.

## Smoke Test و اجرای End-to-End

Runbook کامل در
[`docs/runbooks/phase45-end-to-end.md`](docs/runbooks/phase45-end-to-end.md)
قرار دارد. برای Smoke Test فقط از رزومهٔ ساختگی یا مجاز استفاده کنید.

### ۱. کنترل پایه

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

### ۲. ارزیابی رزومه توسط HR

1. با حساب مجاز n8n وارد شوید؛
2. Published URL مربوط به `talentai-hr-resume-assessment` را باز کنید؛
3. یک PDF غیرحساس و مقادیر سازگار مانند `JAVA_BACKEND` و Grade هدف را وارد
   کنید؛
4. Form Ending موفق باید نتیجهٔ قابل‌فهم Assessment را نمایش دهد؛
5. دکمهٔ ساخت دعوت فقط در Decision برابر `MEETS_TARGET` دیده می‌شود.

Form Ending یک نمای انسانی است و لازم نیست تمام فیلدهای داخلی Assessment را
نمایش دهد. قرارداد کامل شامل شناسه‌های همبستگی، امتیازها، نسخهٔ Grade Guide،
Model و Timestampها در دادهٔ persisted و تست‌های Source کنترل می‌شود.

مسیر Validation ناموفق باید Form Ending کنترل‌شده نشان دهد و برای خطای پیش
از Claim رکورد Assessment ناقص نسازد.

### ۳. صدور دعوت توسط HR

1. دکمهٔ شرطی یا Published URL مربوط به TAI-05 را باز کنید؛
2. عملیات Issue را برای Assessment/Extraction تکمیل‌شده تأیید کنید؛
3. TTL را در محدودهٔ مجاز قرار دهید؛
4. Candidate URL تولیدشده را فقط از کانال مجاز برای همان کاندید ارسال کنید.

HR می‌تواند دعوت Claim‌نشده را از همان Workflow لغو کند. Token لغوشده یا
منقضی‌شده نباید مصاحبه را آغاز کند.

### ۴. مصاحبهٔ کاندید

1. Candidate URL حاوی `invitationToken` را در Session جداگانه باز کنید؛
2. TAI-04 باید Token را اتمیک Claim کند؛
3. سؤال‌های مرحله اول و Follow-up را تکمیل کنید؛
4. Form Ending نهایی باید نتیجه یا Failure پاک‌سازی‌شده را نمایش دهد؛
5. استفادهٔ مجدد از همان Token نباید Session دوم ایجاد کند.

### ۵. کنترل همبستگی فازهای ۱ تا ۵

پس از یک اجرای کامل، `extractionId` مربوط به همان Assessment را بررسی کنید:

```bash
./scripts/verify-phase45-correlation.sh '<phase3-extraction-uuid>'
```

این Gate وجود یک زنجیرهٔ سازگار از Assessment، Question Setها، Answerهای
ارزیابی‌شده و نتیجهٔ نهایی را کنترل می‌کند. این تست به دادهٔ Provider-backed
نیاز دارد و عمداً جزو CI روی دیتابیس خالی نیست.

## بررسی Runtime در PostgreSQL

برای وضعیت ارزیابی‌های اخیر، از View پاک‌سازی‌شده استفاده کنید:

```bash
./scripts/show-assessment-executions.sh
```

نمایش Failureهای اخیر:

```bash
./scripts/show-assessment-executions.sh FAILED 50
```

فهرست Objectهای فعلی Schema:

```bash
docker compose exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U admin -d talentai <<'SQL'
SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'talentai'
ORDER BY table_name;
SQL
```

برای بررسی End-to-End از Query دستی روی Payloadهای رزومه یا پاسخ استفاده
نکنید؛ `verify-phase45-correlation.sh` شناسه‌ها، وضعیت‌ها و شمارش‌های لازم را
بدون چاپ محتوای حساس بررسی می‌کند.

### مسئولیت جدول‌ها

| Table | مسئولیت |
| --- | --- |
| `talentai.resume_extraction` | پروفایل ساخت‌یافتهٔ رزومه، اطلاعات منبع و نسخهٔ Schema/Model |
| `talentai.grade_guide` | Grade Guide نسخه‌بندی‌شده، Dimensionها، Weightها و Decision Policy |
| `talentai.grade_assessment` | امتیازها، نتیجهٔ قواعد قطعی و اطلاعات ممیزی Assessment |
| `talentai.assessment_execution` | Request، Fingerprint، Claim owner، Stage، Attempt و Failure Contract |
| `talentai.technical_interview_session` | چرخه، Stage، Checkpoint و وضعیت مصاحبه |
| `talentai.technical_question_set` | سؤال‌های نسخه‌بندی‌شدهٔ هر Round |
| `talentai.technical_interview_answer` | پاسخ‌ها و متادیتای ارزیابی هر سؤال |
| `talentai.technical_interview_result` | نتیجهٔ نهایی و Final Grade مصاحبه |
| `talentai.technical_interview_invitation` | Hash دعوت، TTL، وضعیت Issue/Claim/Revoke/Expire و ارتباط با Assessment |

داده‌های Runtime داخل Volume PostgreSQL قرار دارند و جزئی از Commit نیستند.
Git فقط Migration، Seed، Query و Sourceهای قابل‌بازتولید را نگه می‌دارد.

### اتصال IntelliJ IDEA

| Field | Value |
| --- | --- |
| Host | `127.0.0.1` |
| Port | `5434` |
| Database | `talentai` |
| User | `talentai_app` یا `admin` برای مدیریت محلی |
| SSL | Disabled در محیط محلی |
| JDBC URL | `jdbc:postgresql://127.0.0.1:5434/talentai` |

Schema با نام `talentai` را برای Introspection انتخاب و Data Source را
Synchronize کنید.

## قراردادهای عملیاتی در یک نگاه

- `requestId` و `input_fingerprint` اجرای تکراری را از ورودی متفاوت تشخیص
  می‌دهند و از Assessment تکراری جلوگیری می‌کنند؛
- Claim owner مانع تغییر وضعیت اجرای جدید توسط Execution قدیمی می‌شود؛
- Stageها رو به جلو حرکت می‌کنند و Retry فقط برای Failureهای موقت و
  قابل‌بازیابی فعال است؛
- Checkpoint مصاحبه اجازه می‌دهد سؤال‌ها و پاسخ‌های ثبت‌شده پس از Failure
  دوباره تولید نشوند؛
- Failureها با Category و Code پایدار و پیام پاک‌سازی‌شده ثبت می‌شوند؛
- Resume، Prompt، پاسخ خام Provider، Credential و Token خام نباید در
  Failure message یا Log عملیاتی ذخیره شوند؛
- Invitation فقط برای Assessment تکمیل‌شده صادر و در TAI-04 به‌صورت اتمیک
  Claim می‌شود؛
- Formهای نتیجه و خطا RTL هستند و Payload داخلی را مستقیماً نمایش نمی‌دهند.

جزئیات Queryها، Timeoutها، Retryها، Transformerها و Release tooling در Source،
Testها، Manifestها، Runbook و [`scripts/README.md`](scripts/README.md) قرار
دارند تا README اصلی برای Developer تازه‌وارد قابل مرور بماند.

## تست‌های توسعه و Release Gateها

Verification جامع Repository و Runtime:

```bash
docker compose config --quiet
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

تست‌های متمرکز هنگام تغییر همان حوزه:

```bash
./scripts/test-phase1-operational-workflows.sh
./scripts/test-technical-interview-persistence.sh
./scripts/test-technical-interview-invitations.sh
node scripts/test-phase45-workflow.mjs
node scripts/test-secure-invitation-workflows.mjs
node scripts/test-form-access-and-rtl.mjs
```

آزمون‌های SQL داخل Transaction اجرا و Rollback می‌شوند. آزمون correlation
تنها پس از اجرای کامل واقعی قابل استفاده است:

```bash
./scripts/verify-phase45-correlation.sh '<phase3-extraction-uuid>'
```

پیش از Commit:

```bash
git diff --check
git status --short --branch
```

## ساخت Package انتشار

Builder رسمی پنج Workflow، دو Credential definition بدون Secret، Dependencyها
و Source contractها را کنترل می‌کند و Archive را برای الگوهای Secret اسکن
می‌کند:

```bash
TALENTAI_RELEASE_VERSION='3.1.0'

./scripts/build-phase45-mvp-package.sh \
  "$TALENTAI_RELEASE_VERSION"

TALENTAI_RELEASE_PACKAGE="$PWD/exports/private/TalentAI-phase45-mvp-v${TALENTAI_RELEASE_VERSION}.n8np"

test -s "$TALENTAI_RELEASE_PACKAGE"
shasum -a 256 "$TALENTAI_RELEASE_PACKAGE"
tar -tzf "$TALENTAI_RELEASE_PACKAGE"
```

Artifactهای `exports/private` تولیدشدنی و ignored هستند و نباید Commit شوند.
Release رسمی باید فقط از `main` تمیز و همگام، پس از موفقیت Gateها ساخته شود.
RC را Rename نکنید و Tag منتشرشده را جابه‌جا نکنید.

## عیب‌یابی کوتاه

### TAI-01 منتشر نمی‌شود

ابتدا TAI-02 و TAI-03 را Publish کنید؛ TAI-01 به هر دو Sub-workflow وابسته
است.

### Form با Login یا Token باز نمی‌شود

- Formهای HR به Login و Execute Access نیاز دارند؛
- Form کاندید به Token معتبر نیاز دارد؛
- Test URL فقط در حالت Listening معتبر است؛
- `/form-waiting/...` لینک دائمی نیست؛
- Host و Port باید با `N8N_WEBHOOK_URL` محیط یکسان باشند.

### Credential بعد از Recreate قابل خواندن نیست

`N8N_ENCRYPTION_KEY` محیط قبلی را بازیابی کنید. با کلید جدید Credential را
Save نکنید و Volume را حذف نکنید.

### خطای Permission دیتابیس

```bash
./scripts/apply-database.sh
./scripts/verify-phase1.sh
```

Workflow را برای دورزدن خطا به Role مدیریتی `admin` متصل نکنید.

### `INVALID_EXTRACTION_ID`

TAI-02 باید از TAI-01 یک `extractionId` واقعی دریافت کند. اجرای مستقیم آن بدون
ورودی معتبر تست End-to-End محسوب نمی‌شود.

### خطای Invitation

Expired، Revoked، Already Claimed، نامعتبر یا نامرتبط‌بودن Invitation باید به
Failure کنترل‌شده و پاک‌سازی‌شده منجر شود. Token خام یا جزئیات داخلی دیتابیس
را برای عیب‌یابی در کانال عمومی ارسال نکنید.

### Port اشغال است

```bash
lsof -nP -iTCP:5678 -sTCP:LISTEN
lsof -nP -iTCP:5434 -sTCP:LISTEN
```

در صورت نیاز `N8N_HOST_PORT` یا `POSTGRES_HOST_PORT` را فقط در `.env` محلی
تغییر دهید.

## سیاست امنیت و حریم خصوصی

- فقط از رزومهٔ ساختگی یا داده‌ای استفاده کنید که مجوز پردازش آن وجود دارد؛
- Formهای HR علاوه بر n8n authentication باید در Production محدودیت شبکه
  داشته باشند؛
- Candidate URL را فقط برای کاندید مربوط به همان دعوت ارسال کنید؛
- Token خام، Resume، Prompt و Answer text را در Log یا Issue عمومی نگذارید؛
- Credentialها فقط در n8n Credential Store نگه‌داری شوند؛
- PostgreSQL روی Loopback یا شبکهٔ خصوصی باقی بماند؛
- Runtime با `talentai_app` و Migration با Role مدیریتی اجرا شود؛
- `N8N_ENCRYPTION_KEY` پایدار، محرمانه و خارج از Git باشد؛
- Package و Checksum پیش از انتشار بررسی شوند؛
- Backup، Retention، HTTPS، SSO و Monitoring محیط Production باید جداگانه
  تعریف شوند.

## محدودیت‌های نسخهٔ فعلی

- اطلاعات رزومه ادعای کاندید است و اعتبار بیرونی آن بررسی نمی‌شود؛
- بخش‌های مبتنی بر LLM ممکن است تغییر محدود داشته باشند؛
- Decision اولیه فقط براساس Grade Guide و Dimension Scoreها محاسبه می‌شود؛
- Grade Guide مرجع فعلی مربوط به `JAVA_BACKEND` نسخه `1.0.0` است؛
- سامانه UI مستقل ندارد و از Formها و Editor مربوط به n8n استفاده می‌کند؛
- محدودسازی شبکهٔ HR، HTTPS، SSO، Backup policy، Queue scaling و Monitoring
  Production بخشی از Deployment سازمانی هستند و با Publish کردن Workflow
  به‌تنهایی ایجاد نمی‌شوند.

## منابع رسمی

- [n8n Docker Compose deployment](https://docs.n8n.io/deploy/host-n8n/install-options/use-a-cloud-provider/use-docker-compose/)
- [n8n encryption key configuration](https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/configuration-examples/set-a-custom-encryption-key/)
- [n8n endpoint environment variables](https://docs.n8n.io/deploy/host-n8n/configure-n8n/basic-configuration/use-environment-variables/endpoints/)
- [n8n Form Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.formtrigger/)
- [n8n packages](https://docs.n8n.io/build/manage-workflows/n8n-packages/)
- [Import an n8n package](https://docs.n8n.io/build/manage-workflows/n8n-packages/import-a-package/)
- [PostgreSQL JSON functions](https://www.postgresql.org/docs/current/functions-json.html)

## مجوز و مالکیت

این پروژه برای استفادهٔ داخلی تیم TalentAI تهیه شده است. پیش از انتشار عمومی،
سیاست مالکیت کد، مجوز استفاده، داده‌های نمونه و الزامات حریم خصوصی سازمان باید
مشخص شوند.
