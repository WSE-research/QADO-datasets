#!/bin/bash
function initSparqlExpansion() {
  echo "Initialize setup..."
  docker volume create sparql-analyse > /dev/null
  docker pull bigoli98/sparql-analyser:latest > /dev/null
  docker tag bigoli98/sparql-analyser:latest sparql-analyser:latest > /dev/null
  docker image rm bigoli98/sparql-analyser:latest > /dev/null

  initializeStardogConfig
}


function initializeStardogConfig() {
  docker volume create qado-stardog > /dev/null

  docker run --rm -d --name dummy -v qado-stardog:/stardog alpine tail -f /dev/null > /dev/null
  docker cp stardog_config/* dummy:/stardog/ > /dev/null
  docker exec dummy chown -R 1000:1000 stardog/ > /dev/null
  docker stop dummy > /dev/null
}


function checkAvailability() {
  while true
  do
    sleep 5
    code=$(curl -u admin:admin --write-out '%{http_code}' --silent --output /dev/null http://172.30.0.3:5820)

    if [ "$code" -eq 302 ]
    then
      break
    fi
  done
}

function loadOntology() {
  echo "Fetching ontology..."
  curl --silent --output ontology.ttl http://172.30.0.2:8080/ontology
  addDataToDb "ontology.ttl"
}


function fetchRmlData() {
  echo "Converting JSON to RDF..."
  for payload in $(find datasets/ -iname "*.json")
  do
    data_file="${payload/".json"/".ttl"}"
    curl -X POST -H "Content-Type: application/json" --silent --data-binary "@${payload}" --output "$data_file" http://172.30.0.2:8080/json2rdf
    addDataToDb "$data_file"
  done
}


function addDataToDb() {
   tx=$(curl -u admin:admin --silent -X POST "http://172.30.0.3:5820/$STARDOG_DB_NAME/transaction/begin")
   curl -u admin:admin --silent --output /dev/null -X POST -H "Content-Type: text/turtle" --data-binary "@$1" "http://172.30.0.3:5820/$STARDOG_DB_NAME/${tx}/add?graph-uri=default"
   curl -u admin:admin --silent --output /dev/null -X POST "http://172.30.0.3:5820/$STARDOG_DB_NAME/transaction/commit/$tx"
}


function addAdditionalProperties() {
  echo "Generating additional properties..."

  payload=$(cat addSparqlAnalysis.json)
  payload=${payload/DBNAME/"$STARDOG_DB_NAME"}
  id=$(curl --silent -X POST -H "Content-Type: application/json" --data-raw "${payload/"-1"/"$STARDOG_PORT"}" http://172.30.0.4:80/sparql/analyse/db | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
  sleep 5
  initial=$(curl --silent "http://172.30.0.4:80/sparql/analyse/$id")

  while true
  do
    sleep 5
    current=$(curl --silent "http://172.30.0.4:80/sparql/analyse/$id")

    if [ "$initial" != "$current" ]
    then
      break
    fi
  done
}


function startDeployer() {
  initSparqlExpansion
  docker-compose up -d

  echo "Waiting until start up finished..."
  checkAvailability
}


function createDb() {
  echo "Creating db $STARDOG_DB_NAME..."
  curl -u admin:admin --silent --output /dev/null -X POST -F root="{\"dbname\": \"$STARDOG_DB_NAME\"}" http://172.30.0.3:5820/admin/databases

  insertDataIntoDb
}


function insertDataIntoDb() {
  loadOntology
  fetchRmlData
  addAdditionalProperties
}


function stopDeployer() {
  echo "Stopping deployment tools..."
  docker-compose down
  docker container rm "$(docker ps -a -q --filter ancestor=sparql-analyser:latest)" > /dev/null
  docker volume rm sparql-analyse > /dev/null
}


function startFinalStardog() {
  echo "Start final Stardog instance on port $STARDOG_PORT..."
  docker run --rm --name "QADO-stardog" -p "$STARDOG_PORT:5820" -itd -v "qado-stardog:/var/opt/stardog" "stardog/stardog:$STARDOG_VERSION" > /dev/null
}


function exportDb() {
  echo "Export DB..."
  sleep 10
  curl "http://admin:admin@localhost:$STARDOG_PORT/$STARDOG_DB_NAME/export" --silent -o "qado.ttl"
  zip qado-full-dataset.zip qado.ttl
  zip qado-benchmarks.zip datasets/*.ttl ontology.ttl
  stopStardog
}

function stopStardog() {
  docker container stop QADO-stardog > /dev/null
  sleep 3
  docker volume rm qado-stardog > /dev/null
  rm -rf datasets/*.ttl
}


startDeployer
createDb
stopDeployer
startFinalStardog
exportDb
