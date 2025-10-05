API‑клиент

NavigationAPIClient
- Предоставляет типизированные методы:
  - Маршрутизация: POST /routing/7.0.0/global
  - Map matching: POST /map_matching/1.0.0
  - Радарная геолокация: POST /v2/geolocation
- Кодирование/декодирование JSON настроено на snake_case.

Модели
- RouteRequest/Response, Maneuver, SegmentGeometry.
- MapMatchRequest/Response и связанные структуры.
- GeolocationRequest/Response для радарной геолокации.

Ошибки
- Явно обрабатываются: неверный URL, HTTP‑ошибки со статус‑кодами и ошибки декодирования (с локализованными описаниями).

Отладочные логи
- В сборке DEBUG запросы и ответы печатаются в консоль.
