"""
Simple script to setup Telegram connection in Airflow.

This script creates the telegram_default connection needed for TelegramOperator.
"""

import os
from airflow.models import Connection
from airflow.settings import Session


def setup_telegram_connection():
    """Setup Telegram connection in Airflow."""
    
    # Get configuration from environment
    bot_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID")
    
    if not bot_token or not chat_id:
        print("❌ TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables are required")
        print("Please set these variables before running the script")
        return False
    
    # Create connection
    conn = Connection(
        conn_id="telegram_default",
        conn_type="telegram",
        host=chat_id,  # Chat ID goes in host field
        password=bot_token,  # Bot token goes in password field
        description="Telegram bot connection for notifications"
    )
    
    # Save connection
    session = Session()
    
    try:
        # Check if connection already exists
        existing_conn = session.query(Connection).filter(
            Connection.conn_id == "telegram_default"
        ).first()
        
        if existing_conn:
            # Update existing connection
            existing_conn.host = chat_id
            existing_conn.password = bot_token
            existing_conn.description = "Telegram bot connection for notifications"
            print("✅ Updated existing telegram_default connection")
        else:
            # Create new connection
            session.add(conn)
            print("✅ Created new telegram_default connection")
        
        session.commit()
        print(f"📱 Telegram connection configured:")
        print(f"   Chat ID: {chat_id}")
        print(f"   Bot Token: {bot_token[:10]}...")
        
        return True
        
    except Exception as e:
        print(f"❌ Error setting up connection: {e}")
        session.rollback()
        return False
    
    finally:
        session.close()


def verify_telegram_connection():
    """Verify that Telegram connection is properly configured."""
    
    session = Session()
    
    try:
        conn = session.query(Connection).filter(
            Connection.conn_id == "telegram_default"
        ).first()
        
        if conn:
            print("✅ Telegram connection found:")
            print(f"   Connection ID: {conn.conn_id}")
            print(f"   Connection Type: {conn.conn_type}")
            print(f"   Host (Chat ID): {conn.host}")
            print(f"   Password (Bot Token): {conn.password[:10] if conn.password else 'Not set'}...")
            print(f"   Description: {conn.description}")
            return True
        else:
            print("❌ Telegram connection not found")
            return False
            
    except Exception as e:
        print(f"❌ Error verifying connection: {e}")
        return False
    
    finally:
        session.close()


if __name__ == "__main__":
    print("🚀 Setting up Telegram connection for Airflow...")
    
    if setup_telegram_connection():
        print("\n🔍 Verifying connection...")
        verify_telegram_connection()
        
        print("\n📋 Next steps:")
        print("1. Restart Airflow webserver and scheduler")
        print("2. Test the connection in Airflow UI (Admin -> Connections)")
        print("3. Use TelegramOperator in your DAGs")
        print("4. Set Airflow variable 'telegram_chat_id' with your chat ID")
    else:
        print("\n❌ Failed to setup Telegram connection")
        print("Please check your environment variables and try again")
