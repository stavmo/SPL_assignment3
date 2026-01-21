#include "../include/event.h"
#include "../include/json.hpp"
#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <vector>
#include <sstream>
using json = nlohmann::json;

Event::Event(std::string team_a_name, std::string team_b_name, std::string name, int time,
             std::map<std::string, std::string> game_updates, std::map<std::string, std::string> team_a_updates,
             std::map<std::string, std::string> team_b_updates, std::string description)
    : team_a_name(team_a_name), team_b_name(team_b_name), name(name),
      time(time), game_updates(game_updates), team_a_updates(team_a_updates),
      team_b_updates(team_b_updates), description(description)
{
}

Event::~Event()
{
}

const std::string &Event::get_team_a_name() const
{
    return this->team_a_name;
}

const std::string &Event::get_team_b_name() const
{
    return this->team_b_name;
}

const std::string &Event::get_name() const
{
    return this->name;
}

int Event::get_time() const
{
    return this->time;
}

const std::map<std::string, std::string> &Event::get_game_updates() const
{
    return this->game_updates;
}

const std::map<std::string, std::string> &Event::get_team_a_updates() const
{
    return this->team_a_updates;
}

const std::map<std::string, std::string> &Event::get_team_b_updates() const
{
    return this->team_b_updates;
}

const std::string &Event::get_description() const
{
    return this->description;
}

Event::Event(const std::string &frame_body)
    : team_a_name(""), team_b_name(""), name(""), time(0),
      game_updates(), team_a_updates(), team_b_updates(), description("")
{
    std::istringstream iss(frame_body);
    std::string line;

    enum Section { NONE, GENERAL, TEAM_A, TEAM_B, DESC };
    Section section = NONE;

    while (std::getline(iss, line)) {
        if (line.size() > 0 && line.back() == '\r') line.pop_back();
        if (line.empty()) continue;

        // main fields
        if (line.rfind("team a:", 0) == 0) {
            team_a_name = line.substr(std::string("team a:").size());
            if (!team_a_name.empty() && team_a_name[0] == ' ') team_a_name.erase(0, 1);
            section = NONE;
            continue;
        }
        if (line.rfind("team b:", 0) == 0) {
            team_b_name = line.substr(std::string("team b:").size());
            if (!team_b_name.empty() && team_b_name[0] == ' ') team_b_name.erase(0, 1);
            section = NONE;
            continue;
        }
        if (line.rfind("event name:", 0) == 0) {
            name = line.substr(std::string("event name:").size());
            if (!name.empty() && name[0] == ' ') name.erase(0, 1);
            section = NONE;
            continue;
        }
        if (line.rfind("time:", 0) == 0) {
            std::string t = line.substr(std::string("time:").size());
            if (!t.empty() && t[0] == ' ') t.erase(0, 1);
            time = std::stoi(t);
            section = NONE;
            continue;
        }

        // section headers
        if (line == "general game updates:") { section = GENERAL; continue; }
        if (line == "team a updates:")       { section = TEAM_A; continue; }
        if (line == "team b updates:")       { section = TEAM_B; continue; }
        if (line == "description:")          { section = DESC; description = ""; continue; }

        // body content
        if (section == DESC) {
            if (!description.empty()) description += "\n";
            description += line;
            continue;
        }

        // key:value updates inside update sections
        if (section == GENERAL || section == TEAM_A || section == TEAM_B) {
            size_t colon = line.find(':');
            if (colon == std::string::npos) continue;

            std::string key = line.substr(0, colon);
            std::string val = line.substr(colon + 1);
            if (!val.empty() && val[0] == ' ') val.erase(0, 1);

            if (section == GENERAL) game_updates[key] = val;
            if (section == TEAM_A)  team_a_updates[key] = val;
            if (section == TEAM_B)  team_b_updates[key] = val;
            continue;
        }

        // ignore other lines (like "user:xyz" if it exists)
    }
}

names_and_events parseEventsFile(std::string json_path)
{
    std::ifstream f(json_path);
    json data = json::parse(f);

    std::string team_a_name = data["team a"];
    std::string team_b_name = data["team b"];

    // run over all the events and convert them to Event objects
    std::vector<Event> events;
    for (auto &event : data["events"])
    {
        std::string name = event["event name"];
        int time = event["time"];
        std::string description = event["description"];
        std::map<std::string, std::string> game_updates;
        std::map<std::string, std::string> team_a_updates;
        std::map<std::string, std::string> team_b_updates;
        for (auto &update : event["general game updates"].items())
        {
            if (update.value().is_string())
                game_updates[update.key()] = update.value();
            else
                game_updates[update.key()] = update.value().dump();
        }

        for (auto &update : event["team a updates"].items())
        {
            if (update.value().is_string())
                team_a_updates[update.key()] = update.value();
            else
                team_a_updates[update.key()] = update.value().dump();
        }

        for (auto &update : event["team b updates"].items())
        {
            if (update.value().is_string())
                team_b_updates[update.key()] = update.value();
            else
                team_b_updates[update.key()] = update.value().dump();
        }
        
        events.push_back(Event(team_a_name, team_b_name, name, time, game_updates, team_a_updates, team_b_updates, description));
    }
    names_and_events events_and_names{team_a_name, team_b_name, events};

    return events_and_names;
}