/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║  🤖 Duplicate Scanner Bot - Implementation                   ║
 * ║  File: duplicate_bot.cpp                                     ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

#include "duplicate_bot.h"

// MD5 Constants
const uint32_t MD5::S[64] = {
    7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
    5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,
    4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
    6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21
};

const uint32_t MD5::K[64] = {
    0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
    0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
    0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
    0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
    0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
    0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
    0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
};

// ═══════════════════════════════════════════════════════════════
// Constructor & Destructor
// ═══════════════════════════════════════════════════════════════

DuplicateScannerBot::DuplicateScannerBot(const BotConfig& cfg)
    : config(cfg), logger(cfg.logFile) {
    logger.info("🤖 Duplicate Scanner Bot initialized");
}

DuplicateScannerBot::~DuplicateScannerBot() {
    stop();
}

// ═══════════════════════════════════════════════════════════════
// Hash Functions
// ═══════════════════════════════════════════════════════════════

std::string DuplicateScannerBot::calculateHash(const fs::path& path) {
    MD5 md5;
    std::ifstream file(path, std::ios::binary);
    if (!file) return "";
    
    const size_t chunkSize = 128 * 1024;
    std::vector<uint8_t> buffer(chunkSize);
    
    while (file) {
        file.read(reinterpret_cast<char*>(buffer.data()), chunkSize);
        std::streamsize bytesRead = file.gcount();
        if (bytesRead > 0) md5.update(buffer.data(), bytesRead);
    }
    
    return md5.finalize();
}

std::string DuplicateScannerBot::partialHash(const fs::path& path, size_t sampleSize) {
    MD5 md5;
    std::ifstream file(path, std::ios::binary);
    if (!file) return "";
    
    std::vector<uint8_t> buffer(sampleSize);
    file.read(reinterpret_cast<char*>(buffer.data()), sampleSize);
    std::streamsize bytesRead = file.gcount();
    if (bytesRead > 0) {
        md5.update(buffer.data(), bytesRead);
        return md5.finalize();
    }
    return "";
}

// ═══════════════════════════════════════════════════════════════
// Safety Checks
// ═══════════════════════════════════════════════════════════════

bool DuplicateScannerBot::isExcluded(const fs::path& path) {
    for (const auto& part : path) {
        std::string p = part.string();
        std::transform(p.begin(), p.end(), p.begin(), ::tolower);
        for (const auto& excl : config.excludeDirs) {
            if (p == excl) return true;
        }
    }
    return false;
}

bool DuplicateScannerBot::isProtected(const fs::path& path) {
    std::string ext = path.extension().string();
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
    static const std::unordered_set<std::string> protectedExts = {
        ".exe", ".dll", ".sys", ".msi", ".bat", ".cmd",
        ".ps1", ".vbs", ".reg", ".com", ".drv"
    };
    return protectedExts.count(ext) > 0;
}

std::string DuplicateScannerBot::humanSize(uintmax_t size) {
    double sz = size;
    const char* units[] = {"B", "KB", "MB", "GB", "TB"};
    int idx = 0;
    while (sz >= 1024 && idx < 4) { sz /= 1024; idx++; }
    std::stringstream ss;
    ss << std::fixed << std::setprecision(2) << sz << " " << units[idx];
    return ss.str();
}

// ═══════════════════════════════════════════════════════════════
// Main Scan Logic
// ═══════════════════════════════════════════════════════════════

void DuplicateScannerBot::performScan() {
    if (scanning) {
        logger.warn("Scan already in progress, skipping...");
        return;
    }
    
    scanning = true;
    stats.totalScans++;
    
    logger.info("═══════════════════════════════════════════════════");
    logger.info("🚀 Starting scan #" + std::to_string(stats.totalScans.load()));
    logger.info("═══════════════════════════════════════════════════");
    
    auto startTime = std::chrono::high_resolution_clock::now();
    
    std::unordered_map<uintmax_t, std::vector<FileInfo>> sizeMap;
    uintmax_t totalFiles = 0;
    
    // Stage 1: Collect files
    logger.info("📊 Stage 1: Collecting files...");
    
    for (const auto& scanPath : config.scanPaths) {
        if (!fs::exists(scanPath)) {
            logger.warn("Path does not exist: " + scanPath);
            continue;
        }
        
        try {
            for (const auto& entry : fs::recursive_directory_iterator(
                scanPath, fs::directory_options::skip_permission_denied)) {
                
                if (!running && !scanning) return;
                if (!entry.is_regular_file()) continue;
                
                const auto& path = entry.path();
                if (isExcluded(path)) continue;
                
                try {
                    uintmax_t size = entry.file_size();
                    if (size < config.minFileSize || size > config.maxFileSize) continue;
                    
                    FileInfo fi;
                    fi.path = path.string();
                    fi.size = size;
                    
                    auto ftime = entry.last_write_time();
                    auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
                        ftime - fs::file_time_type::clock::now() + std::chrono::system_clock::now()
                    );
                    fi.modified = std::chrono::system_clock::to_time_t(sctp);
                    
                    std::lock_guard<std::mutex> lock(dataMutex);
                    sizeMap[size].push_back(fi);
                    totalFiles++;
                    
                } catch (const std::exception&) {
                    continue;
                }
            }
        } catch (const std::exception& e) {
            logger.error("Error scanning " + scanPath + ": " + e.what());
        }
    }
    
    logger.info("✓ Collected " + std::to_string(totalFiles) + " files");
    stats.totalFilesFound += totalFiles;
    
    // Stage 2: Filter by size
    logger.info("🔍 Stage 2: Filtering by size...");
    uintmax_t candidates = 0;
    for (auto it = sizeMap.begin(); it != sizeMap.end(); ) {
        if (it->second.size() <= 1) {
            it = sizeMap.erase(it);
        } else {
            candidates += it->second.size();
            ++it;
        }
    }
    logger.info("✓ Candidates: " + std::to_string(candidates) + " files");
    
    // Stage 3: Partial hash
    logger.info("⚡ Stage 3: Partial hash...");
    std::unordered_map<std::string, std::vector<FileInfo>> partialMap;
    
    for (auto& [size, files] : sizeMap) {
        for (auto& fi : files) {
            std::string ph = partialHash(fs::path(fi.path));
            if (!ph.empty()) {
                std::string key = std::to_string(size) + "_" + ph;
                partialMap[key].push_back(fi);
            }
        }
    }
    
    // Stage 4: Full hash
    logger.info("🔐 Stage 4: Full hash...");
    std::unordered_map<std::string, DuplicateGroup> fullMap;
    
    for (auto& [key, files] : partialMap) {
        if (files.size() <= 1) continue;
        
        for (auto& fi : files) {
            std::string fullHash = calculateHash(fs::path(fi.path));
            if (!fullHash.empty()) {
                fi.hash = fullHash;
                fullMap[fullHash].hash = fullHash;
                fullMap[fullHash].files.push_back(fi);
            }
        }
    }
    
    // Stage 5: Identify duplicates
    logger.info("✅ Stage 5: Identifying duplicates...");
    std::vector<DuplicateGroup> duplicates;
    uintmax_t wastedSpace = 0;
    
    for (auto& [hash, group] : fullMap) {
        if (group.files.size() > 1) {
            duplicates.push_back(std::move(group));
            wastedSpace += duplicates.back().wastedSpace();
        }
    }
    
    stats.totalDuplicates += duplicates.size();
    
    auto endTime = std::chrono::high_resolution_clock::now();
    double duration = std::chrono::duration<double>(endTime - startTime).count();
    
    // Report
    logger.info("═══════════════════════════════════════════════════");
    logger.info("📊 Scan Results");
    logger.info("═══════════════════════════════════════════════════");
    logger.info("⏱️  Duration: " + std::to_string(duration) + " seconds");
    logger.info("📁 Total files: " + std::to_string(totalFiles));
    logger.info("🎯 Duplicate groups: " + std::to_string(duplicates.size()));
    logger.info("💾 Wasted space: " + humanSize(wastedSpace));
    logger.info("═══════════════════════════════════════════════════");
    
    // Show top duplicates
    if (!duplicates.empty()) {
        std::sort(duplicates.begin(), duplicates.end(),
            [](const DuplicateGroup& a, const DuplicateGroup& b) {
                return a.wastedSpace() > b.wastedSpace();
            });
        
        size_t topN = std::min<size_t>(5, duplicates.size());
        logger.info("\n🔥 Top " + std::to_string(topN) + " duplicate groups:");
        
        for (size_t i = 0; i < topN; i++) {
            const auto& g = duplicates[i];
            logger.info("  " + std::to_string(i+1) + ". [" +
                       std::to_string(g.files.size()) + " files] - " +
                       g.wastedHuman() + " wasted");
            for (size_t j = 0; j < std::min<size_t>(2, g.files.size()); j++) {
                logger.info("     📄 " + g.files[j].path);
            }
        }
    }
    
    saveReport(duplicates);
    
    if (config.autoDelete && !duplicates.empty()) {
        logger.info("\n🗑️  Auto-delete enabled, removing duplicates...");
        deleteDuplicates(duplicates);
    }
    
    if (config.notifyUser && !duplicates.empty()) {
        notifyUser(duplicates);
    }
    
    {
        std::lock_guard<std::mutex> lock(dataMutex);
        lastResults = std::move(duplicates);
    }
    
    scanning = false;
    logger.success("✓ Scan completed successfully");
}

// ═══════════════════════════════════════════════════════════════
// Delete Duplicates
// ═══════════════════════════════════════════════════════════════

void DuplicateScannerBot::deleteDuplicates(const std::vector<DuplicateGroup>& duplicates) {
    uintmax_t deleted = 0;
    uintmax_t freed = 0;
    
    for (const auto& group : duplicates) {
        std::vector<FileInfo> sorted = group.files;
        
        if (config.keepOldest) {
            std::sort(sorted.begin(), sorted.end(),
                [](const FileInfo& a, const FileInfo& b) {
                    return a.modified < b.modified;
                });
        } else {
            std::sort(sorted.begin(), sorted.end(),
                [](const FileInfo& a, const FileInfo& b) {
                    return a.modified > b.modified;
                });
        }
        
        for (size_t i = 1; i < sorted.size(); i++) {
            const auto& fi = sorted[i];
            
            if (isProtected(fs::path(fi.path))) {
                logger.warn("⚠️  Protected: " + fi.path);
                continue;
            }
            
            try {
                fs::remove(fi.path);
                logger.info("✓ Deleted: " + fi.path);
                deleted++;
                freed += fi.size;
            } catch (const std::exception& e) {
                logger.error("✗ Failed: " + fi.path + " - " + e.what());
            }
        }
    }
    
    stats.totalDeleted += deleted;
    stats.totalFreedSpace += freed;
    
    logger.success("🗑️  Deleted " + std::to_string(deleted) +
                  " files, freed " + humanSize(freed));
}

// ═══════════════════════════════════════════════════════════════
// Save Report
// ═══════════════════════════════════════════════════════════════

void DuplicateScannerBot::saveReport(const std::vector<DuplicateGroup>& duplicates) {
    std::ofstream file(config.reportFile);
    if (!file) return;
    
    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    
    file << "{\n";
    file << "  \"scan_time\": \"" << std::put_time(std::localtime(&time), "%Y-%m-%d %H:%M:%S") << "\",\n";
    file << "  \"total_scans\": " << stats.totalScans.load() << ",\n";
    file << "  \"duplicate_groups\": " << duplicates.size() << ",\n";
    file << "  \"duplicates\": [\n";
    
    for (size_t i = 0; i < duplicates.size(); i++) {
        const auto& g = duplicates[i];
        file << "    {\n";
        file << "      \"hash\": \"" << g.hash << "\",\n";
        file << "      \"count\": " << g.files.size() << ",\n";
        file << "      \"wasted\": " << g.wastedSpace() << ",\n";
        file << "      \"files\": [\n";
        for (size_t j = 0; j < g.files.size(); j++) {
            file << "        \"" << g.files[j].path << "\"";
            if (j < g.files.size() - 1) file << ",";
            file << "\n";
        }
        file << "      ]\n";
        file << "    }";
        if (i < duplicates.size() - 1) file << ",";
        file << "\n";
    }
    
    file << "  ]\n";
    file << "}\n";
    
    logger.info("💾 Report saved: " + config.reportFile);
}

// ═══════════════════════════════════════════════════════════════
// User Notification
// ═══════════════════════════════════════════════════════════════

void DuplicateScannerBot::notifyUser(const std::vector<DuplicateGroup>& duplicates) {
#ifdef _WIN32
    uintmax_t wasted = 0;
    for (const auto& g : duplicates) wasted += g.wastedSpace();
    
    std::string msg = "🤖 Duplicate Scanner Bot\n\n"
                     "Found " + std::to_string(duplicates.size()) + " duplicate groups\n"
                     "Wasted space: " + humanSize(wasted) + "\n\n"
                     "Check report: " + config.reportFile;
    
    MessageBoxA(NULL, msg.c_str(), "Duplicate Scanner Bot",
               MB_ICONINFORMATION | MB_SYSTEMMODAL);
#endif
}

// ═══════════════════════════════════════════════════════════════
// Worker Thread
// ═══════════════════════════════════════════════════════════════

void DuplicateScannerBot::workerLoop() {
    logger.info("🤖 Bot started, interval: " +
               std::to_string(config.scanIntervalMinutes) + " minutes");
    
    while (running) {
        performScan();
        
        for (int i = 0; i < config.scanIntervalMinutes * 60 && running; i++) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }
    
    logger.info("🤖 Bot stopped");
}

// ═══════════════════════════════════════════════════════════════
// Public Methods
// ═══════════════════════════════════════════════════════════════

void DuplicateScannerBot::start() {
    if (workerThread.joinable()) return;
    running = true;
    workerThread = std::thread(&DuplicateScannerBot::workerLoop, this);
    logger.success("✓ Bot started");
}

void DuplicateScannerBot::stop() {
    running = false;
    if (workerThread.joinable()) {
        workerThread.join();
    }
}

void DuplicateScannerBot::scanNow() {
    performScan();
}

void DuplicateScannerBot::printStatus() const {
    std::cout << "\n═══════════════════════════════════════════════════\n";
    std::cout << "🤖 Bot Status\n";
    std::cout << "═══════════════════════════════════════════════════\n";
    std::cout << "🔄 Running: " << (running ? "YES" : "NO") << "\n";
    std::cout << "🔍 Scanning: " << (scanning ? "YES" : "NO") << "\n";
    std::cout << "📊 Total scans: " << stats.totalScans.load() << "\n";
    std::cout << "📁 Files found: " << stats.totalFilesFound.load() << "\n";
    std::cout << "🎯 Duplicates: " << stats.totalDuplicates.load() << "\n";
    std::cout << "🗑️  Deleted: " << stats.totalDeleted.load() << "\n";
    std::cout << "💾 Freed: " << humanSize(stats.totalFreedSpace.load()) << "\n";
    std::cout << "═══════════════════════════════════════════════════\n";
}
