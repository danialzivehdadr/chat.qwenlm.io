/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  🤖 Duplicate Scanner Bot - Main Entry Point                 ║
 * ║  File: main.cpp                                              ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

#include "duplicate_bot.h"

int main(int argc, char* argv[]) {
    std::cout << "\n╔══════════════════════════════════════════════════════════════╗\n";
    std::cout << "║         🤖 Auto Duplicate Scanner Bot v1.0  🤖               ║\n";
    std::cout << "║         Background Service - Automatic File Cleaner          ║\n";
    std::cout << "╚══════════════════════════════════════════════════════════════╝\n\n";
    
    // Configure bot
    BotConfig config;
    
    // Default scan paths
#ifdef _WIN32
    char* userProfile = getenv("USERPROFILE");
    if (userProfile) {
        config.scanPaths.push_back(std::string(userProfile) + "\\Desktop");
        config.scanPaths.push_back(std::string(userProfile) + "\\Documents");
        config.scanPaths.push_back(std::string(userProfile) + "\\Downloads");
        config.scanPaths.push_back(std::string(userProfile) + "\\Pictures");
        config.scanPaths.push_back(std::string(userProfile) + "\\Videos");
    }
#else
    char* home = getenv("HOME");
    if (home) {
        config.scanPaths.push_back(std::string(home) + "/Desktop");
        config.scanPaths.push_back(std::string(home) + "/Documents");
        config.scanPaths.push_back(std::string(home) + "/Downloads");
    }
#endif
    
    // Command line options
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--auto-delete") config.autoDelete = true;
        else if (arg == "--no-notify") config.notifyUser = false;
        else if (arg == "--interval" && i + 1 < argc) {
            config.scanIntervalMinutes = std::stoi(argv[++i]);
        }
        else if (arg == "--path" && i + 1 < argc) {
            config.scanPaths.push_back(argv[++i]);
        }
    }
    
    // Create bot
    DuplicateScannerBot bot(config);
    
    // Interactive menu
    std::cout << "📋 Commands:\n";
    std::cout << "  1. Start bot (background)\n";
    std::cout << "  2. Scan now (one-time)\n";
    std::cout << "  3. Show status\n";
    std::cout << "  4. Stop bot\n";
    std::cout << "  5. Exit\n\n";
    
    bool exitProgram = false;
    while (!exitProgram) {
        std::cout << "\n👉 Enter command (1-5): ";
        std::string cmd;
        std::getline(std::cin, cmd);
        
        if (cmd == "1") {
            bot.start();
            std::cout << "✓ Bot started in background\n";
            std::cout << "  Press Ctrl+C to stop or use command 4\n";
        }
        else if (cmd == "2") {
            bot.scanNow();
        }
        else if (cmd == "3") {
            bot.printStatus();
        }
        else if (cmd == "4") {
            bot.stop();
            std::cout << "✓ Bot stopped\n";
        }
        else if (cmd == "5") {
            bot.stop();
            exitProgram = true;
            std::cout << "✓ Goodbye!\n";
        }
        else {
            std::cout << "❌ Invalid command\n";
        }
    }
    
    return 0;
}
