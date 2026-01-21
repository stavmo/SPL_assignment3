#pragma once
#include <string>
#include <map>
#include <vector>
#include <mutex>

struct EventReportLine {
    int time;
    std::string name;
    std::string description;
};

struct GameSummaryData {
    std::string teamA;
    std::string teamB;
    std::map<std::string, std::string> generalStats;
    std::map<std::string, std::string> teamAStats;
    std::map<std::string, std::string> teamBStats;
    std::vector<EventReportLine> events;
};

class GameDB {
private:
    std::map<std::string, std::map<std::string, GameSummaryData>> db;
    std::mutex mtx;

public:
    void addEvent(const std::string& gameName,
                  const std::string& user,
                  const std::string& teamA,
                  const std::string& teamB,
                  const std::map<std::string,std::string>& general,
                  const std::map<std::string,std::string>& aUpd,
                  const std::map<std::string,std::string>& bUpd,
                  int time,
                  const std::string& eventName,
                  const std::string& desc);

    bool writeSummaryToFile(const std::string& gameName,
                            const std::string& user,
                            const std::string& outFile);

    void printSummaryToConsole(const std::string& gameName,
                               const std::string& user);
};
