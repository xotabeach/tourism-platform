# Security policy

## Поддерживаемая версия

Проект не имеет production-релиза. Есть constrained **test** contour и
as-built auth (OTP/JWT), SQLAdmin, FCM. Исправления безопасности — ветка
`main`.

## Канонические security docs

Политики, threat model, checklists и incident response:

[docs/security/security-baseline.md](docs/security/security-baseline.md)

## Сообщение об уязвимости

Не публикуйте сведения об уязвимости, токены, персональные данные или шаги
эксплуатации в публичном issue. Используйте private vulnerability reporting
репозитория после его включения владельцами организации.

Если private reporting ещё недоступен, свяжитесь с владельцем репозитория по
заранее согласованному приватному каналу. Контакт не фиксируется в репозитории,
пока не определён официальный security contact проекта.

В сообщении укажите:

- затронутый компонент и версию;
- условия воспроизведения;
- возможное влияние;
- минимальный proof of concept без реальных пользовательских данных;
- предложенное исправление, если оно известно.

## Секреты

- В Git разрешено хранить только `.env.example` с локальными значениями.
- Production credentials, API keys, signing keys и access tokens запрещены.
- Обнаруженный секрет должен быть немедленно отозван; удаления строки из Git
  недостаточно.
- Legacy API keys не должны использоваться или переноситься.
- См. [docs/security/secrets-management.md](docs/security/secrets-management.md).

## Scope проверок

Security Baseline (docs + local/full CI jobs) существует; на test host есть
auth, admin cookie session, input limits. RLS, prod NetworkPolicy, staging
DAST — по фазам. Не считать проект «полностью защищённым» из‑за документации.
