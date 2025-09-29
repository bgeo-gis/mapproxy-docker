# Mapproxy Docker

This guide will help you set up a running instance of Mapproxy. This instance consists of:

- `mapproxy-service`: Mapproxy with custom endpoints for seeding and managing updates.
- `mapproxy-docker`: (this repository) Mapproxy integrated with internal Nginx and QGIS Server.

## Prerequisites

- Docker
- Nginx

> **Note:** The following installation steps may vary depending on your system or may be outdated. If the required software is already installed, you can skip these steps.

## Install Docker (Debian)

1. Update the package index and install required dependencies:
   ```sh
   sudo apt-get update
   sudo apt-get install ca-certificates curl gnupg
   ```
2. Add Docker’s official GPG key:
   ```sh
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   sudo chmod a+r /etc/apt/keyrings/docker.gpg
   ```
3. Set up the Docker repository:
   ```sh
   echo \
   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
   $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```
4. Update the package index:
   ```sh
   sudo apt-get update
   ```
5. Install Docker Engine, containerd, and Docker Compose:
   ```sh
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
6. Verify the installation:
   ```sh
   sudo docker run hello-world
   ```

## Install Docker (Ubuntu Server)

1. Update the package index and install dependencies:
   ```sh
   sudo apt-get update
   sudo apt install apt-transport-https ca-certificates curl software-properties-common
   ```
2. Add Docker’s official GPG key:
   ```sh
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
   ```
3. Add the Docker repository:
   ```sh
   sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
   ```
4. Update the package index:
   ```sh
   sudo apt-get update
   ```
5. Install Docker Engine, containerd, and Docker Compose:
   ```sh
   sudo apt install docker-ce docker-ce-cli containerd.io
   ```
6. Verify the installation:
   ```sh
   sudo docker run hello-world
   ```

## Clone Repository and Further Steps

1. Clone the repository in the desired directory (e.g., `/opt`):
   ```sh
   git clone --recursive https://github.com/bgeo-gis/mapproxy-docker.git
   ```
2. Set permissions for the volumes directory:
   ```sh
   sudo chown -R 33:33 mapproxy-docker/docker/volumes
   ```
3. Modify the host configuration in `api-gateway/nginx.conf` to match your machine’s IP address or domain name:
   ```nginx
   location ~ ^/mapproxy {
       proxy_set_header Host localhost; # Change this line
       proxy_set_header X-Forwarded-Proto https;
       proxy_pass http://mapproxy-bgeo:9090;
   }
   ```

## Docker Compose Configuration

The `docker-compose.yaml` file defines three containers:

- `mapproxy-bgeo`: Runs Mapproxy.
- `qwc-qgis-server`: QGIS Server instance used by Mapproxy as a source.
- `qwc-api-gateway`: Internal Nginx.

### Configure Storage Directories

In the `mapproxy-bgeo` container, configure the directories for storing configuration files and generated tiles. Replace `example` with an appropriate name (e.g., your organization’s name):

```yaml
./volumes/mapproxy/tiles/example:/srv/qwc_service/mapproxy/tiles
./volumes/mapproxy/config/example:/srv/qwc_service/mapproxy/config
```

> **Note:** The default directory for storing tiles is `./volumes/mapproxy/tiles/`. You can change it as needed. We recommend using a large and fast SSD (>1GB/s read/write) to improve performance.

Set permissions for `www-data` on the tile directory. Use ACL as follows:

```sh
sudo apt-get install -y acl
sudo setfacl -R -m d:u:www-data:rwx /volumes/mapproxy/tiles
```
> **Note:** If you changed the tile directory to point to another disk or location, set the permissions there.

> **Example: Changing the tile directory to an external disc mounted on `/mnt/tiles`:**
>
> On `mapproxy-bgeo` in `docker-compose.yaml`:
>
> ```yaml
> /mnt/tiles/bgeo:/srv/qwc_service/mapproxy/tiles
> ```
> Set permissions:
>
> ```sh
> sudo setfacl -R -m d:u:www-data:rwx /mnt/tiles
> ```


Similarly, in `qwc-qgis-server`, set the directory for storing QGIS projects if desired, although we recommend using the default value:

```yaml
./qgis-projects:/data:rw
```



## Nginx Configuration (external)

1. Install Nginx:
   ```sh
   sudo apt install nginx
   ```
2. Create a configuration file (`<host>.conf`) in `/etc/nginx/sites-available`:
   ```nginx
   server {
       listen 80;
       server_name <host>;
       proxy_read_timeout 1d;
       allow 10.10.10.10; # QWC2 Server IP
       deny all;

       location / {
           proxy_pass http://localhost:8089/;
       }
   }
   ```
   To restrict access, allow only QWC2's server by using the `allow` and `deny` directives and configuring QWC2 accordingly, using the Mapproxy Proxy Auth service.

3. Create a symbolic link to enable the site:
   ```sh
   sudo ln -s /etc/nginx/sites-available/<host>.conf /etc/nginx/sites-enabled/
   ```
4. Restart Nginx:
   ```sh
   sudo systemctl restart nginx
   ```

## Mapproxy Configuration

### Database Setup

Mapproxy requires a `tiled` schema in your PostgreSQL database. Follow the `ddl/tiled.sql` file (included in this repository) to:

1. Create the schema `tiled` and the user `tileuser`.
2. Create the required materialized views (`ws_t_node`, `ws_t_arc`, `ws_t_connec`, `ws_t_link`).
3. Create the `tilecluster` materialized view (`ws_t_tileclusters`).

> **Note:** Creating or refreshing the `tilecluster` materialized view may take several minutes.

4. Create the `logs` tables:
   ```sql
   -- Table for storing logs of updates tile generation
   CREATE TABLE tiled.logs (
      id SERIAL PRIMARY KEY,
      process_id VARCHAR(255) NOT NULL,
      tilecluster_id VARCHAR(255) NOT NULL,
      project_id VARCHAR(255) NOT NULL,
      start_time TIMESTAMP NOT NULL,
      end_time TIMESTAMP,
      geometry GEOMETRY NOT NULL
   );


   -- Table for storing the last seed time for each project
   CREATE TABLE tiled.last_seed_time (
      id varchar(255) NOT NULL,
      last_seed timestamp NOT NULL,
      CONSTRAINT last_seed_time_pkey PRIMARY KEY (id)
   );
   ```

### PostgreSQL Service Configuration

Edit the `pg_service.conf` file to point to the data BD:

```ini
[giswater_service_example]
host=<host>
port=<port>
dbname=<data_db>
user=tileuser
password=<password>
```

This service configuration will be used for Mapproxy and QGIS Server.

> **Note:** For big databases with many concurrent users, we recommend setting up Postgres replication in the QWC2 Server. Follow [this documentation](https://github.com/bgeo-gis/qwc2-docker?tab=readme-ov-file#setting-up-postgresql-replication) for more details.

### QGIS Project Setup

1. Copy your original QGIS project (in this example, the `ws` Giswater project), open it and add the new materialized views as layers.
2. Apply the main layers styles to their respective materialized counterparts (you can do this using the right click from the QGIS TOC):
   - `v_edit_arc` → `ws_t_arc`
   - `v_edit_node` → `ws_t_node`
   - `v_edit_connec` → `ws_t_connec`
   - `v_edit_link` → `ws_t_link`
3. Remove all non-materialized layers from the project.
4. In **Project > Properties > QGIS Server**, enable **Service Capabilities**, set **Advertised extent**, and configure **CRS restrictions**.
5. Save the project in the `/docker/qgis-projects` directory.

> **Note:** Check that, using the user `tileuser` with all the selectors active you can see the network properly in the QGIS project. We recomend setting the source as a `service` with the same name as in `pg_service.conf`

### Mapproxy Yaml Configuration

1. Create a `.yaml` configuration for the `ws` project (an example is already included in this repository).
2. Rename the `example` folders in `volumes/mapproxy/config` and `volumes/mapproxy/tiles` to match the directory names specified in the `docker-compose.yaml` file.

The YAML configuration file is divided into three parts:

```yaml
db_url: postgresql:///?service=giswater_service_example # PostgreSQL connection configuration for the read-only replica database (pg_service.conf)
db_url_remote: postgresql:///?service=giswater_service_example # PostgreSQL connection configuration for the master remote database (pg_service.conf)
tiling_db_schema: tiled # Schema containing the tiling data
tileclusters_table: tiled.ws_t_tileclusters # Materialized view for storing tile clusters
data_db_schema: ws # Schema containing the data
crs: EPSG:25831 # Coordinate reference system (CRS) used in your project
```
Replace `db_url` and `db_url_remote` with your actual service names defined in the pg_service.conf file. Also update data_db_schema to match the schema where your data (Giswater schema) resides, and set crs to the coordinate system used in your project.

> **Note:** `db_url` and `db_url_remote` are used to differentiate between the master and replica in a PostgreSQL replication setup. If you are using only one database, you can point both to the same service defined in `postgresql.conf`.

```yaml
# Tables used to check for updates
update_tables: [
  link,
  arc,
  connec,
  node
]

# Materialized views to be used as sources
materialized_views: [
  tiled.ws_t_link,
  tiled.ws_t_arc,
  tiled.ws_t_connec,
  tiled.ws_t_node
]

# List of selector commands to select what combinations are tiled:
#  M: Municipality
#  E: Exploitation
#  A: Additional Exploitation
#  S: Sector
#  T: sTate
selectors: [
  E: true, # All Exploitations
  T: [0, 1], # States 0 and 1
]


# Sources to be used in the mapproxy configuration (QGIS project and layers)
sources:
  inventory_source:
    url: http://qwc-qgis-server/ows/?MAP=/data/ws.qgs&USER=tileuser
    layers: ws_t_link,ws_t_arc,ws_t_connec,ws_t_node
```

In this section:

- `update_tables` are the parent tables used in the update to detect changes.
- `materialized_views` are used as data sources.
- `sources` define how to access QGIS layers via WMS. Where:
   - `url` points to the QGIS project
   - `layers` are the name of the layers in the QGIS project to use as source.

```yaml
grid:
  srs: EPSG:25831
  origin: nw
  bbox: [601843, 8128564, 747781, 8208982] # Must cover all the area to tile, used as main_grid
  # mapproxy-util scales -l 10 --as-res-config 20000 --dpi 96

res: [
      #  res            level     scale @96.0 DPI
        52.9166666667, #  0      200000.00000000
        26.4583333333, #  1      100000.00000000
        13.2291666667, #  2       50000.00000000
        5.2916666667, #  3       20000.00000000
        2.6458333333, #  4       10000.00000000
        1.3229166667, #  5        5000.00000000
        0.6614583333, #  6        2500.00000000
        0.3307291667, #  7        1250.00000000
        0.1653645833, #  8         625.00000000
        0.0826822917, #  9         312.50000000
        0.0413411458, # 10         156.25000000
        0.0206705729, # 11          78.12500000
        0.0103352865, # 12          39.06250000
  ]

```
In this last section change the `srs` and `origin` if needed.

To build the containers, from the `/docker` directory run:

```sh
docker compose up -d --build
```

### Mapproxy dynamic configuration and seed


To do a full seed:
```sh
curl http://localhost:8098/mapproxy/seeding/seed/all?config=ws
```
The `config` parameter should be the name of your project (in this case `ws` as our configuration is `ws.yaml`).

> **Note:** The process of seeding the network for the first time could take several hours. Logs are saved in `/docker/volumes/mapproxy/logs`.

During this process, a `.time` file will be created in the `example/temp` folder to record the last seed timestamp. A `.yaml` file is also generated for the current layer Mapproxy is seeding.

Tiles will be saved in the directory specified in your `docker-compose.yaml` file. Once seeding completes, you can verify the tiled `tileclusters layers` via the Mapproxy demo site:

```
http://<host>/mapproxy/ws/demo
```

You can also access the WMTS Capabilities document (used for the QWC2-published QGIS project) at:

```
http://<host>/mapproxy/ws/wmts/1.0.0/WMTSCapabilities.xml
```

### QGIS Project for publishing in QWC2


Install the QGIS plugin [`Tile Manager`](https://github.com/bgeo-gis/tile_manager_qgis_plugin) and follow [this guide](https://github.com/bgeo-gis/tile_manager_qgis_plugin?tab=readme-ov-file#tile-manager-plugin) to build a QGIS project for publishing in QWC2.

### Update tiles

If the network changes, instead of retiling everything (which is time-consuming), you can update only the modified tiles using.:

```sh
curl http://localhost:8098/mapproxy/seeding/seed/update?config=ws
```
> **Note:** This only retiles objects that have been updated or created. To also consider deleted objects in the Network you'll have to implement the audit schema, log table and the triggers the respective parent tables from Giswater 4.

> ❗ f you are using the audit schema for deleted objects, make sure to apply a cleanup policy to the log schema to periodically empty the table.



This endpoint works as follows:

1. Reads the last seed time (from a full or update seed) from `temp/<project>.time`.
2. Refreshes the materialized views specified as `materialized_views` in the base .yaml config file.
3. For each `tilecluster` in the tilecluster materialized view:

   1. Calls the `gw_fct_getfeatureboundary` Giswater function, using  `update_tables` from the base .yaml config file.
   2. The function returns a GeoJSON geometry of features changed since the last seed. If the audit structure is set and working , this will also track deleted objects
   3. If the GeoJson is not empty:
      - Reseeds the tilecluster using the geometry as seed coverage.
      - Logs details into the  `tiled.logs` table for tracking.
   4. A new `temp/<project>.time` file is created to record the latest update timestamp.


## Quick Reference Commands

Build and start Docker containers
```sh
cd mapproxy-docker/docker && docker compose up -d --build
```
Stop and remove Docker containers
```sh
cd mapproxy-docker/docker && docker compose down
```
Clean up project resources
```sh
cd mapproxy-docker/docker && docker compose down -v --rmi all
```
Stops and removes containers, deletes named/anonymous volumes, and removes images built or pulled by this project.

Full seed of a specific project (`ws` in this example)
```sh
curl http://localhost:8098/mapproxy/seeding/seed/all?config=ws
```

Seed update of a specific project (`ws` in this example)
```sh
curl http://localhost:8098/mapproxy/seeding/seed/all?config=ws
```

Access Mapproxy demo for a specific project (`ws` in this example).
```sh
https://<server>/mapproxy/ws/demo/
```
Here you will be able to see all the layers of the project and a preview

WMTS capabilities URL (used for connecting to Mapproxy via QGIS and importing all the layers with the Tile Manager Plugin).
```sh
https://<server>/mapproxy/ws/wmts/1.0.0/WMTSCapabilities.xml
```
After a full seed or an update, is a good idea to generate service configuration in the QWC2 server. Execute this in the QWC2 server:

```sh
curl -X POST "http://localhost:5010/generate_configs?tenant=<tenant>"
```
You can create a Bash script to run the MapProxy update and regenerate the QWC2 configurations at regular intervals (e.g., nightly, weekly, etc.).
