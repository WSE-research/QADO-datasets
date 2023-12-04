#!/bin/bash

# This script is used to deploy the QADO benchmark dataset

# the script stops if an error occurs
set -e

sparqlanalyser="sparql-analyser:latest"

validate="$1"

function initSparqlExpansion() {
  echo "Initialize setup..."
  docker volume create sparql-analyse > /dev/null
  docker pull wseresearch/sparql-analyser:latest > /dev/null
  docker tag wseresearch/sparql-analyser:latest $sparqlanalyser > /dev/null
  docker image rm wseresearch/sparql-analyser:latest > /dev/null
  # check if image is created
  if [ "`docker image ls  --filter reference=$sparqlanalyser -q`" != "" ]; then echo "$sparqlanalyser: image created"; else echo "$sparqlanalyser: image NOT CREATED"; fi
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
    echo -n "Converting $payload. "
    data_file="${payload/".json"/".ttl"}"
    curl -X POST -H "Content-Type: application/json" --silent --data-binary "@${payload}" --output "$data_file" http://172.130.0.2:8080/json2rdf
    addDataToDb "$data_file"
    echo "Completed: added to database: $data_file"
  done
}


function addDataToDb() {
  curl --silent -X POST -H "Content-Type: application/x-turtle" -T "$1" "http://172.130.0.3:7200/repositories/qado/statements"
}

function validate(){
  if [ "$validate" != "--validate" ]
  then
    echo -n "No SPARQL query validation demanded. "
  else
    echo -n "SPARQL query validation: "
    cd ./sparql_validator
    python3 -m venv env
    python3 -m pip install -r requirements.txt
    export QADO_ENDPOINT="http://172.130.0.3:7200/repositories/qado"
    python3 check_sparql_queries_in_qado_triplestore.py
    echo -n "Done. "
    cd ..
  fi
}

function addAdditionalProperties() {
  echo "Generating additional properties from addSparqlAnalysis.json ..."

  payload=$(cat addSparqlAnalysis.json)
  curl --silent -X POST -H "Content-Type: application/json" --data-raw "$payload" http://172.130.0.4:80/sparql/analyse/db --output /dev/null

  echo -n "Waiting until sparql-analyser finished (might take some time) "
  while true
  do
    sleep 15
    echo -n "."
    if [ $( docker ps | grep $sparqlanalyser | wc -l ) -eq 0 ]
    then
      break
    fi
  done
  printf "\nCompleted: sparql-analyser finished\n"
}


function checkAvailability() {
  echo -n "Waiting until start up finished "
  while true
  do
    sleep 1
    echo -n "."
    code=$(curl http://172.130.0.3:7200/rest/repositories -H "Accept: application/json" --write-out '%{http_code}' --silent --output /dev/null)

    if [ "$code" -eq 200 ]
    then
      break
    fi
  done
  echo " completed."
}


function startDeployer() {
  initSparqlExpansion
  docker-compose pull
  docker-compose up -d

  checkAvailability
}


function createDb() {
  echo "Creating QADO database from repo-config.ttl ..."
  curl --silent --output /dev/null -X POST -H "Content-Type: multipart/form-data" -F "config=@repo-config.ttl" http://172.130.0.3:7200/rest/repositories

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
  docker container rm "$(docker ps -a -q --filter ancestor=$sparqlanalyser)" > /dev/null
  docker volume rm sparql-analyse > /dev/null
}


function exportDb() {
  echo "Export DB..."
  curl -H "Accept: application/x-turtle" --silent -o "full-qado.ttl" http://172.130.0.3:7200/repositories/qado/statements?infer=false
  zip qado-benchmarks.zip datasets/*.ttl ontology.ttl full-qado.ttl
  printf "\n### Create RDF Turtle files:\n"
  ls -1 datasets/*.ttl ontology.ttl full-qado.ttl
  removeTTL
}

function createBasicStatistics(){

  printf "\n=== Statistics: Number of triples in complete QADO dataset ===\n"
  curl -X GET 'http://172.130.0.3:7200/repositories/qado?query=select%20(COUNT(*)%20AS%20%3Fcount)%20%20where%20%7B%20%0A%09%3Fs%20%3Fp%20%3Fo%20.%0A%7D%20%0A&infer=true&sameAs=true&Accept=text%2Fcsv&authToken=' \
    --silent \
    --header 'Accept: text/csv' \
    --insecure | column -t -s,


  printf "\n=== Statistics: All dataset labels and number of their languages-specific questions ===\n"
  curl -X GET 'http://172.130.0.3:7200/repositories/qado?query=PREFIX+qado%3A+%3Chttp%3A%2F%2Fpurl.com%2Fqado%2Fontology.ttl%23%3E%0D%0APREFIX+rdf%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F1999%2F02%2F22-rdf-syntax-ns%23%3E%0D%0ASELECT+%3Fdataset+%28count%28%3Fquestion%29+AS+%3Fnumber_of_questions%29%0D%0AWHERE+%7B+%0D%0A++++%3Fquestion+qado%3AisElementOf+%3Fdataset+.%0D%0A++++%3Fdataset+rdf%3Atype+qado%3ADataset+.%0D%0A%7D+%0D%0AGROUP+BY+%3Fdataset%0D%0A&infer=true&sameAs=true&Accept=text%2Fcsv&authToken=' \
    --silent \
    --header 'Accept: text/csv' \
    --insecure | column -t -s,

  printf "\n=== Statistics: Number of questions using a language in a dataset ===\n"
  curl -X GET 'http://172.130.0.3:7200/repositories/qado?query=PREFIX+rdf%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F1999%2F02%2F22-rdf-syntax-ns%23%3E%0D%0APREFIX+qado%3A+%3Chttp%3A%2F%2Fpurl.com%2Fqado%2Fontology.ttl%23%3E%0D%0APREFIX+rdfs%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2000%2F01%2Frdf-schema%23%3E%0D%0ASELECT+%0D%0A++++%3Fdataset+%0D%0A++++%3Fdataset_label+%0D%0A++++%3Flang+%0D%0A++++%28COUNT%28%3Fquestion%29+AS+%3Fnumber_of_question_for_specific_language%29%0D%0AWHERE+%7B%0D%0A++++%3Fquestion+qado%3AisElementOf+%3Fdataset.%0D%0A++++%3Fdataset+rdf%3Atype+qado%3ADataset.%0D%0A++++%3Fdataset+rdfs%3Alabel+%3Fdataset_label+.%0D%0A++++%3Fquestion+qado%3AhasQuestion+%3Fquestion_string.%0D%0A++++BIND%28LANG%28%3Fquestion_string%29+AS+%3Flang%29%0D%0A%7D%0D%0AGROUP+BY+%3Fdataset+%3Fdataset_label+%3Flang%0D%0AORDER+BY+%3Fdataset_label&infer=true&sameAs=true&Accept=text%2Fcsv&authToken=' \
    --silent \
    --header 'Accept: text/csv' \
    --insecure | column -t -s,

}

function removeTTL() {
  echo "Clean up."
  rm -rf datasets/*.ttl
}


startDeployer
createDb
validate
exportDb
createBasicStatistics
stopDeployer
