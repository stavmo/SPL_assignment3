#include "../include/GameDB.h"
#include <fstream>
#include <algorithm>

void GameDB::addEvent(const std::string& gameName,
                      const std::string& user,
                      const std::string& teamA,
                      const std::string& teamB,
                      const std::map<std::string,std::string>& general,
                      const std::map<std::string,std::string>& aUpd,
                      const std::map<std::string,std::string>& bUpd,
                      int time,
                      const std::string& eventName,
                      const std::string& desc) {
    std::lock_guard<std::mutex> lock(mtx);

    GameSummaryData& data = db[gameName][user];

    // set teams
    if (data.teamA.empty() && data.teamB.empty()) {
        data.teamA = teamA;
        data.teamB = teamB;
    }

    // update latest stats
    for (const auto& p : general) data.generalStats[p.first] = p.second;
    for (const auto& p : aUpd) data.teamAStats[p.first] = p.second;
    for (const auto& p : bUpd) data.teamBStats[p.first] = p.second;

    // add event report
    data.events.push_back(EventReportLine{time, eventName, desc});
}

bool GameDB::writeSummaryToFile(const std::string& gameName,
                                const std::string& user,
                                const std::string& outFile) {
    std::lock_guard<std::mutex> lock(mtx);

    auto gameIt = db.find(gameName);
    if (gameIt == db.end()) return false;

    auto userIt = gameIt->second.find(user);
    if (userIt == gameIt->second.end()) return false;

    const GameSummaryData& data = userIt->second;

    std::ofstream out(outFile);
    if (!out.is_open()) return false;

    out << data.teamA << " vs " << data.teamB << "\n";
    out << "Game stats:\n";

    out << "General stats:\n";
    for (const auto& kv : data.generalStats) {
        out << kv.first << ": " << kv.second << "\n";
    }
    out << "\n";

    out << data.teamA << " stats:\n";
    for (const auto& kv : data.teamAStats) {
        out << kv.first << ": " << kv.second << "\n";
    }
    out << "\n";

    out << data.teamB << " stats:\n";
    for (const auto& kv : data.teamBStats) {
        out << kv.first << ": " << kv.second << "\n";
    }
    out << "\n";

    out << "Game event reports:\n";

    // print events by time order of the game
    std::vector<EventReportLine> events = data.events;
    std::sort(events.begin(), events.end(), [](const EventReportLine& a, const EventReportLine& b) {
                  return a.time < b.time;
              });

    for (const auto& e : events) {
        out << e.time << " - " << e.name << ":\n";
        out << e.description << "\n\n";
    }

    return true;
}
