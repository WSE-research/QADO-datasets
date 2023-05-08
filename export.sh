curl -k --silent --output /dev/null -X DELETE "$EXPORT_DB/admin/databases/qado"
curl -k --silent --output /dev/null -X POST -F root="{\"dbname\": \"qado\"}" "$EXPORT_DB/admin/databases"
tx=$(curl -k --silent -X POST "$EXPORT_DB/qado/transaction/begin")
curl -k --silent --output /dev/null -X POST -H "Content-Type: text/turtle" --data-binary "@full-qado.ttl" "$EXPORT_DB/qado/${tx}/add?graph-uri=default"
curl -k --silent --output /dev/null -X POST "$EXPORT_DB/qado/transaction/commit/$tx"