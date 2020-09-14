# OpenMapTiles extra layers Bicycle & Hiking routes

This project is an [OpenMapTiles](https://github.com/openmaptiles/openmaptiles) add-on layers.

It adds the data layer:

* `route_bicycle_hiking`: containing linestring routes for bicycle and hiking with defined network, name and ref.

Git-clone this project on the root the the OpenMapTiles project:
```
git clone https://github.com/makina-maps/openmaptiles-layer-route_bicycle_hiking.git layers_extra/bicycle_hiking_route
```

Add the layer definition from `layers_extra/route_bicycle_hiking/route.yaml` on your own `openmaptiles.yaml` tileset definition. Change `TILESET_FILE` from the OpenMapTiles `.env` to point on it.

## Styles

This layer is know to used by the [osm-bright-bicycle-gl-style](https://github.com/makina-maps/osm-bright-bicycle-gl-style).

# License

All code in this repository is under the BSD license and the cartography decisions encoded in the schema and SQL are licensed under CC-BY.

There is no extra requirement of attribution to this layer than the default OpenMapTiles License.
