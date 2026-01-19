#include "../include/ConnectionHandler.h"
#include "../include/StompFrame.h"
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

// gets the game from the destination (converts "/topic/gameName" to "gameName")
static std::string getGameFromDestination(const std::string& dest) {
    std::string prefix = "/topic/";
    if (dest.size() >= prefix.size() && dest.substr(0, prefix.size()) == prefix) {
        return dest.substr(prefix.size());
    }
    return dest;
}

//StompFrame::toString() already adds '\0' and ConnectionHandler::sendFrameAscii adds too, so we remove the last '\0'
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
                           std::condition_variable& receiptCv)
{
    while (running) {
        std::string raw_str;
        if (!handler.getFrameAscii(raw_str, '\0')) {
            running = false;
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
            if (receiptId == expectedReceiptId) {
                receiptMtx.lock();
                receiptArrived = true;
                receiptCv.notify_all();
                receiptMtx.unlock();
            }
        }
        else if (frame.getType() == FrameType::ERROR) {
            std::cerr << "ERROR from server:\n" << frame.getBody() << std::endl;
        }

        if (shouldTerminate) {
            running = false;
            break;
        }
    }
}

int main(int argc, char *argv[]) {

    GameDB db;

    std::atomic<bool> running(true);
    std::atomic<bool> shouldTerminate(false);

    std::string activeUser = "";

    std::unordered_map<std::string, std::string> gameToSubId;
    int nextSubId = 1;

    ConnectionHandler* handler = nullptr;
    std::thread serverThread;

	std::mutex receiptMtx;
	std::condition_variable receiptCv;
	bool receiptArrived = false;
	std::string expectedReceiptId = "";
	int nextReceiptId = 1;

    while (running) {
        std::string line;
        if (!std::getline(std::cin, line)) 
			break;
        if (line.empty()) 
			continue;

        std::istringstream iss(line);
        std::string cmd;
        iss >> cmd;

        if (cmd == "login") {
            // login command = login {host:port} {user} {pass}
            std::string hostport, user, pass;
            iss >> hostport >> user >> pass;

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
                std::cerr << "could not connect\n";
                delete handler;
                handler = nullptr;
                continue;
            }

            activeUser = user;

            // start listener thread
            if (!serverThread.joinable()) {
                serverThread = std::thread([&](){
                    listenToServer(*handler, db, running, shouldTerminate, activeUser, expectedReceiptId, receiptArrived, receiptMtx, receiptCv);
                });
            }

            // send CONNECT frame
            std::vector<StompFrame::Header> headers;
            headers.push_back({"accept-version", "1.2"});
            headers.push_back({"host", host});
            headers.push_back({"login", user});
            headers.push_back({"passcode", pass});

            StompFrame connectFrame(FrameType::CONNECT, "", headers);
            sendFrame(*handler, connectFrame);
        }

        else if (cmd == "join") {
            if (handler == nullptr) { std::cerr << "login first\n"; 
				continue; }

            std::string game;
            iss >> game;
            if (game.empty()) 
				continue;

            std::string dest = "/topic/" + game;
            std::string subId = std::to_string(nextSubId++);

            gameToSubId[game] = subId;

            std::vector<StompFrame::Header> headers;
            headers.push_back({"destination", dest});
            headers.push_back({"id", subId});

            StompFrame subFrame(FrameType::SUBSCRIBE, "", headers);
            sendFrame(*handler, subFrame);
        }

        else if (cmd == "exit") {
            if (handler == nullptr) { std::cerr << "login first\n"; 
				continue; }

            std::string game;
            iss >> game;
            if (game.empty()) 
				continue;

            auto it = gameToSubId.find(game);
            if (it == gameToSubId.end()) {
                std::cerr << "not subscribed to " << game << "\n";
                continue;
            }

            std::string subId = it->second;

            std::vector<StompFrame::Header> headers;
            headers.push_back({"id", subId});

            StompFrame unsub(FrameType::UNSUBSCRIBE, "", headers);
            sendFrame(*handler, unsub);

            gameToSubId.erase(it);
        }

        else if (cmd == "report") {
            if (handler == nullptr) { std::cerr << "login first\n"; 
				continue; }

            // report command looks like : {game} {jsonFile}
            std::string game, jsonFile;
            iss >> game >> jsonFile;
            if (game.empty() || jsonFile.empty()) 
				continue;

            names_and_events parsed = parseEventsFile(jsonFile);
            std::string dest = "/topic/" + game;

            for (const Event& ev : parsed.events) {
                std::string body = buildEventBody(ev, activeUser);

                std::vector<StompFrame::Header> headers;
                headers.push_back({"destination", dest});

                StompFrame sendF(FrameType::SEND, body, headers);
                sendFrame(*handler, sendF);
            }
        }

        else if (cmd == "summary") {
            // summary command looks like: summary{game} {user} {file}
            std::string game, user, outFile;
            iss >> game >> user >> outFile;
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

    // reset receipt
    {
        receiptMtx.lock();
        receiptArrived = false;
        expectedReceiptId = std::to_string(nextReceiptId++);
        receiptMtx.unlock();
    }

    // send DISCONNECT with receipt header
    std::vector<StompFrame::Header> headers;
    headers.push_back({"receipt", expectedReceiptId});

    StompFrame disc(FrameType::DISCONNECT, "", headers);
    sendFrame(*handler, disc);

    // wait until server sends RECEIPT with matching receipt-id
    // we use unique_lock here because it lets the thread sleep without holding the lock, and then lock it again when it wakes up
    //main thread (keyboard) sleeps while waiting for the RECEIPT, listener thread gets the RECEIPT and updates receiptArrived, then wakes up main
    {
        std::unique_lock<std::mutex> lock(receiptMtx);

        while (!receiptArrived) {
            receiptCv.wait(lock);
        }
    }

    // close socket after we get RECEIPT
    if (handler != nullptr) {
        handler->close();
        delete handler;
        handler = nullptr;
    }

    // graceful shut down
    shouldTerminate = true;
    running = false;
    break;
    }

	else {
		std::cerr << "unknown command: " << cmd << "\n";
	}
}

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
