from SPARQLWrapper import SPARQLWrapper, JSON
from decouple import config
import logging
import time
import pprint

"""
currently only graphdb is supported
"""


logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("query_validator")
logger.setLevel(logging.DEBUG)

WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
DBPEDIA_ENDPOINT = "http://dbpedia.org/sparql"

FREEBASE = "http://dbpedia.org/resource/Freebase_(database)"
DBPEDIA_ENDPOINT_V0416 = "http://dbpedia.org/sparql#v0416"
DBPEDIA_ENDPOINT_2018 = "http://dbpedia.org/sparql#v2018"

NO_ENDPOINT_AVAILABLE = [ FREEBASE, DBPEDIA_ENDPOINT_V0416, DBPEDIA_ENDPOINT_2018 ]


SLEEP_TIME_BETWEEN_QUERIES = 0.5 # in seconds

mapping_dataset_to_knowledge_base = {   
    "http://purl.com/qado/ontology.ttl#CWQ-dev-dataset": FREEBASE,
    "http://purl.com/qado/ontology.ttl#CWQ-test-dataset": FREEBASE,
    "http://purl.com/qado/ontology.ttl#CWQ-train-dataset": FREEBASE,
    
    "http://purl.com/qado/ontology.ttl#lcquad-1.0-test-en-de-dataset": DBPEDIA_ENDPOINT_V0416,
    "http://purl.com/qado/ontology.ttl#lcquad-1.0-train-en-de-dataset": DBPEDIA_ENDPOINT_V0416,
    "http://purl.com/qado/ontology.ttl#lcquad-2.0-train-dataset": DBPEDIA_ENDPOINT_2018,
    "http://purl.com/qado/ontology.ttl#lcquad-2.0-test-dataset": DBPEDIA_ENDPOINT_2018,
    
    "http://purl.com/qado/ontology.ttl#Mintaka-dev-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#Mintaka-test-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#Mintaka-train-dataset": WIKIDATA_ENDPOINT,
    
    "http://purl.com/qado/ontology.ttl#QALD-10-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#QALD-6-train-multilingual-dataset": DBPEDIA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#QALD-8-test-multilingual-dataset": DBPEDIA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#QALD-9-plus-test-dbpedia-dataset": DBPEDIA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#QALD-9-plus-test-wikidata-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#QALD-9-plus-train-dbpedia-dataset": DBPEDIA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#QALD-9-plus-train-wikidata-dataset": WIKIDATA_ENDPOINT,
    
    "http://purl.com/qado/ontology.ttl#RuBQ-1.0-dev-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#RuBQ-1.0-test-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#RuBQ-2.0-dev-dataset": WIKIDATA_ENDPOINT,
    "http://purl.com/qado/ontology.ttl#RuBQ-2.0-test-dataset": WIKIDATA_ENDPOINT
}


# select question from QADO triplestore, currently only graphdb is supported
def question_from_qado_triplestore(qado_endpoint):
    sparql = SPARQLWrapper(qado_endpoint)
    sparql.setQuery("""
        PREFIX qado: <http://purl.com/qado/ontology.ttl#> 
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
		PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        SELECT ?dataset ?question ?query ?queryText ?answerType
        WHERE {
            ?question a ?class ; 
                qado:hasSparqlQuery ?query ;
  				qado:hasAnswer ?answer ;
      			qado:isElementOf ?dataset .
            ?class rdfs:subClassOf qado:Question .
            ?query a qado:Query ; 
                qado:hasQueryText ?queryText .
  			?answer rdf:type ?answerType .
        } 
        ORDER BY RAND() 
        LIMIT 100
    """)
    sparql.setReturnFormat(JSON)
    results = sparql.query().convert()
    return results['results']['bindings']

def get_endpoint(dataset, query):
    if mapping_dataset_to_knowledge_base[dataset] in NO_ENDPOINT_AVAILABLE:
        return None
    elif mapping_dataset_to_knowledge_base[dataset] is None:
        logger.debug("\tNo knowledge base defined for this dataset")
        if "http://dbpedia.org/resource/" in query:
            endpoint = DBPEDIA_ENDPOINT
        elif "http://www.wikidata.org/entity" in query:
            endpoint = WIKIDATA_ENDPOINT
        else:
            logger.warning("No knowledge base found in query: " + query)
            return None
    else:
        endpoint = mapping_dataset_to_knowledge_base[dataset]
    
    logger.debug("\tknowledgeBase: " + endpoint)
    sparql = SPARQLWrapper(endpoint)
    return sparql

def validate_all_queries(results):
    invalid_queries = []
    valid_queries = []
    for result in results:
        question = result['question']['value']
        query = result['query']['value']
        queryText = result['queryText']['value']
        answerType = result['answerType']['value']
        dataset = result['dataset']['value']
        result["knowledgeBase"] = mapping_dataset_to_knowledge_base[dataset] # add the knowledge base to the result
        
        logger.debug("Validating query...")
        logger.debug(yellow("\tquestion: " + question))
        logger.debug("\tquery: " + query)
        logger.debug("\tqueryText: " + queryText)
        logger.debug("\tanswerType: " + answerType)
        logger.debug("\tdataset: " + dataset)
        logger.debug("\tknowledgeBase: " + mapping_dataset_to_knowledge_base[dataset])
        
        try:
            sparql = SPARQLWrapper(result["knowledgeBase"])  # get_endpoint(dataset, query)
            
            # skip the query if there is no endpoint
            if mapping_dataset_to_knowledge_base[dataset] not in NO_ENDPOINT_AVAILABLE and sparql is None:
                    msg = "\tQuery is invalid: no knowledge base found"
                    logger.debug("\t" + msg)
                    result['validation_success'] = False
                    result['error'] = msg
                    
            # execute the query if there is a valid answer type, is not empty, and has a live endpoint
            elif queryText.strip() != "" and mapping_dataset_to_knowledge_base[dataset] is not NO_ENDPOINT_AVAILABLE:
                sparql.setQuery(queryText)
                sparql.setReturnFormat(JSON)
                results = sparql.query().convert()
                if len(results['results']['bindings']) > 0:
                    logger.debug("\tQuery is valid: " + str(len(results['results']['bindings'])) + " results found")
                    result['validation_success'] = True
                else:
                    msg = "Query is invalid: no results"
                    logger.debug("\t" + msg)
                    result['validation_success'] = False
                    result['error'] = msg
                
                # add a sleep to avoid overloading the endpoint for SLEEP_TIME_BETWEEN_QUERIES seconds
                time.sleep(SLEEP_TIME_BETWEEN_QUERIES)
                    
            else:
                if mapping_dataset_to_knowledge_base[dataset] in NO_ENDPOINT_AVAILABLE:
                    logger.debug("\tQuery considered to be valid (no live test as no live endpoint available).")
                else:
                    logger.debug("\tQuery considered to be valid (no live test as text is empty).")
                result['validation_success'] = True
                
        except Exception as e:
            # logging.error(e) 
            msg = "Error while validating query: " + str(e)
            logger.debug("\t" + msg)
            result['validation_success'] = False
            result['error'] = msg

        if result['validation_success'] is False:
            invalid_queries.append(result)
        else:
            valid_queries.append(result)

    return {
        "valid_queries": valid_queries,
        "invalid_queries": invalid_queries
    }

def create_insert_query(query_uri, property, time, knowledge_graph_endpoint):
    return f"""
        PREFIX qado: <http://purl.com/qado/ontology.ttl#>
        PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
        INSERT {{ 
            <{query_uri}> qado:hasSPARQLCheck [ 
                        a qado:SPARQLCheck ; 
                        qado:{property} "{time}"^^xsd:dateTime 
            ] .
            <{query_uri}> qado:correspondsToKnowledgeGraph <{knowledge_graph_endpoint}> .
        }}
    """

def red(text):
    return "\x1b[31;20m" + text + "\x1b[0m"

def green(text):
    return "\x1b[32;20m" + text + "\x1b[0m"

def yellow(text):
    return "\x1b[43;20m" + text + "\x1b[0m"

def cyan(text):
    return "\x1b[33;20m" + text + "\x1b[0m"

def update_qado_triplestore(qado_endpoint, evaluation_results):
    
    updater = SPARQLWrapper(qado_endpoint)
    updater.setMethod('POST')
    
    current_time = time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime())
    
    for evaluation_result in evaluation_results['valid_queries'] + evaluation_results['invalid_queries']:
        query_uri = evaluation_result['query']['value']
        logger.debug(cyan("Inserting evaluation result into QADO triplestore for query: " + query_uri))
        
        if evaluation_result['validation_success'] is False:
            property = "didNotWorkAt"
        else:
            property = "testedSuccessfullyAt"

        insert_query = create_insert_query(
                query_uri, 
                property, 
                current_time, 
                evaluation_result["knowledgeBase"]
        )
        
        logger.debug("\tInserting evaluation result into QADO triplestore...")
        try:
            updater.setQuery(insert_query)
            updater.query()
            logger.debug(green("\tEvaluation result inserted into QADO triplestore: " + query_uri))
        except Exception as e:
            logger.error("\tEvaluation result: " + pprint.pformat(evaluation_result, indent=4, width=160))
            logger.error(e)
            logger.error(red("Error while inserting evaluation result into QADO triplestore: " + insert_query))

# if main 
if __name__ == "__main__":
    QADO_ENDPOINT = config('QADO_ENDPOINT')
    
    # get the list of SPARQL queries that are in the QA_DO triplestore
    results = question_from_qado_triplestore(QADO_ENDPOINT)
    
    # validate all stored queries 
    evaluation_results = validate_all_queries(results)
    
    logger.info("Number of valid queries:   " + str(len(evaluation_results['valid_queries'])))
    logger.info("Number of invalid queries: " + str(len(evaluation_results['invalid_queries'])))
    for result in evaluation_results['invalid_queries']:
        logger.warning(pprint.pformat(result, indent=4, width=160))
    
    # update the QADO triplestore with the evaluation results
    update_qado_triplestore(QADO_ENDPOINT, evaluation_results)
    