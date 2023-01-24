#!/bin/bash
function initSparqlExpansion() {
  echo "Initialize setup..."
  docker volume create sparql-analyse > /dev/null
  docker pull bigoli98/sparql-analyser:latest > /dev/null
  docker tag bigoli98/sparql-analyser:latest sparql-analyser:latest > /dev/null
  docker image rm bigoli98/sparql-analyser:latest > /dev/null
}


function checkAvailability() {
  while true
  do
    sleep 5
    code=$(curl --write-out '%{http_code}' --silent --output /dev/null http://172.30.0.2:8080/json2rdf)

    if [ "$code" -eq 200 ]
    then
      break
    fi
  done
}


function fetchRmlData() {
  echo "Converting JSON to RDF..."
  for payload in $(find datasets/ -iname "*.json")
  do
    curl -X POST -H "Content-Type: application/json" --silent --data-binary "@${payload}" --output "$payload.ttl" http://172.30.0.2:8080/json2rdf
    addDataToDb "$payload"
    rm "$payload.ttl"
  done
}


function addDataToDb() {
   tx=$(curl -u admin:admin --silent -X POST "http://172.30.0.3:5820/$STARDOG_DB_NAME/transaction/begin")
   curl -u admin:admin --silent --output /dev/null -X POST -H "Content-Type: text/turtle" --data-binary "@$1.ttl" "http://172.30.0.3:5820/$STARDOG_DB_NAME/${tx}/add?graph-uri=default"
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
  DB_CREATION=$(curl --write-out '%{http_code}' --silent --output /dev/null -u admin:admin -X POST -F root="{\"dbname\": \"$STARDOG_DB_NAME\"}" http://172.30.0.3:5820/admin/databases)

  insertDataIntoDb "$DB_CREATION"
}


function insertDataIntoDb() {
  if [ "$1" -eq 201 ]
  then
    fetchRmlData
    addAdditionalProperties
  else
    echo "Failed to create db $STARDOG_DB_NAME! Stopping deployment..."
  fi
}


function stopDeployer() {
  echo "Stopping deployment tools..."
  docker-compose down
  docker container rm "$(docker ps -a -q --filter ancestor=sparql-analyser:latest)" > /dev/null
  docker volume rm sparql-analyse > /dev/null
}


function startFinalStardog() {
  echo "Start final Stardog instance on port $STARDOG_PORT..."
  docker run --name "QADO-stardog" -p "$STARDOG_PORT:5820" -itd -v "$(pwd)/stardog_config:/var/opt/stardog" stardog/stardog:latest
}

function configurePermissions() {
  sleep 10
  curl -X PUT -H "Content-Type: application/json" http://admin:admin@localhost:5820/admin/users/admin/pwd --data-raw "{\"password\": \"$ADMIN_PWD\"}"
}


startDeployer
createDb
stopDeployer
startFinalStardog
configurePermissions
