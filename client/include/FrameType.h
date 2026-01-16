#pragma once

#include <string>
#include <stdexcept>

enum class FrameType {
    CONNECT,
    CONNECTED,
    SEND,
    SUBSCRIBE,
    UNSUBSCRIBE,
    DISCONNECT,
    MESSAGE,
    RECEIPT,
    ERROR
};

inline std::string frameTypeToString(FrameType type) {
    switch (type) {
        case FrameType::CONNECT: return "CONNECT";
        case FrameType::CONNECTED: return "CONNECTED";
        case FrameType::SEND: return "SEND";
        case FrameType::SUBSCRIBE: return "SUBSCRIBE";
        case FrameType::UNSUBSCRIBE: return "UNSUBSCRIBE";
        case FrameType::DISCONNECT: return "DISCONNECT";
        case FrameType::MESSAGE: return "MESSAGE";
        case FrameType::RECEIPT: return "RECEIPT";
        case FrameType::ERROR: return "ERROR";
        default: throw std::runtime_error("Unknown frame type");
    }
}

inline FrameType stringToFrameType(const std::string& str) {
    if (str == "CONNECT") return FrameType::CONNECT;
    if (str == "CONNECTED") return FrameType::CONNECTED;
    if (str == "SEND") return FrameType::SEND;
    if (str == "SUBSCRIBE") return FrameType::SUBSCRIBE;
    if (str == "UNSUBSCRIBE") return FrameType::UNSUBSCRIBE;
    if (str == "DISCONNECT") return FrameType::DISCONNECT;
    if (str == "MESSAGE") return FrameType::MESSAGE;
    if (str == "RECEIPT") return FrameType::RECEIPT;
    if (str == "ERROR") return FrameType::ERROR;
    throw std::runtime_error("Unknown frame type: " + str);
}