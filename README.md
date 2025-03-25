# Mapproxy Docker

This guide will help you set up a running instance of Mapproxy. This instance consists of:

- `mapproxy-service`: Mapproxy with custom endpoints for seeding and managing updates.
- `mapproxy-docker`: (this repository) Mapproxy integrated with internal Nginx and QGIS Server.

## Prerequisites

- Docker
- Nginx

> **Note:** The following installation steps may vary depending on the system or may be out of date. If the required software is already installed, you can skip the installation steps.

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
   To restrict access, allow only QWC2's server by using the `allow` and `deny` directives.
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

Mapproxy requires a `tiled` schema in your PostgreSQL database. Follow the `ddl/tiled.sql` file (located in this repository) to:

1. Create the schema `tiled` and the user `tileuser`.
2. Create the required materialized views (`ws_t_node`, `ws_t_arc`, `ws_t_connec`, `ws_t_link`).
3. Create the `tilecluster` materialized view (`ws_t_tileclusters`).

> **Note:** Creating or refreshing the `tilecluster` materialized view may take several minutes.

4. Create a `logs` table:
   ```sql
   CREATE TABLE tiled.logs (
       id SERIAL PRIMARY KEY,
       process_id VARCHAR(255) NOT NULL,
       tilecluster_id VARCHAR(255) NOT NULL,
       project_id VARCHAR(255) NOT NULL,
       start_time TIMESTAMP NOT NULL,
       end_time TIMESTAMP,
       geometry GEOMETRY NOT NULL
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
2. Apply the main layers' styles to their respective materialized layers (you can do this using the right click from the QGIS TOC):
   - `v_edit_arc` → `ws_t_arc`
   - `v_edit_node` → `ws_t_node`
   - `v_edit_connec` → `ws_t_connec`
   - `v_edit_link` → `ws_t_link`
3. Remove all non-materialized layers from the project.
4. In **Project > Properties > QGIS Server**, enable **Service Capabilities**, set **Advertised extent**, and configure **CRS restrictions**.
5. Save the project in the `/docker/qgis-projects` directory.

> **Note:** Check that, using the user `tileuser` with all the selectors active you can see the network properly in the QGIS project. We recomend setting the source as a `service` with the same name as the one in `pg_service.conf`

### Mapproxy Yaml Configuration

1. Create a `.yaml` configuration for the `ws` project (in this repository this is already created as an example).
2. Rename the `example` folders in `volumes/mapproxy/config` and `volumes/mapproxy/tiles` to match the name for the directories in the `docker-compose.yaml`.

The `yaml` configuration file is divided in 3 parts:

```yaml
db_url: postgresql:///?service=giswater_service_example # Postgres connection configuration (pg_service.conf)
tiling_db_table: tiled.ws_t_tileclusters # Materialized view to store the tileclusters
data_db_schema: ws # Schema of the data
crs: EPSG:31982 # Change to the CRS of your data
log_table: tiled.logs # Table to store update logs
```
Change the `db_url` with your service name defined in the pg_service.conf file, the `data_db_schema` of the data (Giswater schema), the `crs` for the one used in your project, etc.

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

# Sources to be used in the mapproxy configuration (QGIS project and layers)
sources:
  inventory_source:
    url: http://qwc-qgis-server/ows/?MAP=/data/ws.qgs&USER=tileuser
    layers: ws_t_link,ws_t_arc,ws_t_connec,ws_t_node
```

In this second part, the `update_tables` are the parent tables used in the update to check for network object changes. The `materialized_views` are the views in the DB used as sources. In the `source` definition, change the `url` to point to your QGIS project file (only change the name of the project, in this case `ws.qgs`, the rest of the URL should remain the same).

The `layers` are the name of the layers in the QGIS project to use as source.

```yaml
grid:
  srs: EPSG:31982
  origin: nw
  # mapproxy-util scales -l 10 --as-res-config 20000 --dpi 96
# The following are just examples, resolution and bbox are defined on make_conf_v2.py
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
bbox: [601843, 8128564, 747781, 8208982]
```
In this last part you should only change the `srs` and `origin` if necessary.

With all these changes, now we can build the docker containers. From the `/docker` directory, run:

```sh
docker compose up -d --build
```

### Mapproxy dynamic configuration and seed

With all docker containers running, we can now create the final `.yaml` config file that Mapproxy will use to seed. This endpoint uses the base .yaml file to create said file.

Call the endpoint directly from terminal:
```sh
curl http://localhost:8098/mapproxy/seeding/generate_config_v2?config=ws
```
The `config` parameter should be the name of the project (in this case `ws`, as our base config file name is `ws.yaml`).

If the configuration is generated successfully, it will create a new file `docker/mapproxy/config/example/config-out/ws.yaml`, which will be the base file for Mapproxy to seed. In this file there is a layer definition, cache, source and grid for each `tilecluster` in `tiled.ws_t_tileclusters` view.

To seed all the network, call the endpoint directly from terminal:
```sh
curl http://localhost:8098/mapproxy/seeding/seed/all?config=ws
```
The `config` parameter should be the name of your project (in this case `ws` as our configuration is `ws.yaml`).

> **Note:** The process of seeding the network for the first time could take several hours. The process will create a file `mapproxy_seed_all.log` in `/docker/mapproxy/logs` to show the current seeding process.

In the `example/temp` folder, a `.time` file will be created to save the last seed timestamp. Also, a `.yaml` file is created for the current layer Mapproxy is seeding.

The tiles will be saved in the tile directory set in the `docker-compose.yaml` file. Once the process is finished, you can check the individual `tileclusters` layers tiled from the Mapproxy demo site:

```
http://<host>/mapproxy/ws/demo
```

You can also check the `RESTFul capabilities document` URL that will be used for the creation of the QGIS project published in QWC2.

```
http://<host>/mapproxy/ws/wmts/1.0.0/WMTSCapabilities.xml
```

### QGIS Project for publishing in QWC2

To use the tiled `tileclusters` layers in QWC2, we need a QGIS project to publish.

To do this, install the QGIS plugin [`Tile Manager`](https://github.com/bgeo-gis/tile_manager_qgis_plugin) and follow [this documentation](https://github.com/bgeo-gis/tile_manager_qgis_plugin?tab=readme-ov-file#tile-manager-plugin) to set up a publishable QGIS project using the Mapproxy tiled layers.

### Update tiles

Since the network can change and retiling all the network can be slow and time-consuming, we can retile only the changes from the last seed using the following endpoint:

```sh
curl http://localhost:8098/mapproxy/seeding/seed/update?config=ws
```
This works as follows:

1. Gets the last seed time (complete network or update) from the `temp/<project>.time` file.
2. Refreshes the materialized views used as source (`materialized_views` in the base .yaml config file).
3. Then for each `tilecluster` in the tilecluster materialized view:

   1. Calls the Giswater function `gw_fct_getfeatureboundary` passing the `update_tables` in the base .yaml config file.
   2. The function returns a `geojson` geometry of the objects that changed since the last seed.
   3. If the geojson is not empty, reseed the specified tilecluster (using the geojson as the seed coverage).
   4. Insert logs in the `tiled.logs` table to keep track of the reseeded tileclusters and geometries.
4. Create a new `temp/<project>.time` to keep track of the last seed time for future updates.

## Scalability

Although QWC2's multi-tenancy approach is very powerful and configurable, you can have multiple QWC2 instances (servers) consuming the tiles from the Mapproxy server, depending on your needs.
