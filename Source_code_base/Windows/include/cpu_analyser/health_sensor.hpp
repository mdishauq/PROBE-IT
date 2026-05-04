#ifndef HEALTH_SENSOR_HPP
#define HEALTH_SENSOR_HPP
#include <Windows.h>
#include <stdint.h>
#include <cmath>

enum class DataUnit : uint8_t {
    Bytes,
    KB,
    MB,
    GB,
    TB
};


class health_sensor{

public:
    
    struct health_reads{

    uint8_t MemoryLoad;
    uint64_t TotalRam;
    uint64_t RamAvailable;
    uint64_t TotalPageFile;
    uint64_t TotalAvailPageFile;
    uint64_t TotalVirtualMemory;
    uint64_t TotalAvailVirtualMemory;

    };

    health_sensor::health_reads health_data;

    //every final calculation will return a struct package(value,unit)
    struct ResultPackage{
        double Value;
        DataUnit unit;
    };

    uint64_t prevIdle, prevKernel, prevUser;

    void CPU_AttributesRetriver(void);
    void UsedRamCalculator(ResultPackage* rstptr);
    void UsedPageFileCalculator(ResultPackage* rstptr);
    void UsedVirtualMemory(ResultPackage* rstptr);
    void SystemCommitLimit(ResultPackage* rstptr);
    void UsedSystemCommit(ResultPackage* rstptr);
    void getsystemtimes();

    double RamUsageLevel();
    double PageFileStressLevel();
    double VirtualMemoryPressureLevel();
    double CpuWorkingLoad();
    double MemoryTOSwapRatio();
    void SystemStressLevel();
    double SystemVirtualUsageLevel(health_sensor::ResultPackage* rstptr);
};


 

#endif