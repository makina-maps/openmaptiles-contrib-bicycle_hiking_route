# OpenMapTiles contrib layers Bicycle & Hiking routes

This project is an [OpenMapTiles](https://github.com/openmaptiles/openmaptiles) add-on layers.

It adds the data layers:

* bicycle_hiking_route containing linestring routes for bicycle and hiking with defined network, name and ref.

Git-clone this project on the root the the OpenMapTiles project:
```
git clone https://github.com/makina-maps/openmaptiles-contrib-bicycle_hiking_route.git layers_bicycle_hiking_route
```

Use the layer definition from `bicycle_hiking_route/route.yaml` on your own tileset definition or the pre-set configuration `openmaptiles.yaml` by changing `TILESET_DEF` from the OpenMapTiles `.env` to `layers_bicycle_hiking_route/openmaptiles.yaml`.

## Styles

This layer is know to used by the [osm-bright-bicycle-gl-style](https://github.com/makina-maps/osm-bright-bicycle-gl-style).

# License

All code in this repository is under the BSD license and the cartography decisions encoded in the schema and SQL are licensed under CC-BY.

There is no extra requirement of attribution to this layer than the default OpenMapTiles License.
