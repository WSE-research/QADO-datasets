from check_sparql_queries_in_qado_triplestore import validate_all_queries

"""
a simple test to check if the check of queries works on DBpedia and Wikidata
"""

    
def test_validate_all_queries():
    QADO_ENDPOINT = "http://localhost:8080/graphdb-workbench/repositories/qa-do"

    valid_questions = [
        {
            "dataset": {"value": "http://purl.com/qado/ontology.ttl#QALD-6-train-multilingual-dataset"},
            "question": {"value": "http://purl.com/qado/ontology.ttl#Q1"},
            "query": {"value": "http://purl.com/qado/ontology.ttl#Query1"},
            "queryText": {"value": "PREFIX dbo: <http://dbpedia.org/ontology/> PREFIX res: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SELECT ?uri WHERE { ?uri dbo:publisher res:GMT_Games }"},
            "text": {"value": "correct DBpedia query"},
            "answerType": {"value": "http://purl.com/qado/ontology.ttl#ValidAnswer"}
        },
        {
            "dataset": {"value": "http://purl.com/qado/ontology.ttl#QALD-9-plus-train-wikidata-dataset"},
            "question": {"value": "http://purl.com/qado/ontology.ttl#Q2"},
            "query": {"value": "http://purl.com/qado/ontology.ttl#Query2"},
            "queryText": {"value": "PREFIX wdt: <http://www.wikidata.org/prop/direct/> PREFIX wd: <http://www.wikidata.org/entity/> SELECT ?uri WHERE { ?uri wdt:P31 wd:Q131436 . }"},
            "text": {"value": "correct Wikidata query"},
            "answerType": {"value": "http://purl.com/qado/ontology.ttl#ValidAnswer"}
        }
    ]

    
    invalid_questions = [
        {
            "dataset": {"value": "http://purl.com/qado/ontology.ttl#QALD-6-train-multilingual-dataset"},
            "question": {"value": "http://purl.com/qado/ontology.ttl#Q3"},
            "query": {"value": "http://purl.com/qado/ontology.ttl#Query3"},
            "queryText": {"value": "PREFIX dbo: <http://dbpedia.org/ontology/> PREFIX res: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SELECT ?uri WHERE { ?uri dbo:publisher res:GMT_GamesINVALID }"},
            "text": {"value": "incorrect DBpedia query"},
            "answerType": {"value": "http://purl.com/qado/ontology.ttl#ValidAnswer"}
        },
        {
            "dataset": {"value": "http://purl.com/qado/ontology.ttl#QALD-6-train-multilingual-dataset"},
            "question": {"value": "http://purl.com/qado/ontology.ttl#Q4"},
            "query": {"value": "http://purl.com/qado/ontology.ttl#Query4"},
            "queryText": {"value": "PREFIXX dbo: <http://dbpedia.org/ontology/> PREFIX res: <http://dbpedia.org/resource/> PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> SELECT ?uri WHERE { ?uri dbo:publisher res:GMT_Games }"},
            "text": {"value": "incorrect DBpedia query"},
            "answerType": {"value": "http://purl.com/qado/ontology.ttl#ValidAnswer"}
        },
        {
            "dataset": {"value": "http://purl.com/qado/ontology.ttl#QALD-9-plus-train-wikidata-dataset"},
            "question": {"value": "http://purl.com/qado/ontology.ttl#Q5"},
            "query": {"value": "http://purl.com/qado/ontology.ttl#Query5"},
            "queryText": {"value": "PREFIX wdt: <http://www.wikidata.org/prop/direct/> PREFIX wd: <http://www.wikidata.org/entity/> SELECT ?uri WHERE { ?uri wwdt:P31 wd:Q131436 . }"},
            "text": {"value": "incorrect Wikidata query"},
            "answerType": {"value": "http://purl.com/qado/ontology.ttl#ValidAnswer"}
        }
    ]
    
    evaluation_results = validate_all_queries(valid_questions + invalid_questions)
    
    assert len(evaluation_results['valid_queries']) == len(valid_questions)
    assert len(evaluation_results['invalid_queries']) == len(invalid_questions)