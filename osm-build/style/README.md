# Стиль карты КрымТрип

`crimeatrip.json` — стиль для tileserver-gl на векторных тайлах OpenMapTiles
(собираются `../build.sh`). Основа — стиль basic-preview из tileserver-gl-styles,
цвета и подписи подогнаны под приложение: русские названия, без номеров домов
и значков. Шрифт — встроенный в образ tileserver-gl «Noto Sans Regular».

`config.json` — конфиг tileserver-gl: стиль из этой папки, тайлы из
`/data/tiles/crimea.mbtiles` (на сервере это `osm/current/tiles`).

Бэкенд запрашивает у tileserver-gl только подложку; линию маршрута, пины и
атрибуцию «© участники OpenStreetMap» рисует сам (спека 12a, раздел 3).
