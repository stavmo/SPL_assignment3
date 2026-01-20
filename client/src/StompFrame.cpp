#include "../include/StompFrame.h"

StompFrame::StompFrame(FrameType type, const std::string& body, const std::vector<Header>& headers)
    : type(type), body(body), headers(headers) {}

StompFrame::StompFrame(const std::string& rawFrame) {
    // Remove trailing null terminator if present
    std::string frame = rawFrame;
    if (!frame.empty() && frame.back() == '\0') {
        frame.pop_back();
    }
    
    size_t currentPosition = 0;
    
    // Parse frame type (first line)
    size_t firstNewline = frame.find('\n', currentPosition);
    if (firstNewline < frame.length()) {  // check if position is valid
        std::string typeStr = frame.substr(currentPosition, firstNewline - currentPosition);
        type = stringToFrameType(typeStr);
        currentPosition = firstNewline + 1;
    }
    
    // Parse headers (until empty line)
    while (currentPosition < frame.length()) {
        size_t lineEnd = frame.find('\n', currentPosition);
        
        std::string line = frame.substr(currentPosition, lineEnd - currentPosition);
        currentPosition = lineEnd + 1;
        
        // check if the line is a header
        if (line.empty()) {
            break;
        }
        
        // Split on first colon
        size_t colonPos = line.find(':');
        if (colonPos < line.length()) {  // check if position is valid
            std::string key = line.substr(0, colonPos);
            std::string value = line.substr(colonPos + 1);
            headers.push_back(Header(key, value));
        }
    }
    
    // Parse body (everything after headers)
    if (currentPosition < frame.length()) {
        body = frame.substr(currentPosition);
        if (body.back() == '\n') {
            body.pop_back();
        }
    } else {
        body = "";
    }
}

std::string StompFrame::toString() const {
    std::string result;
    
    // Frame type
    result += frameTypeToString(type) + "\n";
    
    // Headers
    for (const auto& header : headers) {
        result += header.key + ":" + header.value + "\n";
    }
    
    // Empty line before body
    result += "\n";
    
    // Body
    result += body + "\n";
    
    // Null terminator
    //result += '\0';
    
    return result;
}

FrameType StompFrame::getType() const {
    return type;
}

const std::string& StompFrame::getBody() const {
    return body;
}

const std::vector<StompFrame::Header>& StompFrame::getHeaders() const {
    return headers;
}

std::string StompFrame::getHeaderValue(const std::string& key) const {
    for (const auto& header : headers) {
        if (header.key == key) {
            return header.value;
        }
    }
    return "";
}