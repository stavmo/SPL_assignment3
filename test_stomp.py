#!/usr/bin/env python3
"""STOMP client for testing the server using stomp.py"""

import stomp
import time
import sys

class TestListener(stomp.ConnectionListener):
    """Listener to handle STOMP messages"""
    
    def on_error(self, frame):
        print(f'ERROR: {frame.body}')
    
    def on_message(self, frame):
        print(f'MESSAGE received:')
        print(f'  Headers: {frame.headers}')
        print(f'  Body: {frame.body}')
    
    def on_connected(self, frame):
        print(f'CONNECTED to server')
        print(f'  Session: {frame.headers.get("session", "N/A")}')
        print(f'  Version: {frame.headers.get("version", "N/A")}')
    
    def on_disconnected(self):
        print('DISCONNECTED from server')

def test_stomp_server(host='localhost', port=7777):
    """Test STOMP server with basic operations"""
    
    print(f"Connecting to {host}:{port}...")
    
    # Create connection
    conn = stomp.Connection([(host, port)])
    conn.set_listener('test', TestListener())
    
    try:
        # Connect to server
        conn.connect('testuser', 'testpass', wait=True)
        
        print("\n✓ Connection successful!")
        
        # Subscribe to a topic
        print("\nSubscribing to /topic/test...")
        conn.subscribe(destination='/topic/test', id=1, ack='auto')
        print("✓ Subscribed")
        
        # Send a message
        print("\nSending a message to /topic/test...")
        conn.send(body='Hello STOMP Server!', destination='/topic/test')
        print("✓ Message sent")
        
        # Wait for messages
        print("\nWaiting for messages (5 seconds)...")
        time.sleep(5)
        
        # Unsubscribe
        print("\nUnsubscribing...")
        conn.unsubscribe(id=1)
        print("✓ Unsubscribed")
        
        # Disconnect
        print("\nDisconnecting...")
        conn.disconnect()
        print("✓ Disconnected")
        
        print("\n✓✓✓ All tests passed! ✓✓✓")
        
    except Exception as e:
        print(f"\n✗ ERROR: {e}")
        try:
            conn.disconnect()
        except:
            pass
        sys.exit(1)

if __name__ == "__main__":
    test_stomp_server()
