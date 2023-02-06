curl --silent --output /dev/null -X DELETE "$EXPORT_DB/admin/databases/qado"
curl --silent --output /dev/null -X POST -F root="{\"dbname\": \"qado\"}" "$EXPORT_DB/admin/databases"
tx=$(curl -u admin:admin --silent -X POST "$EXPORT_DB/qado/transaction/begin")
curl -u admin:admin --silent --output /dev/null -X POST -H "Content-Type: text/turtle" --data-binary "@qado.ttl" "$EXPORT_DB/qado/${tx}/add?graph-uri=default"
curl -u admin:admin --silent --output /dev/null -X POST "$EXPORT_DB/qado/transaction/commit/$tx"