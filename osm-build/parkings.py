"""Public car parks of Crimea as GeoJSON points (spec 14b, section 1).

Reads the same extract the graph and tiles are built from. Nodes are taken
as they are; car parks drawn as areas become the average of their outline.
Private and customers-only car parks are left out: a route must not send
people to a gate they cannot pass.

  python parkings.py crimea.osm.pbf parkings.geojson
"""

from __future__ import annotations

import json
import sys

import osmium

_CLOSED_ACCESS = {"private", "customers", "no", "permit", "delivery", "bus"}


def _wanted(tags: osmium.osm.TagList) -> bool:
    if tags.get("amenity") != "parking":
        return False
    if tags.get("access", "yes") in _CLOSED_ACCESS:
        return False
    # Bicycle and motorcycle parking share the tag.
    return tags.get("parking") not in {"bicycle", "motorcycle"}


def _properties(kind: str, osm_id: int, tags: osmium.osm.TagList) -> dict[str, object]:
    capacity = tags.get("capacity")
    return {
        "osm_id": f"{kind}{osm_id}",
        "access": tags.get("access"),
        "fee": tags.get("fee"),
        "capacity": int(capacity) if capacity and capacity.isdigit() else None,
        "name": tags.get("name:ru") or tags.get("name"),
    }


class _Parkings(osmium.SimpleHandler):
    def __init__(self) -> None:
        super().__init__()
        self.features: list[dict[str, object]] = []

    def _add(self, lon: float, lat: float, properties: dict[str, object]) -> None:
        self.features.append(
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [round(lon, 7), round(lat, 7)]},
                "properties": properties,
            }
        )

    def node(self, n: osmium.osm.Node) -> None:
        if _wanted(n.tags) and n.location.valid():
            self._add(n.location.lon, n.location.lat, _properties("n", n.id, n.tags))

    def way(self, w: osmium.osm.Way) -> None:
        if not _wanted(w.tags):
            return
        points = [(nd.lon, nd.lat) for nd in w.nodes if nd.location.valid()]
        if len(points) > 1 and points[0] == points[-1]:
            points = points[:-1]
        if not points:
            return
        lon = sum(p[0] for p in points) / len(points)
        lat = sum(p[1] for p in points) / len(points)
        self._add(lon, lat, _properties("w", w.id, w.tags))


def main() -> None:
    source, target = sys.argv[1], sys.argv[2]
    handler = _Parkings()
    handler.apply_file(source, locations=True)
    with open(target, "w", encoding="utf-8") as out:
        json.dump(
            {"type": "FeatureCollection", "features": handler.features},
            out,
            ensure_ascii=False,
        )
    print(f"parkings: {len(handler.features)}")


if __name__ == "__main__":
    main()
