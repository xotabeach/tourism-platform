"""Public transport lines of Crimea from OSM (spec 12b, section 1).

Every `type=route` relation for a bus, trolleybus, tram, train, share taxi
or ferry becomes a line variant (one direction) with its ordered stops and
its shape along the road; `route_master` relations group variants into a
line. Lines without PTv2 tagging are kept but flagged: their stop order
cannot be trusted, so they are not planned on until fixed (D8).

Two passes over the extract: the first collects the relations and the ids
they need, the second the stop coordinates and the way geometries.

  python transit.py crimea.osm.pbf transit.json
"""

from __future__ import annotations

import json
import sys

import osmium

KINDS = {"bus", "trolleybus", "tram", "train", "share_taxi", "minibus", "ferry"}
STOP_ROLES = {"stop", "stop_entry_only", "stop_exit_only"}
PLATFORM_ROLES = {"platform", "platform_entry_only", "platform_exit_only"}
LINE_TAGS = ("ref", "name", "from", "to", "operator", "network", "interval",
             "opening_hours", "duration", "colour", "charge")


class _Relations(osmium.SimpleHandler):
    def __init__(self) -> None:
        super().__init__()
        self.routes: dict[int, dict] = {}
        self.masters: dict[int, dict] = {}
        self.nodes: set[int] = set()
        self.ways: set[int] = set()

    def relation(self, r: osmium.osm.Relation) -> None:
        tags = r.tags
        if tags.get("type") == "route" and tags.get("route") in KINDS:
            members = [(m.type, m.ref, m.role) for m in r.members]
            self.routes[r.id] = {
                "osm_id": r.id,
                "kind": "bus" if tags.get("route") == "minibus" else tags.get("route"),
                "ptv2": tags.get("public_transport:version") == "2",
                **{key: tags.get(key) for key in LINE_TAGS if tags.get(key)},
                "members": members,
            }
            for kind, ref, role in members:
                if kind == "n":
                    self.nodes.add(ref)
                elif kind == "w" and role in ("", "forward", "backward"):
                    self.ways.add(ref)
        elif tags.get("type") == "route_master":
            self.masters[r.id] = {
                "osm_id": r.id,
                **{key: tags.get(key) for key in ("ref", "name", "operator", "network")
                   if tags.get(key)},
                "routes": [m.ref for m in r.members if m.type == "r"],
            }


class _Geometry(osmium.SimpleHandler):
    def __init__(self, nodes: set[int], ways: set[int]) -> None:
        super().__init__()
        self.want_nodes = nodes
        self.want_ways = ways
        self.nodes: dict[int, dict] = {}
        self.ways: dict[int, list[list[float]]] = {}

    def node(self, n: osmium.osm.Node) -> None:
        if n.id in self.want_nodes and n.location.valid():
            self.nodes[n.id] = {
                "lng": round(n.location.lon, 7),
                "lat": round(n.location.lat, 7),
                "name": n.tags.get("name:ru") or n.tags.get("name"),
            }

    def way(self, w: osmium.osm.Way) -> None:
        if w.id in self.want_ways:
            self.ways[w.id] = [
                [round(nd.lon, 6), round(nd.lat, 6)] for nd in w.nodes if nd.location.valid()
            ]


def _chain(parts: list[list[list[float]]]) -> list[list[float]]:
    """Join the route's ways end to end, flipping a way (or the first one)
    when its ends meet the line the other way round."""
    line: list[list[float]] = []
    for part in parts:
        if not part:
            continue
        if not line:
            line = list(part)
        elif part[0] == line[-1]:
            line.extend(part[1:])
        elif part[-1] == line[-1]:
            line.extend(reversed(part[:-1]))
        elif part[0] == line[0]:
            # Only possible after the first way: it was drawn backwards.
            line = list(reversed(line)) + part[1:]
        elif part[-1] == line[0]:
            line = list(reversed(line)) + list(reversed(part[:-1]))
        else:
            # A gap in the relation: keep going, the shape stays approximate.
            line.extend(part)
    return line


def main() -> None:
    source, target = sys.argv[1], sys.argv[2]
    relations = _Relations()
    relations.apply_file(source)
    geometry = _Geometry(relations.nodes, relations.ways)
    geometry.apply_file(source, locations=True)

    variants = []
    for route in relations.routes.values():
        def members(roles: set[str]) -> list[dict]:
            return [
                {"osm_id": f"n{ref}", "role": role, **geometry.nodes[ref]}
                for kind, ref, role in route["members"]
                if kind == "n" and role in roles and ref in geometry.nodes
            ]

        # Stop positions when mapped; many PTv2 routes list only platforms.
        stops = members(STOP_ROLES) or members(PLATFORM_ROLES)
        shape = _chain([
            geometry.ways.get(ref, [])
            for kind, ref, role in route["members"]
            if kind == "w" and role in ("", "forward", "backward")
        ])
        route = {key: value for key, value in route.items() if key != "members"}
        variants.append({**route, "stops": stops, "shape": shape})

    with open(target, "w", encoding="utf-8") as out:
        json.dump(
            {"variants": variants, "masters": list(relations.masters.values())},
            out,
            ensure_ascii=False,
        )
    print(f"transit: {len(variants)} variants, {len(relations.masters)} lines grouped")


if __name__ == "__main__":
    main()
