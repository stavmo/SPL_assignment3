CFLAGS:=-c -Wall -Weffc++ -g -std=c++11 -Iinclude
LDFLAGS:=-lboost_system -lpthread -lstdc++ -lgcc_s

all: StompClient

EchoClient: bin/ConnectionHandler.o bin/echoClient.o
	g++ -o bin/EchoClient bin/ConnectionHandler.o bin/echoClient.o $(LDFLAGS)

StompClient: bin/ConnectionHandler.o bin/StompClient.o bin/event.o bin/StompFrame.o bin/GameDB.o
	g++ -o bin/StompClient bin/ConnectionHandler.o bin/StompClient.o bin/event.o bin/StompFrame.o bin/GameDB.o $(LDFLAGS)

bin/ConnectionHandler.o: src/ConnectionHandler.cpp
	g++ $(CFLAGS) -o bin/ConnectionHandler.o src/ConnectionHandler.cpp

bin/echoClient.o: src/echoClient.cpp
	g++ $(CFLAGS) -o bin/echoClient.o src/echoClient.cpp

bin/event.o: src/event.cpp
	g++ $(CFLAGS) -o bin/event.o src/event.cpp

bin/StompClient.o: src/StompClient.cpp
	g++ $(CFLAGS) -o bin/StompClient.o src/StompClient.cpp

bin/StompFrame.o: src/StompFrame.cpp
	g++ $(CFLAGS) -o bin/StompFrame.o src/StompFrame.cpp

bin/GameDB.o: src/GameDB.cpp
	g++ $(CFLAGS) -o bin/GameDB.o src/GameDB.cpp

.PHONY: clean
clean:
	rm -f bin/*
	