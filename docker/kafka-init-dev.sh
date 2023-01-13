/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server sharenite-kafka:9092 --list

echo -e 'Creating kafka topics'
/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server sharenite-kafka:9092 --create --if-not-exists --topic library.sync --replication-factor 1 --partitions 10
/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server sharenite-kafka:9092 --create --if-not-exists --topic dead.messages --replication-factor 1 --partitions 1

echo -e 'Successfully created the following topics:'
/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server sharenite-kafka:9092 --list