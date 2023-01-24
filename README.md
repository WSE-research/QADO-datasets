# QADO dataset deployer
This repository contains a setup script to install a stardog instance via Docker
with the QADO dataset.

## Configuration
You need to provide a valid Stardog license key in the `stardog_config` directory.

Edit the environment variables in `config.sh` to adjust the setup for your needs.
You can change the following properties:
* `ADMIN_PWD`: The password for the `admin` user. It's recommended to change it.
* `STARDOG_VERSION`: The stardog version you want to use. It has to be compatible with
your license. You need to select a valid [Stardog Docker Image tag](https://hub.docker.com/r/stardog/stardog/tags).
* `STARDOG_PORT`: The external port at which the stardog instance is available after 
the configuration has been finished.
* `STARDOG_DB_NAME`: The name of the database where the QADO dataset will be stored.

## Run deployer
1. Clone the repository
    ```shell
    git clone https://github.com/WSE-research/QADO-dataset-deployer.git
    ```
2. Adjust the configuration as needed. Default configuration uses `STARDOG_PORT=5820` and
`STARDOG_DB_NAME=RDFized-datasets`
3. Run the deployment script
   ```shell
   bash config.sh 
   ```
