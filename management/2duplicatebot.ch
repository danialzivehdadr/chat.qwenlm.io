/**
 * ╔══════════════════════════════════════════════════════════════╗
 * ║         🤖 Auto Duplicate Scanner Bot v1.0  🤖               ║
 * ║         Background Service - Automatic File Cleaner          ║
 * ║         Language: C++17 | Platform: Windows                  ║
 * ║         Author: Danial Zivehdar                              ║
 * ╚══════════════════════════════════════════════════════════════╝
 */

#include <iostream>
#include <fstream>
#include <filesystem>
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <thread>
#include <mutex>
#include <chrono>
#include <iomanip>
#include <sstream>
#include <atomic>
#include <condition_variable>
#include <queue>
#include <functional>

#ifdef _WIN32
    #include <windows.h>
    #include <shlobj.h>
#endif

namespace fs = std::filesystem;

// ═══════════════════════════════════════════════════════════════
// 📝 Logger Class
// ═══════════════════════════════════════════════════════════════

class Logger {
private:
    std::mutex logMutex;
    std::ofstream logFile;
    std::string logPath;
    
public:
    Logger(const std::string& path) : logPath(path) {
        logFile.open(path, std::ios::app);
    }
    
    ~Logger() {
        if (logFile.is_open()) logFile.close();
    }
    
    void log(const std::string& level, const std::string& message) {
        std::lock_guard<std::mutex> lock(logMutex);
        
        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        
        std::stringstream ss;
        ss << std::put_time(std::localtime(&time), "%Y-%m-%d %H:%M:%S");
        
        std::string logEntry = "[" + ss.str() + "] [" + level + "] " + message + "\n";
        
        // Write to file
        if (logFile.is_open()) {
            logFile << logEntry;
            logFile.flush();
        }
        
        // Print to console
        std::cout << logEntry;
    }
    
    void info(const std::string& msg) { log("INFO", msg); }
    void warn(const std::string& msg) { log("WARN", msg); }
    void error(const std::string& msg) { log("ERROR", msg); }
    void success(const std::string& msg) { log("SUCCESS", msg); }
};

// ═══════════════════════════════════════════════════════════════
// 📊 Simple MD5 (Compact Version)
// ═══════════════════════════════════════════════════════════════

class MD5 {
    uint32_t state[4], count;
    uint8_t buffer[64];
    
    static uint32_t F(uint32_t x, uint32_t y, uint32_t z) { return (x & y) | (~x & z); }
    static uint32_t G(uint32_t x, uint32_t y, uint32_t z) { return (x & z) | (y & ~z); }
    static uint32_t H(uint32_t x, uint32_t y, uint32_t z) { return x ^ y ^ z; }
    static uint32_t I(uint32_t x, uint32_t y, uint32_t z) { return y ^ (x | ~z); }
    static uint32_t rotl(uint32_t x, uint32_t n) { return (x << n) | (x >> (32 - n)); }
    
    static const uint32_t S[64], K[64];
    
    void transform(const uint8_t block[64]) {
        uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
        uint32_t M[16];
        for (int i = 0; i < 16; i++)
            M[i] = block[i*4] | (block[i*4+1] << 8) | (block[i*4+2] << 16) | (block[i*4+3] << 24);
        
        for (int i = 0; i < 64; i++) {
            uint32_t f, g;
            if (i < 16) { f = F(b,c,d); g = i; }
            else if (i < 32) { f = G(b,c,d); g = (5*i+1)%16; }
            else if (i < 48) { f = H(b,c,d); g = (3*i+5)%16; }
            else { f = I(b,c,d); g = (7*i)%16; }
            
            uint32_t temp = d; d = c; c = b;
            b = b + rotl(a + f + K[i] + M[g], S[i]);
            a = temp;
        }
        state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    }
    
public:
    MD5() { reset(); }
    
    void reset() {
        state[0] = 0x67452301; state[1] = 0xefcdab89;
        state[2] = 0x98badcfe; state[3] = 0x10325476;
        count = 0;
    }
    
    void update(const uint8_t* data, size_t len) {
        size_t index = count % 64;
        count += len;
        size_t i = 0;
        if (index) {
            size_t partLen = 64 - index;
            if (len >= partLen) {
                memcpy(&buffer[index], data, partLen);
                transform(buffer);
                i = partLen;
            } else {
                memcpy(&buffer[index], data, len);
                return;
            }
        }
        for (; i + 64 <= len; i += 64) transform(&data[i]);
        if (i < len) memcpy(buffer, &data[i], len - i);
    }
    
    std::string finalize() {
        uint8_t padding[64] = {0x80};
        uint64_t bits = count * 8;
        size_t index = count % 64;
        size_t padLen = (index < 56) ? (56 - index) : (120 - index);
        update(padding, padLen);
        uint8_t bitsArr[8];
        for (int i = 0; i < 8; i++) bitsArr[i] = (bits >> (i*8)) & 0xFF;
        update(bitsArr, 8);
        
        std::stringstream ss;
        for (int i = 0; i < 4; i++)
            for (int j = 0; j < 4; j++)
                ss << std::hex << std::setfill('0') << std::setw(2) << ((state[i] >> (j*8)) & 0xFF);
        return ss.str();
    }
};

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
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x45
