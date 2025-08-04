# Placeholder for Python script to generate pseudo-streaming data
# This script will produce messages to a Kafka topic (e.g., price_5m)
import time

def main():
    print("Starting data generator...")
    while True:
        # Simulate generating data every 5 minutes
        print("Generating data...")
        time.sleep(300)

if __name__ == "__main__":
    main()
