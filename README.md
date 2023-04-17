# QADO dataset deployer
This repository contains a setup script to install a stardog instance via Docker
with the QADO dataset.

## Run deployer
1. Clone the repository
    ```shell
    git clone https://github.com/WSE-research/QADO-dataset-deployer.git
    ```
2. Run the deployment script
   ```shell
   bash deploy.sh 
   ```

The script generates a ZIP file `qado-benchmark.zip` containing the
full dataset (`full-qado.ttl`) and all supported benchmarks as
separated files in the `datasets` subdirectory.
