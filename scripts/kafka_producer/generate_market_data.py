import time
import argparse
import os
from dotenv import load_dotenv
from schemas import generate_market_data
from producers import DataProducer

# Load environment variables from the centralized .env file
dotenv_path = os.path.join(os.path.dirname(__file__), '../../infra/env/kafka.env')
load_dotenv(dotenv_path=dotenv_path)

# Kafka settings from environment variables
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9093") # Port updated to 9093 for SASL_SSL
TOPIC = os.getenv("TOPIC_1MIN", "energy_data_1min")
KAFKA_ADMIN_USER = os.getenv("KAFKA_ADMIN_USER")
KAFKA_ADMIN_PASSWORD = os.getenv("KAFKA_ADMIN_PASSWORD")
KAFKA_SSL_KEYSTORE_PASSWORD = os.getenv("KAFKA_SSL_KEYSTORE_PASSWORD")
TRUSTSTORE_PATH = os.path.join(os.path.dirname(__file__), '../../infra/terraform/secrets/kafka.truststore.jks')


def main(iterations: int, delay: int):
    """
    Generates and sends a specified number of market data messages.

    Args:
        iterations (int): The number of messages to send.
        delay (int): The delay in seconds between messages.
    """
    if not all([KAFKA_ADMIN_USER, KAFKA_ADMIN_PASSWORD, KAFKA_SSL_KEYSTORE_PASSWORD]):
        print("Ошибка: Учетные данные Kafka (user, password, keystore_password) должны быть заданы в infra/env/kafka.env")
        return

    producer = DataProducer(
        broker_url=KAFKA_BROKER,
        sasl_username=KAFKA_ADMIN_USER,
        sasl_password=KAFKA_ADMIN_PASSWORD,
        ssl_truststore_location=TRUSTSTORE_PATH,
        ssl_password=KAFKA_SSL_KEYSTORE_PASSWORD
    )
    
    print(f"Starting generation of {iterations} messages for topic '{TOPIC}' with a {delay}s delay.")
    
    for i in range(iterations):
        data = generate_market_data()
        producer.send_data(TOPIC, data)
        if i < iterations - 1:
            time.sleep(delay)
            
    producer.flush()
    producer.close()
    print(f"Finished sending {iterations} messages.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Kafka Producer for Energy Market Data")
    parser.add_argument(
        "-i", "--iterations", 
        type=int, 
        default=60, 
        help="Number of messages to generate and send."
    )
    parser.add_argument(
        "-d", "--delay", 
        type=int, 
        default=1, 
        help="Delay in seconds between messages."
    )
    args = parser.parse_args()
    
    main(args.iterations, args.delay)
