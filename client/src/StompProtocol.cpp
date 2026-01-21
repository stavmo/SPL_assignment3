#include "../include/StompProtocol.h"
#include "../include/StompFrame.h"
#include <vector>

StompProtocol::StompProtocol()
    : nextReceiptId(1), nextSubscriptionId(1), isLoggedIn(false), currentUser("") {}

StompProtocol::~StompProtocol() {}

StompFrame StompProtocol::buildConnectFrame(const std::string& host, const std::string& user, const std::string& passcode)
{
    std::vector<StompFrame::Header> headers;
    headers.push_back({"accept-version", "1.2"});
    headers.push_back({"host", host});
    headers.push_back({"login", user});
    headers.push_back({"passcode", passcode});

    return StompFrame(FrameType::CONNECT, "", headers);
}

StompFrame StompProtocol::buildSendFrame(const std::string& destination, const std::string& body, const std::string& filename, const std::string& receiptId)
{
    std::vector<StompFrame::Header> headers;
    headers.push_back({"destination", destination});
    
    if (!filename.empty()) {
        headers.push_back({"filename", filename});
    }
    
    if (!receiptId.empty()) {
        headers.push_back({"receipt", receiptId});
    }

    return StompFrame(FrameType::SEND, body, headers);
}

StompFrame StompProtocol::buildSubscribeFrame(const std::string& destination)
{
    std::string subId = getNextSubscriptionId();
    
    std::vector<StompFrame::Header> headers;
    headers.push_back({"destination", destination});
    headers.push_back({"id", subId});

    return StompFrame(FrameType::SUBSCRIBE, "", headers);
}

StompFrame StompProtocol::buildUnsubscribeFrame(const std::string& subscriptionId)
{
    std::vector<StompFrame::Header> headers;
    headers.push_back({"id", subscriptionId});

    return StompFrame(FrameType::UNSUBSCRIBE, "", headers);
}

StompFrame StompProtocol::buildDisconnectFrame(const std::string& receiptId)
{
    std::vector<StompFrame::Header> headers;
    headers.push_back({"receipt", receiptId});

    return StompFrame(FrameType::DISCONNECT, "", headers);
}

void StompProtocol::setLoggedIn(bool logged, const std::string& user)
{
    isLoggedIn = logged;
    if (logged) {
        currentUser = user;
    } else {
        currentUser = "";
    }
}

bool StompProtocol::getLoggedIn() const
{
    return isLoggedIn;
}

std::string StompProtocol::getCurrentUser() const
{
    return currentUser;
}

void StompProtocol::addSubscription(const std::string& game, const std::string& subscriptionId)
{
    gameToSubscriptionId[game] = subscriptionId;
}

void StompProtocol::removeSubscription(const std::string& game)
{
    gameToSubscriptionId.erase(game);
}

std::string StompProtocol::getSubscriptionId(const std::string& game) const
{
    auto it = gameToSubscriptionId.find(game);
    if (it != gameToSubscriptionId.end()) {
        return it->second;
    }
    return "";
}

bool StompProtocol::isSubscribedTo(const std::string& game) const
{
    return gameToSubscriptionId.find(game) != gameToSubscriptionId.end();
}

void StompProtocol::clearAllSubscriptions()
{
    gameToSubscriptionId.clear();
}

std::string StompProtocol::getNextReceiptId()
{
    return std::to_string(nextReceiptId++);
}

std::string StompProtocol::getNextSubscriptionId()
{
    return std::to_string(nextSubscriptionId++);
}

bool StompProtocol::validateConnectResponse(const StompFrame& frame) const
{
    if (frame.getType() != FrameType::CONNECTED && frame.getType() != FrameType::ERROR) {
        return false;
    }
    return true;
}

bool StompProtocol::validateMessageFrame(const StompFrame& frame) const
{
    if (frame.getType() != FrameType::MESSAGE) {
        return false;
    }
    
    std::string dest = frame.getHeaderValue("destination");
    std::string subId = frame.getHeaderValue("subscription");
    std::string msgId = frame.getHeaderValue("message-id");
    
    return !dest.empty() && !subId.empty() && !msgId.empty();
}
