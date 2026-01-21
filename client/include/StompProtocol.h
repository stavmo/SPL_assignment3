#pragma once

#include "../include/StompFrame.h"
#include <string>
#include <map>
#include <memory>

class StompProtocol
{
private:
    int nextReceiptId;
    int nextSubscriptionId;
    std::map<std::string, std::string> gameToSubscriptionId;  // game name -> subscription ID
    bool isLoggedIn;
    std::string currentUser;

public:
    StompProtocol();
    ~StompProtocol();

    // Frame builders
    StompFrame buildConnectFrame(const std::string& host, const std::string& user, const std::string& passcode);
    StompFrame buildSendFrame(const std::string& destination, const std::string& body, const std::string& filename = "", const std::string& receiptId = "");
    StompFrame buildSubscribeFrame(const std::string& destination);
    StompFrame buildUnsubscribeFrame(const std::string& subscriptionId);
    StompFrame buildDisconnectFrame(const std::string& receiptId);

    // State management
    void setLoggedIn(bool logged, const std::string& user = "");
    bool getLoggedIn() const;
    std::string getCurrentUser() const;

    // Subscription management
    void addSubscription(const std::string& game, const std::string& subscriptionId);
    void removeSubscription(const std::string& game);
    std::string getSubscriptionId(const std::string& game) const;
    bool isSubscribedTo(const std::string& game) const;
    void clearAllSubscriptions();

    // Receipt management
    std::string getNextReceiptId();

    // Subscription ID management
    std::string getNextSubscriptionId();

    // Validation
    bool validateConnectResponse(const StompFrame& frame) const;
    bool validateMessageFrame(const StompFrame& frame) const;
};

