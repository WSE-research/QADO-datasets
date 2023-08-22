#!/bin/bash
function initSparqlExpansion() {
  echo "Initialize setup..."
  docker volume create sparql-analyse > /dev/null
  docker pull wseresearch/sparql-analyser:latest > /dev/null
  docker tag wseresearch/sparql-analyser:latest sparql-analyser:latest > /dev/null
  docker image rm wseresearch/sparql-analyser:latest > /dev/null
}


function checkAvailability() {
  while true
  do
    sleep 5
    code=$(curl http://localhost:7200/rest/repositories -H "Accept: application/json" --write-out '%{http_code}' --silent --output /dev/null)

    if [ "$code" -eq 200 ]
    then
      break
    fi
  done
}

function loadOntology() {
  echo "Fetching ontology..."
  curl --silent --output ontology.ttl http://172.130.0.2:8080/ontology
  addDataToDb "ontology.ttl"
}


function fetchRmlData() {
  echo "Converting JSON to RDF..."
  for payload in $(find datasets/ -iname "*.json")
  do
    data_file="${payload/".json"/".ttl"}"
    curl -X POST -H "Content-Type: application/json" --silent --data-binary "@${payload}" --output "$data_file" http://172.130.0.2:8080/json2rdf
    addDataToDb "$data_file"
  done
}


function addDataToDb() {
   curl --silent -X POST -H "Content-Type: application/x-turtle" -T "$1" "http://172.130.0.3:7200/repositories/qado/statements"
}


function addAdditionalProperties() {
  echo "Generating additional properties..."

  payload=$(cat addSparqlAnalysis.json)
  id=$(curl --silent -X POST -H "Content-Type: application/json" --data-raw "$payload" http://172.130.0.4:80/sparql/analyse/db | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
  sleep 5
  initial=$(curl --silent "http://172.130.0.4:80/sparql/analyse/$id")

  while true
  do
    sleep 5
    current=$(curl --silent "http://172.130.0.4:80/sparql/analyse/$id")

    if [ "$initial" != "$current" ]
    then
      break
    fi
  done
}


function startDeployer() {
  initSparqlExpansion
  docker-compose pull
  docker-compose up -d

  echo "Waiting until start up finished..."
  checkAvailability
}


function createDb() {
  echo "Creating db qado..."
  curl --silent --output /dev/null -X POST -H "Content-Type: multipart/form-data" -F "config=@repo-config.ttl" http://172.130.0.3:7200/rest/repositories

  insertDataIntoDb "$1"
}


function insertDataIntoDb() {
  loadOntology
  fetchRmlData
  addAdditionalProperties
  validateSPARQLQueries "$1"
}


function validateSPARQLQueries() {
  if [ "$1" = "--validate" ]
  then
    docker pull wseresearch/qado-sparql-validator:latest > /dev/null
    echo "Validate SPARQL queries..."
    docker run --rm -it --network host wseresearch/qado-sparql-validator:latest "http://localhost:7200/repositories/qado" "http://localhost:7200/repositories/qado/statements"
  fi
}


function stopDeployer() {
  echo "Stopping deployment tools..."
  docker-compose down
  docker container rm "$(docker ps -a -q --filter ancestor=sparql-analyser:latest)" > /dev/null
  docker volume rm sparql-analyse > /dev/null
}


function exportDb() {
  echo "Export DB..."
  curl -H "Accept: application/x-turtle" --silent -o "full-qado.ttl" http://localhost:7200/repositories/qado/statements?infer=false
  zip qado-benchmarks.zip datasets/*.ttl ontology.ttl full-qado.ttl
  removeTTL
}

function removeTTL() {
  rm -rf datasets/*.ttl
}


startDeployer
createDb "$1"
exportDb
stopDeployer
