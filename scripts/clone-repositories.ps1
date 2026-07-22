$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SuperprojectRoot = Split-Path -Parent $ProjectRoot
$GitLabHost = if ($env:GITLAB_HOST) { $env:GITLAB_HOST } else { "gitlab.com" }
$GitLabNamespace = if ($env:GITLAB_NAMESPACE) { $env:GITLAB_NAMESPACE } else { "travel-platform2" }
$GitLabBaseUrl = "https://$GitLabHost/$GitLabNamespace"
$Repositories = @(
    "tourism-mobile",
    "tourism-backend",
    "tourism-infrastructure",
    "tourism-documentation"
)

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Обязательная команда '$Name' не найдена."
    }
}

Assert-Command -Name "git"
Assert-Command -Name "glab"

& git -C $ProjectRoot rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) {
    throw "'$ProjectRoot' не является Git-репозиторием."
}

$DetectedSuperprojectRoot = & git -C $SuperprojectRoot rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or $DetectedSuperprojectRoot -ne $SuperprojectRoot) {
    throw "'$SuperprojectRoot' не является Git superproject."
}

& glab auth status --hostname $GitLabHost *> $null
if ($LASTEXITCODE -ne 0) {
    throw "GitLab CLI не авторизован. Выполните 'glab auth login'."
}

Write-Host "Проверка репозиториев namespace $GitLabNamespace..."
foreach ($Repository in $Repositories) {
    $Target = Join-Path $SuperprojectRoot $Repository
    if (Test-Path -LiteralPath $Target) {
        Write-Host "Пропуск $Target`: каталог уже существует и не будет перезаписан."
        continue
    }

    & glab api "projects/$GitLabNamespace%2F$Repository" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Репозиторий $GitLabNamespace/$Repository недоступен или ещё не создан."
    }
}

foreach ($Repository in $Repositories) {
    $Target = Join-Path $SuperprojectRoot $Repository
    if (Test-Path -LiteralPath $Target) {
        continue
    }

    Write-Host "Добавление submodule $Repository..."
    & git -C $SuperprojectRoot submodule add `
        "$GitLabBaseUrl/$Repository.git" `
        $Repository
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось добавить submodule $GitLabNamespace/$Repository."
    }
}

Write-Host "Готово. Проверьте .gitmodules и submodule pointers в $SuperprojectRoot."
