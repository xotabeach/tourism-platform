# Routes data model (Phase 4)

Единый `Route` с дискриминатором `source`. Phase 4 реализует только
публичные `source=editorial`.

## ER

```mermaid
erDiagram
  regions ||--o{ routes : contains
  routes ||--o{ route_stops : ordered
  routes ||--o{ route_reviews : receives
  users ||--o{ route_reviews : authors
  route_reviews o|--o{ route_reviews : replied_to
  places ||--o{ route_stops : referenced
  place_entrances ||--o| route_stops : optional
```

## Public catalog invariant

API отдаёт маршрут только если одновременно:

- `source = editorial`
- `visibility = public`
- `lifecycle_status = active`
- минимум 2 stops (seed / editorial content rule)

## Tables

### routes

Ключевые поля: `region_id`, `owner_user_id` (null для editorial), `name`,
`slug`, `source`, `visibility`, `lifecycle_status`, duration/distance,
`difficulty`, `transport_mode`, `seasonality`, `geometry` (LINESTRING),
editorial source/freshness, timestamps.

### route_stops

`route_id`, `place_id`, optional `place_entrance_id`, `position` (≥1, unique
per route), `visit_duration_minutes`, `note`, `is_optional`.

### route_reviews (as-built)

`route_id`, `author_user_id`, `body` (до 2000), `rating` (1–5), moderation
`status`, optional `moderator_note`/`moderated_at`, timestamps и nullable
self-FK `reply_to_review_id` (`ON DELETE SET NULL`). Фотографии не хранятся
в строке отзыва: активные элементы находятся в `media_attachments` с
`entity_type=review`, `role=gallery`, порядком `sort_order` и owner-bound
upload metadata.

## API

- `GET /api/v1/routes` — filters: `region_slug`, `transport_mode`,
  `difficulty`, `q`; pagination `limit`/`offset`
- `GET /api/v1/routes/{id}` — detail + ordered stops with place snapshot
- `GET/POST /api/v1/routes/{id}/reviews` — published list / pending submit;
  POST принимает optional `reply_to_review_id`
- `POST/DELETE /api/v1/routes/{id}/reviews/{review_id}/media[/media_id]` —
  owner-only review images

## Seed

`data/crimea_seed.json` → `routes[]` (3 editorial routes). Idempotent via
`scripts/seed_crimea.py`.
