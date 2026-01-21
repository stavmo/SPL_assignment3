#include "../include/ConnectionHandler.h"
#include "../include/StompFrame.h"
#include "../include/StompProtocol.h"
#include "../include/event.h"
#include "../include/GameDB.h"

#include <mutex>
#include <condition_variable>
#include <iostream>
#include <sstream>
#include <thread>
#include <atomic>
#include <unordered_map>
#include <vector>
#include <cctype>
#include <fstream>

std::atomic<bool> disconnecting(false);

//removed space before filename (because getline keeps the space after "report") 
static std::string trim(std::string s) {
    while (!s.empty() && std::isspace((unsigned char)s.front())) 
        s.erase(s.begin());
    while (!s.empty() && std::isspace((unsigned char)s.back()))  
        s.pop_back();
    return s;
}

// gets the game from the destination (converts "/topic/gameName" to "gameName")
static std::string getGameFromDestination(const std::string& dest) {
    std::string prefix = "/topic/";
    if (dest.size() >= prefix.size() && dest.substr(0, prefix.size()) == prefix) {
        return dest.substr(prefix.size());
    }
    return dest;
}

static bool sendFrame(ConnectionHandler& handler, const StompFrame& frame) {
    std::string s = frame.toString();
    if (!s.empty() && s.back() == '\0') {
        s.pop_back();
    }
    return handler.sendFrameAscii(s, '\0');
}

// extract user from MESSAGE body
static std::string getUserFromBody(const std::string& body, const std::string& activeUser) {
    std::istringstream iss(body);
    std::string line;

    while (std::getline(iss, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();

        if (line.size() >= 5 && line.substr(0,5) == "user:") {
            std::string u = line.substr(5);
            if (!u.empty() && u[0] == ' ') u.erase(0,1);
            return u;
        }
    }
    return activeUser;
}

// build the game event body that the server knows how to parse
static std::string buildEventBody(const Event& ev, const std::string& user) {
    std::ostringstream out;

    out << "user: " << user << "\n";
    out << "team a: " << ev.get_team_a_name() << "\n";
    out << "team b: " << ev.get_team_b_name() << "\n";
    out << "event name: " << ev.get_name() << "\n";
    out << "time: " << ev.get_time() << "\n";

    out << "general game updates:\n";
    for (const auto& kv : ev.get_game_updates()) {
        out << kv.first << ": " << kv.second << "\n";
    }

    out << "team a updates:\n";
    for (const auto& kv : ev.get_team_a_updates()) {
        out << kv.first << ": " << kv.second << "\n";
    }

    out << "team b updates:\n";
    for (const auto& kv : ev.get_team_b_updates()) {
        out << kv.first << ": " << kv.second << "\n";
    }

    out << "description:\n";
    out << ev.get_description() << "\n";

    return out.str();
}

static void listenToServer(ConnectionHandler& handler,
                           GameDB& db,
                           std::atomic<bool>& running,
                           std::atomic<bool>& shouldTerminate,
                           std::string& activeUser,
						   std::string& expectedReceiptId,
                           bool& receiptArrived,
                           std::mutex& receiptMtx,
                           std::condition_variable& receiptCv,
                           std::mutex& loginMtx,
                           std::condition_variable& loginCv,
                           std::string& loginError,
                           bool& loginResponseReceived)
{
    while (running && !shouldTerminate) {
        std::string raw_str;
        if (!handler.getFrameAscii(raw_str, '\0')) {
            if (!disconnecting.load()) {
                std::cerr << "recv failed (Error: End of file)\n";
            }   
        
            else {
                std::lock_guard<std::mutex> lock(receiptMtx);
                receiptArrived = true;
                receiptCv.notify_all();
            }
            break;
        }

        // constructor expects STOMP frame string
        StompFrame frame(raw_str + '\0');

        if (frame.getType() == FrameType::MESSAGE) {
            std::string dest = frame.getHeaderValue("destination");
            if (dest.empty()) 
				continue;

            std::string gameName = getGameFromDestination(dest);

            std::string body = frame.getBody();
            std::string msgUser = getUserFromBody(body, activeUser);

            // parse body into Event
            Event e(body);

            // keep event for summary
            db.addEvent(gameName,
                        msgUser,
                        e.get_team_a_name(),
                        e.get_team_b_name(),
                        e.get_game_updates(),
                        e.get_team_a_updates(),
                        e.get_team_b_updates(),
                        e.get_time(),
                        e.get_name(),
                        e.get_description());
        }
        else if (frame.getType() == FrameType::RECEIPT) {
            std::string receiptId = frame.getHeaderValue("receipt-id");
            std::string expectedCopy;
            {
                    std::lock_guard<std::mutex> lock(receiptMtx);
                    expectedCopy = expectedReceiptId;;
            }
            if (receiptId == expectedCopy) {
                std::lock_guard<std::mutex> lock(receiptMtx);
                receiptArrived = true;
                
                receiptCv.notify_all();
            }
        }
        
        else if (frame.getType() == FrameType::CONNECTED) {
            std::cout << "Login successful" << std::endl;
            {
                std::lock_guard<std::mutex> lock(loginMtx);
                loginResponseReceived = true;
                loginError = "";
            }
            loginCv.notify_all();
        }
        else if (frame.getType() == FrameType::ERROR) {
            std::string errorBody = frame.getBody();
            std::string errorMsg = frame.getHeaderValue("message");
            
            if (errorMsg.find("User already logged in") != std::string::npos) {
                std::cerr << "User already logged in" << std::endl;
            }
            else if (errorMsg.find("Wrong password") != std::string::npos) {
                std::cerr << "Wrong password" << std::endl;
            }
            else if (!errorMsg.empty()) {
                std::cerr << errorMsg << std::endl;
            }
            else if (!errorBody.empty()) {
                std::cerr << errorBody << std::endl;
            }
            
            {
                std::lock_guard<std::mutex> lock(loginMtx);
                loginResponseReceived = true;
                loginError = errorMsg.empty() ? errorBody : errorMsg;
            }
            loginCv.notify_all();
            running = false;
            break;
        }
    }
}

int main(int argc, char *argv[]) {

    GameDB db;
    StompProtocol protocol;

    std::atomic<bool> running(true);
    std::atomic<bool> shouldTerminate(false);

    std::string activeUser = "";

    ConnectionHandler* handler = nullptr;
    std::thread serverThread;

    std::mutex receiptMtx;
    std::condition_variable receiptCv;
    bool receiptArrived = false;
    std::string expectedReceiptId = "";

    std::mutex loginMtx;
    std::condition_variable loginCv;
    std::string loginError = "";
    bool loginResponseReceived = false;

    while (running) {
        std::string line;
        if (!std::getline(std::cin, line)) 
			break;
        if (line.empty()) 
			continue;

        std::istringstream iss(line);
        std::string cmd;

        std::getline(iss, cmd, ' '); //start reading line, stop when you see a space, store that in "cmd"

        if (cmd == "login") {
            // login command = login {host:port} {user} {pass}
            if (handler != nullptr) {
                std::cerr << "The client is already logged in, log out before trying again\n";
                continue;
            }

            std::string hostport, user, pass;
            std::getline(iss, hostport, ' '); //start reading line, stop when you see a space, store that in "hostport"
            std::getline(iss, user, ' ');  //store from there until the next space in "user"
            std::getline(iss, pass);  //store from there the rest in "pass"


            size_t pos = hostport.find(':');
            if (pos == std::string::npos) {
                std::cerr << "bad host:port\n";
                continue;
            }

            std::string host = hostport.substr(0, pos);
            short port = (short) std::stoi(hostport.substr(pos + 1));

            // create the connection
            if (handler != nullptr) {
                handler->close();
                delete handler;
                handler = nullptr;
            }

            handler = new ConnectionHandler(host, port);
            if (!handler->connect()) {
                std::cerr << "Could not connect to server" << std::endl;
                delete handler;
                handler = nullptr;
                continue;
            }

            activeUser = user;

            // start listener thread
            if (!serverThread.joinable()) {
                serverThread = std::thread([&](){
                    listenToServer(*handler, db, running, shouldTerminate, activeUser, expectedReceiptId, receiptArrived, receiptMtx, receiptCv, loginMtx, loginCv, loginError, loginResponseReceived);
                });
            }

            // send CONNECT frame using protocol
            StompFrame connectFrame = protocol.buildConnectFrame(host, user, pass);
            sendFrame(*handler, connectFrame);
            
            // Mark as logged in (pending server confirmation)
            protocol.setLoggedIn(true, user);
            activeUser = user;
            
            // Wait for server response (CONNECTED or ERROR) - indefinitely
            {
                std::unique_lock<std::mutex> lock(loginMtx);
                loginCv.wait(lock, [&] { return loginResponseReceived; });
                loginResponseReceived = false;
            }
            
            // If connection failed, clean up
            if (!running) {
                if (serverThread.joinable()) {
                    serverThread.join();
                }
                if (handler != nullptr) {
                    handler->close();
                    delete handler;
                    handler = nullptr;
                }
                activeUser = "";
                running = true;
            }
        }

        else if (cmd == "join") {
            if (handler == nullptr) { std::cerr << "login first\n"; 
				continue; }

            std::string game;
            std::getline(iss, game);
            if (game.empty()) 
				continue;

            std::string dest = "/topic/" + game;
            std::string subId = protocol.getNextSubscriptionId();
            
            protocol.addSubscription(game, subId);

            StompFrame subFrame = protocol.buildSubscribeFrame(dest, subId);
            sendFrame(*handler, subFrame);
            std::cout << "Joined channel " << game << "\n";
        }

        else if (cmd == "exit") {
            if (handler == nullptr) { std::cerr << "login first\n"; 
				continue; }

            std::string game;
            std::getline(iss, game);
            if (game.empty()) 
				continue;

            if (!protocol.isSubscribedTo(game)) {
                std::cerr << "not subscribed to " << game << "\n";
                continue;
            }

            std::string subId = protocol.getSubscriptionId(game);
            protocol.removeSubscription(game);

            StompFrame unsub = protocol.buildUnsubscribeFrame(subId);
            sendFrame(*handler, unsub);

            std::cout << "Exited channel " << game << "\n";
        }

        else if (cmd == "report") {
            if (handler == nullptr) { std::cerr << "login first\n"; 
				continue; }

            std::string jsonFile;
            std::getline(iss, jsonFile);
            jsonFile = trim(jsonFile);

            if (jsonFile.empty()) 
				continue;

            // If user didn't join any channel yet, block report BEFORE parsing the file
            if (!protocol.gameToSubscriptionId.size()) {
                std::cerr << "You must join a game before reporting.\n";
                continue;
            }

            names_and_events parsed = parseEventsFile(jsonFile);
            std::string gameName = parsed.team_a_name + "_" + parsed.team_b_name;

            if (!protocol.isSubscribedTo(gameName)) {
                std::cerr << "You must join " << gameName << " before reporting.\n";
                continue;
            }
            
            std::string dest = "/topic/" + gameName;

            for (const Event& ev : parsed.events) {
                std::string body = buildEventBody(ev, activeUser);

                // prepare unique receipt id for this SEND and wait for it
                std::string thisReceiptId = protocol.getNextReceiptId();
                {
                    std::lock_guard<std::mutex> lock(receiptMtx);
                    receiptArrived = false;
                    expectedReceiptId = thisReceiptId;
                }

                StompFrame sendF = protocol.buildSendFrame(dest, body, jsonFile, thisReceiptId);
                sendFrame(*handler, sendF);

                // Block until server acknowledges processing (DB logging + publish)
                {
                    std::unique_lock<std::mutex> lock(receiptMtx);
                    receiptCv.wait(lock, [&] { return receiptArrived; });
                }
            }

            std::cout << "Sent reports to " << gameName << " game\n";
        }

        else if (cmd == "summary") {
            // summary command looks like: summary{game} {user} {file}
            std::string game, user, outFile;
            std::getline(iss, game, ' '); //start reading line, stop when you see a space, store that in "game"
            std::getline(iss, user, ' ');  //store from there until the next space in "user"
            std::getline(iss, outFile);  //store from there the rest in "outFile"

            if (game.empty() || user.empty() || outFile.empty()) 
				continue;

            if (!db.writeSummaryToFile(game, user, outFile)) {
                std::cerr << "no info for game=" << game << " user=" << user << "\n";
            } else {
                std::cout << "wrote summary to " << outFile << "\n";
            }
        }

        else if (cmd == "logout") {
            if (handler == nullptr) 
				break;

            disconnecting.store(true);

            // unsubscribe from all first
            std::vector<std::string> subscribed;
            for (const auto& pair : protocol.gameToSubscriptionId) {
                subscribed.push_back(pair.first);
            }
            
            for (const auto& game : subscribed) {
                std::string subId = protocol.getSubscriptionId(game);
                StompFrame unsub = protocol.buildUnsubscribeFrame(subId);
                sendFrame(*handler, unsub);
            }
            protocol.clearAllSubscriptions();

            // prepare receipt
            {
                std::lock_guard<std::mutex> lock(receiptMtx);
                receiptArrived = false;
                expectedReceiptId = protocol.getNextReceiptId();
            }

            // send DISCONNECT with receipt header
            StompFrame disc = protocol.buildDisconnectFrame(expectedReceiptId);
            sendFrame(*handler, disc);

            // waits until server sends RECEIPT with matching receipt-id
            {
                std::unique_lock<std::mutex> lock(receiptMtx);
                receiptCv.wait(lock, [&] { return receiptArrived; });
            }
                        
            // graceful shut down
            shouldTerminate = true;

            if (serverThread.joinable()) {
                serverThread.join();
            }

            handler->close();
            delete handler;
            handler = nullptr;

            // Reset state for next login
            activeUser = "";
            protocol.setLoggedIn(false);
            shouldTerminate = false;
            disconnecting.store(false);

            // restart listener thread readiness
            if (serverThread.joinable()) {
                serverThread.detach();
            }

            std::cout << "Disconnected\n";
        }

	else {
		std::cerr << "unknown command: " << cmd << "\n";
	}
    }  // close while loop

    running = false;
 
    if (serverThread.joinable()) {
        serverThread.join();
    }

    if (handler != nullptr) {
        handler->close();
        delete handler;
        handler = nullptr;
    }

    return 0;
}
