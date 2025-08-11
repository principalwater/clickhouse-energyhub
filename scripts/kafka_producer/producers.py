import time
import json
from kafka import KafkaProducer
from kafka.errors import NoBrokersAvailable

class DataProducer:
    """
    A generic Kafka producer that connects to a broker and sends data,
    with support for SASL_SSL/SCRAM authentication.
    """
    def __init__(self, broker_url: str, sasl_username=None, sasl_password=None, ssl_truststore_location=None, ssl_password=None):
        self.broker_url = broker_url
        self.sasl_username = sasl_username
        self.sasl_password = sasl_password
        self.ssl_truststore_location = ssl_truststore_location
        self.ssl_password = ssl_password
        self.producer = self._create_producer()

    def _create_producer(self):
        """
        Creates and returns a Kafka producer, with retries.
        """
        producer_config = {
            'bootstrap_servers': [self.broker_url],
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'retries': 5,
            'retry_backoff_ms': 1000
        }

        if self.sasl_username and self.sasl_password:
            producer_config.update({
                'security_protocol': 'SASL_SSL',
                'sasl_mechanism': 'SCRAM-SHA-256',
                'sasl_plain_username': self.sasl_username,
                'sasl_plain_password': self.sasl_password,
                'ssl_check_hostname': False, # Set to True if your certs have correct hostname
                'ssl_truststore_location': self.ssl_truststore_location,
                'ssl_truststore_password': self.ssl_password
            })

        while True:
            try:
                producer = KafkaProducer(**producer_config)
                print(f"Successfully connected to Kafka broker at {self.broker_url}")
                return producer
            except NoBrokersAvailable:
                print(f"Could not connect to Kafka broker at {self.broker_url}. Retrying in 10 seconds...")
                time.sleep(10)

    def send_data(self, topic: str, data: dict):
        """
        Sends a single data record to the specified topic.
        """
        try:
            future = self.producer.send(topic, data)
            # Wait for the message to be sent
            record_metadata = future.get(timeout=10)
            print(f"Sent to {topic}: {data}")
            return record_metadata
        except Exception as e:
            print(f"An error occurred while sending data: {e}")
            # Try to reconnect
            self.producer = self._create_producer()
            return None

    def flush(self):
        """Flushes any buffered records."""
        self.producer.flush()

    def close(self):
        """Closes the producer."""
        self.producer.close()
