param(
  [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'

if ($EnvFile -and (Test-Path -LiteralPath $EnvFile)) {
  Get-Content -LiteralPath $EnvFile | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
      $envName = $Matches[1]
      $envValue = $Matches[2].Trim()
      if ($envValue.StartsWith('"') -and $envValue.EndsWith('"') -and $envValue.Length -ge 2) {
        $envValue = $envValue.Substring(1, $envValue.Length - 2)
      }
      if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($envName))) {
        [Environment]::SetEnvironmentVariable($envName, $envValue, 'Process')
      }
    }
  }
}

$requiredVariables = @(
  'POSTGRES_USER'
  'POSTGRES_PASSWORD'
  'POSTGRES_DB'
  'POSTGRES_NON_ROOT_USER'
  'POSTGRES_NON_ROOT_PASSWORD'
  'TALENTAI_DB_PASSWORD'
)

foreach ($requiredVariable in $requiredVariables) {
  if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($requiredVariable))) {
    Write-Error "Required environment variable is missing: $requiredVariable"
    exit 1
  }
}

$talentaiDatabase = 'talentai'
$talentaiAppUser = 'talentai_app'

$postgresUser = $env:POSTGRES_USER
$postgresPassword = $env:POSTGRES_PASSWORD
$postgresDb = $env:POSTGRES_DB
$n8nUser = $env:POSTGRES_NON_ROOT_USER
$n8nPassword = $env:POSTGRES_NON_ROOT_PASSWORD
$talentaiPassword = $env:TALENTAI_DB_PASSWORD

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  Write-Error 'psql was not found in PATH. Install the PostgreSQL client tools first.'
  exit 1
}

$connectionArgs = @()
if (-not [string]::IsNullOrEmpty($env:PGHOST)) {
  $connectionArgs += @('--host', $env:PGHOST)
}
if (-not [string]::IsNullOrEmpty($env:PGPORT)) {
  $connectionArgs += @('--port', $env:PGPORT)
}
elseif (-not [string]::IsNullOrEmpty($env:POSTGRES_HOST_PORT)) {
  $connectionArgs += @('--port', $env:POSTGRES_HOST_PORT)
}

$initSql = @'
SELECT format(
  'CREATE ROLE %I LOGIN PASSWORD %L',
  :'n8n_user',
  :'n8n_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'n8n_user'
)
\gexec

SELECT format(
  'CREATE ROLE %I LOGIN PASSWORD %L',
  :'talentai_user',
  :'talentai_password'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'talentai_user'
)
\gexec

SELECT format(
  'CREATE DATABASE %I OWNER %I',
  :'talentai_database',
  :'postgres_admin'
)
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = :'talentai_database'
)
\gexec

SELECT format(
  'GRANT ALL PRIVILEGES ON DATABASE %I TO %I',
  :'n8n_database',
  :'n8n_user'
)
\gexec

SELECT format(
  'GRANT CONNECT ON DATABASE %I TO %I',
  :'talentai_database',
  :'talentai_user'
)
\gexec
'@

$schemaGrantSql = @'
SELECT format(
  'GRANT USAGE, CREATE ON SCHEMA public TO %I',
  :'n8n_user'
)
\gexec
'@

$previousPgPassword = $env:PGPASSWORD
$env:PGPASSWORD = $postgresPassword
try {
  $initSql | & psql @connectionArgs -v ON_ERROR_STOP=1 --username $postgresUser --dbname postgres `
    "--set=n8n_database=$postgresDb" `
    "--set=n8n_user=$n8nUser" `
    "--set=n8n_password=$n8nPassword" `
    "--set=talentai_database=$talentaiDatabase" `
    "--set=talentai_user=$talentaiAppUser" `
    "--set=talentai_password=$talentaiPassword" `
    "--set=postgres_admin=$postgresUser"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $schemaGrantSql | & psql @connectionArgs -v ON_ERROR_STOP=1 --username $postgresUser --dbname $postgresDb "--set=n8n_user=$n8nUser"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $migrationFiles = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'database\migrations') -Filter '*.sql' -File | Sort-Object Name)

  if ($migrationFiles.Count -eq 0) {
    Write-Error 'No TalentAI database migrations were found.'
    exit 1
  }

  foreach ($migrationFile in $migrationFiles) {
    Write-Host "Applying TalentAI migration: $($migrationFile.Name)"
    & psql @connectionArgs -v ON_ERROR_STOP=1 --username $postgresUser --dbname $talentaiDatabase --file $migrationFile.FullName
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  $seedFiles = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'database\seeds') -Filter '*.sql' -File | Sort-Object Name)

  foreach ($seedFile in $seedFiles) {
    Write-Host "Applying TalentAI seed: $($seedFile.Name)"
    & psql @connectionArgs -v ON_ERROR_STOP=1 --username $postgresUser --dbname $talentaiDatabase --file $seedFile.FullName
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  Write-Host 'PostgreSQL initialization for n8n and TalentAI completed.'
}
finally {
  $env:PGPASSWORD = $previousPgPassword
}
