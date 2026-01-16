#pragma once

#include "FrameType.h"
#include <string>
#include <vector>

class StompFrame
{
public:
    struct Header {
        std::string key;
        std::string value;
        
        Header(const std::string& k, const std::string& v) : key(k), value(v) {}
    };

private:
    FrameType type;
    std::vector<Header> headers;
    std::string body;

public:
    // Constructor with parameters
    StompFrame(FrameType type, const std::string& body, const std::vector<Header>& headers);
    
    // Constructor for parsing from string
    StompFrame(const std::string& rawFrame);
    
    // Convert frame to string (for sending)
    std::string toString() const;
    
    // Getters
    FrameType getType() const;
    const std::string& getBody() const;
    const std::vector<Header>& getHeaders() const;
    
    // Get header value by key
    std::string getHeaderValue(const std::string& key) const;
};