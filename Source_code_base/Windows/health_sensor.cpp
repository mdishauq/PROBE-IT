#include "cpu_analyser/health_sensor.hpp"

MEMORYSTATUSEX winState;
MEMORYSTATUSEX* strptr = &winState;




void health_sensor::CPU_AttributesRetriver(){

    winState.dwLength = sizeof(winState);
    if(GlobalMemoryStatusEx(&winState)){

        //Utility: This is the quickest way to see if the system is "stressed." It’s basically the percentage you see in the Windows Task Manager.
        health_data.MemoryLoad = static_cast<uint8_t>(winState.dwMemoryLoad);
        health_data.TotalRam = winState.ullTotalPhys;
        health_data.RamAvailable = winState.ullAvailPhys;
        health_data.TotalPageFile = winState.ullTotalPageFile;
        health_data.TotalAvailPageFile = winState.ullAvailPageFile;
        health_data.TotalVirtualMemory = winState.ullTotalVirtual;
        health_data.TotalAvailVirtualMemory = winState.ullAvailVirtual;

    }


}

void health_sensor::UsedRamCalculator(health_sensor::ResultPackage* rstptr) {
    
    uint64_t UsedRam = health_data.TotalRam - health_data.RamAvailable;

    
    const uint64_t GB = 1073741824; // 1024 * 1024 * 1024
    const uint64_t MB = 1048576;    // 1024 * 1024
    const uint64_t KB = 1024;

    
    if (UsedRam >= GB) {
        rstptr->Value = (double)UsedRam / GB;  
        rstptr->unit = DataUnit::GB;           
    } 
    else if (UsedRam >= MB) {
        rstptr->Value = (double)UsedRam / MB;
        rstptr->unit = DataUnit::MB;
    } 
    else if (UsedRam >= KB) {
        rstptr->Value = (double)UsedRam / KB;
        rstptr->unit = DataUnit::KB;
    } 
    else {
        rstptr->Value = (double)UsedRam;
        rstptr->unit = DataUnit::Bytes;
    }
}

void health_sensor::UsedPageFileCalculator(health_sensor::ResultPackage* rstptr){
    uint64_t UsedPageSpace =  health_data.TotalPageFile - health_data.TotalAvailPageFile;

    const uint64_t GB = 1073741824; // 1024 * 1024 * 1024
    const uint64_t MB = 1048576;    // 1024 * 1024
    const uint64_t KB = 1024;

    if (UsedPageSpace >= GB) {
        rstptr->Value = (double)UsedPageSpace / GB;  
        rstptr->unit = DataUnit::GB;           
    } 
    else if (UsedPageSpace >= MB) {
        rstptr->Value = (double)UsedPageSpace / MB;
        rstptr->unit = DataUnit::MB;
    } 
    else if (UsedPageSpace >= KB) {
        rstptr->Value = (double)UsedPageSpace / KB;
        rstptr->unit = DataUnit::KB;
    } 
    else {
        rstptr->Value = (double)UsedPageSpace;
        rstptr->unit = DataUnit::Bytes;
    }

}

void health_sensor::UsedVirtualMemory(health_sensor::ResultPackage* rstptr){
    uint64_t UsedVirtualMemory = health_data.TotalVirtualMemory - health_data.TotalAvailVirtualMemory;

    const uint64_t GB = 1073741824; // 1024 * 1024 * 1024
    const uint64_t MB = 1048576;    // 1024 * 1024
    const uint64_t KB = 1024;

    if (UsedVirtualMemory >= GB) {
        rstptr->Value = (double)UsedVirtualMemory / GB;  
        rstptr->unit = DataUnit::GB;           
    } 
    else if (UsedVirtualMemory >= MB) {
        rstptr->Value = (double)UsedVirtualMemory / MB;
        rstptr->unit = DataUnit::MB;
    } 
    else if (UsedVirtualMemory >= KB) {
        rstptr->Value = (double)UsedVirtualMemory / KB;
        rstptr->unit = DataUnit::KB;
    } 
    else {
        rstptr->Value = (double)UsedVirtualMemory;
        rstptr->unit = DataUnit::Bytes;
    }

}

void health_sensor::SystemCommitLimit(health_sensor::ResultPackage* rstptr){
    uint64_t CommitLimit = health_data.TotalRam + health_data.TotalPageFile;

    const uint64_t GB = 1073741824; // 1024 * 1024 * 1024
    const uint64_t MB = 1048576;    // 1024 * 1024
    const uint64_t KB = 1024;

    if (CommitLimit >= GB) {
        rstptr->Value = (double)CommitLimit / GB;  
        rstptr->unit = DataUnit::GB;           
    } 
    else if (CommitLimit >= MB) {
        rstptr->Value = (double)CommitLimit / MB;
        rstptr->unit = DataUnit::MB;
    } 
    else if (CommitLimit >= KB) {
        rstptr->Value = (double)CommitLimit / KB;
        rstptr->unit = DataUnit::KB;
    } 
    else {
        rstptr->Value = (double)CommitLimit;
        rstptr->unit = DataUnit::Bytes;
    }
}


void health_sensor::UsedSystemCommit(health_sensor::ResultPackage* rstptr){

    uint64_t UsedCommit = (health_data.TotalRam - health_data.RamAvailable) + (health_data.TotalPageFile - health_data.TotalAvailPageFile);

    const uint64_t GB = 1073741824; // 1024 * 1024 * 1024
    const uint64_t MB = 1048576;    // 1024 * 1024
    const uint64_t KB = 1024;

    if (UsedCommit >= GB) {
        rstptr->Value = (double)UsedCommit / GB;  
        rstptr->unit = DataUnit::GB;           
    } 
    else if (UsedCommit >= MB) {
        rstptr->Value = (double)UsedCommit / MB;
        rstptr->unit = DataUnit::MB;
    } 
    else if (UsedCommit >= KB) {
        rstptr->Value = (double)UsedCommit / KB;
        rstptr->unit = DataUnit::KB;
    } 
    else {
        rstptr->Value = (double)UsedCommit;
        rstptr->unit = DataUnit::Bytes;
    }
}

uint64_t ConvertFileTime(const FILETIME& ft){
        ULARGE_INTEGER uli;
        uli.LowPart = ft.dwLowDateTime;
        uli.HighPart = ft.dwHighDateTime;
        return uli.QuadPart; // This is your single 64-bit number
}

void health_sensor::getsystemtimes() {
    
    FILETIME idle, kernel, user;

    if (GetSystemTimes(&idle, &kernel, &user)) {
        // 1. Convert current snapshots to 64-bit integers
        uint64_t currentIdle = ConvertFileTime(idle);
        uint64_t currentKernel = ConvertFileTime(kernel);
        uint64_t currentUser = ConvertFileTime(user);

        // 2. Calculate the difference (Delta) between current and previous snapshots
        uint64_t deltaIdle = currentIdle - prevIdle;
        uint64_t deltaKernel = currentKernel - prevKernel;
        uint64_t deltaUser = currentUser - prevUser;

        // 3. Calculate Total and Work times
        uint64_t totalSystemTime = deltaKernel + deltaUser;
        uint64_t workTime = totalSystemTime - deltaIdle;

        // 4. Calculate Final Percentage (with safety check for division by zero)
        double CpuUsagePercentage = (totalSystemTime > 0) ? 
            ((double)workTime / totalSystemTime) * 100.0 : 0.0;

        // 5. Store current values into 'prev' variables for the next call
        prevIdle = currentIdle;
        prevKernel = currentKernel;
        prevUser = currentUser;

        // 6. Save the result to your health_data struct
        health_data.MemoryLoad = (uint8_t)CpuUsagePercentage; 
    }
}

double health_sensor::RamUsageLevel() {
    if (health_data.TotalRam == 0) return 0.0;
    uint64_t used = health_data.TotalRam - health_data.RamAvailable;
    return ((double)used / health_data.TotalRam) * 100.0;
}

double health_sensor::PageFileStressLevel() {
    if (health_data.TotalPageFile == 0) return 0.0;
    uint64_t used = health_data.TotalPageFile - health_data.TotalAvailPageFile;
    return ((double)used / health_data.TotalPageFile) * 100.0;
}

double health_sensor::VirtualMemoryPressureLevel() {
    if (health_data.TotalVirtualMemory == 0) return 0.0;
    uint64_t used = health_data.TotalVirtualMemory - health_data.TotalAvailVirtualMemory;
    return ((double)used / health_data.TotalVirtualMemory) * 100.0;
}

double health_sensor::CpuWorkingLoad() {
    // This simply returns the value calculated in getsystemtimes()
    // Since MemoryLoad is uint8_t, we cast it back to double
    return (double)health_data.MemoryLoad;
}

double health_sensor::MemoryTOSwapRatio() {
    uint64_t usedRam = health_data.TotalRam - health_data.RamAvailable;
    uint64_t usedPage = health_data.TotalPageFile - health_data.TotalAvailPageFile;
    
    if (usedRam == 0) return 0.0; 
    // A ratio of 1.0 means you are using equal parts RAM and PageFile
    return (double)usedPage / usedRam;
}

void health_sensor::SystemStressLevel() {
    // This is the "Commit Charge" percentage
    uint64_t totalLimit = health_data.TotalRam + health_data.TotalPageFile;
    uint64_t totalUsed = (health_data.TotalRam - health_data.RamAvailable) + 
                         (health_data.TotalPageFile - health_data.TotalAvailPageFile);

    if (totalLimit == 0) return;

    [[maybe_unused]] double stress = ((double)totalUsed / totalLimit) * 100.0;
    // You can use this value to trigger a predictive alert
}

double health_sensor::SystemVirtualUsageLevel(health_sensor::ResultPackage* rstptr) {
    // This is the implementation for the method in your snippet
    if (health_data.TotalVirtualMemory == 0) return 0.0;
    
    uint64_t used = health_data.TotalVirtualMemory - health_data.TotalAvailVirtualMemory;
    double percentage = ((double)used / health_data.TotalVirtualMemory) * 100.0;
    
    // We also fill the ResultPackage for the UI as requested by the parameter
    UsedVirtualMemory(rstptr); 
    
    return percentage;
}