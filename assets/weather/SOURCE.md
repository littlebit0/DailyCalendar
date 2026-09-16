# KMA Region Index

Source: Korea Meteorological Administration (KMA), district forecast coordinates,
2026 Q2, published 2026-07-01.

https://data.kma.go.kr/community/board/detailBoard.do?bbrdTypeNo=4&bbrdNo=68822&pgmNo=92

Original workbook: `동네예보지점좌표(위경도)_260701.xlsx`.
The JSON contains the published Korean district names, codes, grid coordinates,
and representative latitude/longitude. No user location data is included.

Regenerate with `python3 tool/import_kma_regions.py <workbook> assets/weather/kma_regions.json`.
Forecast source: https://www.weather.go.kr/plus/rss.jsp (KMA XML/RSS, attribution required).
