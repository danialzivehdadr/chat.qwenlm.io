# include <string>
# include <vector>
# include <cstdint>

struct Operation {
    int step;
    std::string operation;
    std::string binary;
    uint64_t result; // Using uint64_t to safely handle larger XOR results
};

struct Layer {
    std::string name;
    std::vector<Operation> operations;
};

struct ServiceInfo {
    std::string name;
    std::string version;
    std::string type;
    std::string status;
};

struct EncryptionConfig {
    std::string method;
    std::string algorithm;
    std::string securityLevel;
    Layer layer1;
    Layer layer2;
    Layer layer3;
};

struct SystemConfiguration {
    int totalLayers;
    int totalOperations;
    std::string encryptionType;
    std::string response;
    std::string finalHash;
};

struct ProxySettings {
    std::string server;
    int port;
    std::string protocol;
    std::string authentication;
    int timeout;
};

struct ApiEndpoints {
    std::string encrypt;
    std::string decrypt;
    std::string getStatus;
    std::string getConfig;
    std::string generateKey;
};

struct ProxyConfig {
    ServiceInfo service;
    EncryptionConfig encryption;
    SystemConfiguration configuration;
    ProxySettings proxySettings;
    ApiEndpoints apiEndpoints;
};
