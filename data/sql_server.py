#!/usr/bin/env python3
"""
Basic Python Server for STOMP Assignment – Stage 3.3

IMPORTANT:
DO NOT CHANGE the server name or the basic protocol.
Students should EXTEND this server by implementing
the methods below.
"""

import socket
import sys
import threading
import sqlite3
from datetime import datetime


SERVER_NAME = "STOMP_PYTHON_SQL_SERVER"  # DO NOT CHANGE!
DB_FILE = "stomp_server.db"              # DO NOT CHANGE!


def recv_null_terminated(sock: socket.socket) -> str:
    data = b""
    while True:
        chunk = sock.recv(1024)
        if not chunk:
            return ""
        data += chunk
        if b"\0" in data:
            msg, _ = data.split(b"\0", 1)
            return msg.decode("utf-8", errors="replace")

# TODO!!
def init_database():
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        
        # Create users table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                password TEXT NOT NULL,
                registration_date TEXT NOT NULL
            )
        """)
        
        # Create login_history table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS login_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                login_time TEXT NOT NULL,
                logout_time TEXT,
                FOREIGN KEY (username) REFERENCES users(username)
            )
        """)
        
        # Create file_tracking table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS file_tracking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL,
                filename TEXT NOT NULL,
                upload_time TEXT NOT NULL,
                game_channel TEXT NOT NULL,
                FOREIGN KEY (username) REFERENCES users(username)
            )
        """)
        
        conn.commit()
        conn.close()
        print(f"[{SERVER_NAME}] Database initialized successfully")
        return "Database initialized"
    except Exception as e:
        print(f"[{SERVER_NAME}] Error initializing database: {e}")
        return f"Error: {str(e)}"

# TODO!!
def execute_sql_command(sql_command: str) -> str:
    """Execute SQL commands like INSERT, UPDATE, DELETE, CREATE."""
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute(sql_command)
        conn.commit()
        rows_affected = cursor.rowcount
        conn.close()
        return f"done ({rows_affected} rows affected)"
    except Exception as e:
        return f"Error: {str(e)}"

# TODO!!
def execute_sql_query(sql_query: str) -> str:
    """Execute SQL SELECT queries and return results."""
    try:
        conn = sqlite3.connect(DB_FILE)
        cursor = conn.cursor()
        cursor.execute(sql_query)
        rows = cursor.fetchall()
        column_names = [description[0] for description in cursor.description]
        conn.close()
        
        if not rows:
            return "No results found"
        
        # Format results as table
        result = " | ".join(column_names) + "\n"
        result += "-" * (len(result) - 1) + "\n"
        for row in rows:
            result += " | ".join(str(item) if item is not None else "NULL" for item in row) + "\n"
        
        return result.strip()
    except Exception as e:
        return f"Error: {str(e)}"


def handle_client(client_socket: socket.socket, addr):
    print(f"[{SERVER_NAME}] Client connected from {addr}")

    try:
        while True:
            message = recv_null_terminated(client_socket)
            if message == "":
                break

            print(f"[{SERVER_NAME}] Received:")
            print(message)

            # Determine if it's a query or command
            message_upper = message.strip().upper()
            
            if message_upper.startswith("SELECT"):
                result = execute_sql_query(message)
            else:
                result = execute_sql_command(message)
            
            client_socket.sendall((result + "\0").encode("utf-8"))

    except Exception as e:
        print(f"[{SERVER_NAME}] Error handling client {addr}: {e}")
    finally:
        try:
            client_socket.close()
        except Exception:
            pass
        print(f"[{SERVER_NAME}] Client {addr} disconnected")


def start_server(host="127.0.0.1", port=7778):
    # Initialize database on startup
    init_database()
    
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        server_socket.bind((host, port))
        server_socket.listen(5)
        print(f"[{SERVER_NAME}] Server started on {host}:{port}")
        print(f"[{SERVER_NAME}] Waiting for connections...")

        while True:
            client_socket, addr = server_socket.accept()
            t = threading.Thread(
                target=handle_client,
                args=(client_socket, addr),
                daemon=True
            )
            t.start()

    except KeyboardInterrupt:
        print(f"\n[{SERVER_NAME}] Shutting down server...")
    finally:
        try:
            server_socket.close()
        except Exception:
            pass


if __name__ == "__main__":
    port = 7778
    if len(sys.argv) > 1:
        raw_port = sys.argv[1].strip()
        try:
            port = int(raw_port)
        except ValueError:
            print(f"Invalid port '{raw_port}', falling back to default {port}")

    start_server(port=port)
