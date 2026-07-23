# Python code style

Для `tourism-backend`. Инструменты: Ruff (format + lint), MyPy strict,
Pyright/Pylance `standard` в IDE. См. также
[development-environment.md](development-environment.md),
[python-testing-guide.md](python-testing-guide.md).

## Naming

| Вид | Стиль | Пример |
| --- | --- | --- |
| Modules/packages | snake_case | `places/application/service.py` |
| Classes | PascalCase | `PlaceService` |
| Functions/vars | snake_case | `list_places` |
| Constants | UPPER_SNAKE | `DEFAULT_LIMIT` |
| Pydantic schemas | PascalCase + suffix | `PlaceDetailResponse` |

## Imports

1. stdlib → blank → third-party → blank → project (`tourism_backend...`).
2. Абсолютные импорты между packages; relative только внутри малого package.
3. Запрет `from x import *`.
4. Ruff `I` сортирует imports.

```python
# GOOD
from uuid import UUID

from fastapi import APIRouter
from sqlalchemy.ext.asyncio import AsyncSession

from tourism_backend.modules.places.application.schemas import PlaceDetail

# BAD
from tourism_backend.modules.places.application.schemas import *
```

## Type annotations

- Публичные функции application/domain: типы аргументов и return.
- Не возвращать «голый» `dict`, если структура известна — Pydantic/TypedDict.
- `Any` в domain/application — только с обоснованием; не как обход MyPy.
- `type: ignore` / `noqa` — только с кодом ошибки и комментарием причины.

```python
# GOOD
async def get_place(session: AsyncSession, place_id: UUID) -> PlaceDetail: ...

# BAD
async def get_place(session, place_id):  # type: ignore
    ...
```

## Async

- I/O — `async def`; не блокировать event loop sync DB/HTTP.
- Не открывать DB/Redis/HTTP clients на import-time.

## Exceptions

- Domain/application exceptions ≠ HTTP exceptions.
- Presentation maps domain errors → API envelope.
- Не глотать `except Exception:` без log/re-raise/boundary handling.

## Logging

- `logging` / structured JSON logger; не `print`.
- Без secrets, tokens, избыточного PII.

## Pydantic / SQLAlchemy

- Pydantic на API boundaries (`application/schemas.py`).
- Domain/application не импортируют FastAPI.
- Domain/application не импортируют provider SDK (Google GenAI и т.п.).
- SQLAlchemy models — `infrastructure/`; без cross-module `relationship()` (ADR-001).

## Datetime / UUID / Enum

- timezone-aware `datetime` (UTC в persistence предпочтительно).
- UUID для entity ids.
- Enum / Literal вместо magic strings в публичных контрактах.

## Structure

- Тонкие routers; логика в services.
- Функции держать обозримыми; выносить helpers.
- Dependency direction: presentation → application → domain; infrastructure
  реализует ports.

## Prohibited

- Mutable default args (`def f(x=[])`).
- Business logic at import time.
- Bare `noqa` / bare `type: ignore`.
- Editing `uv.lock` by hand.
