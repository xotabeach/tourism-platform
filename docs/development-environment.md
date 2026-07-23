# Development environment

Воспроизводимая среда для Crimea Travel Platform (workspace + submodules).
Аналогия с PHP: `pyproject.toml` ≈ `composer.json`, `uv.lock` ≈ `composer.lock`,
`uv sync` ≈ `composer install`, `.venv` ≈ isolated vendor env;
`pubspec.yaml` / `pubspec.lock` — Flutter dependency manifest + lock.

Канон docs: этот каталог (`tourism-platform/docs/`).

## 1. Requirements

- Git, Docker (для Compose PostGIS/Redis)
- [uv](https://docs.astral.sh/uv/)
- Python 3.13 (см. `tourism-backend/.python-version`)
- Flutter stable (SDK constraint в `tourism-mobile/pubspec.yaml`)
- Cursor / VS Code с recommended extensions

## 2–4. uv and Python

```bash
# install uv: https://docs.astral.sh/uv/getting-started/installation/
cd tourism-backend
cat .python-version   # 3.13
uv sync --all-extras --dev
uv sync --frozen      # CI / reproducible
```

Interpreter: `tourism-backend/.venv/bin/python` (выбрать в Cursor).

## 5. Run backend

```bash
# from tourism-platform
make up

cd ../tourism-backend
cp .env.example .env   # local only
uv run alembic upgrade head
uv run python scripts/seed_crimea.py
uv run tourism-backend
```

## 6–8. Dependencies (backend)

```bash
uv add <package>           # runtime → pyproject + lock
uv add --dev <package>     # or edit [project.optional-dependencies] dev
uv lock / uv sync          # refresh lock; commit uv.lock
```

Не создавать параллельный `requirements.txt` как source of truth.
Не править `uv.lock` руками.

## 9–10. Cursor extensions and interpreter

Расширения **не устанавливались автоматически** (в agent-окружении нет
`cursor --install-extension`). В репозитории только **recommendations**.

### Как поставить у себя (один раз)

1. Открой файл `mobile_travel_app.code-workspace` через **File → Open Workspace from File…**
2. Cursor покажет баннер *“This workspace has extension recommendations”* → **Install All**
   или: Extensions → фильтр `@recommended` → Install.
3. Список:
   - Python, Pylance, Ruff
   - Dart, Flutter
   - Even Better TOML, YAML, EditorConfig
4. Python interpreter: Command Palette → **Python: Select Interpreter** →
   `tourism-backend/.venv/bin/python` (сначала `cd tourism-backend && uv sync --all-extras --dev`).

Подробнее: этот же файл, разделы ниже.

### Ложная ошибка `flutter_lldb_helper.py` / `import lldb`

Это **не баг проекта**. Файл генерирует Flutter в `ios/Flutter/ephemeral/`
(в `.gitignore`) для отладки iOS в Xcode. Модуль `lldb` есть только внутри
LLDB Xcode, не в обычном Python. Workspace исключает `ephemeral` из
Pylance/поиска — после Reload Window ошибка должна пропасть.

## 11–14. Ruff, Pylance, MyPy, Pytest

```bash
cd tourism-backend
uv run ruff format .
uv run ruff format --check .
uv run ruff check .
uv run ruff check . --fix
uv run mypy src/tourism_backend
uv run pytest
uv run pytest --cov=tourism_backend --cov-report=term-missing
./scripts/validate.sh
# or from workspace: make backend-check
```

- **Ruff** — format + lint + import sort (не Black/isort/flake8).
- **Pylance/Pyright** — `typeCheckingMode=standard` в workspace settings /
  `[tool.pyright]` в pyproject.
- **MyPy** — `strict = true` в CI (не ослаблять без ADR).

## 15–19. Flutter

```bash
flutter doctor
cd tourism-mobile
flutter pub get
flutter pub outdated
dart format lib test
flutter analyze --fatal-infos
flutter test
flutter run
./scripts/validate.sh
# or: make mobile-check
```

Freezed/build_runner — Phase 5; до этого hand-written models.

## 20. All local checks

```bash
# workspace root
make check          # platform validate + backend + mobile
make backend-check
make mobile-check
```

## 21. Troubleshooting

| Symptom | Fix |
| --- | --- |
| Unresolved Python imports | Select `.venv` interpreter; `uv sync` |
| Wrong interpreter | Clear Python path; pick `tourism-backend/.venv` |
| Stale uv env | `rm -rf .venv && uv sync --all-extras --dev` |
| Missing Dart generated files | Phase 5+: `dart run build_runner build --delete-conflicting-outputs` |
| build_runner conflicts | delete conflicting outputs, regenerate; don't hand-edit |
| Flutter SDK not found | Install Flutter; ensure `flutter` on PATH; reopen workspace |
| PostGIS tests fail | `make up` in platform; ports `5433`/`6380` per `.env.example` |

## Make targets (workspace)

| Target | Action |
| --- | --- |
| `backend-sync` | `uv sync --all-extras --dev` |
| `backend-format` | ruff format |
| `backend-lint` | ruff check |
| `backend-typecheck` | mypy |
| `backend-test` | pytest |
| `backend-check` | `./scripts/validate.sh` |
| `mobile-get` | `flutter pub get` |
| `mobile-format` | dart format check |
| `mobile-analyze` | flutter analyze --fatal-infos |
| `mobile-test` | flutter test |
| `mobile-check` | mobile validate.sh |
| `check` | platform + backend + mobile validates |
