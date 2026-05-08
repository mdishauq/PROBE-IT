#include <iostream>
#include <iomanip>
#include <string>
#include <sstream>
#include "health_sensor.hpp"
#include <thread>
#include <mutex>
#include <condition_variable>
#include <csignal>
#include <atomic>

// Helper function to turn the Enum number into readable text
const char* UnitToString(DataUnit unit) {
    switch (unit) {
        case DataUnit::Bytes: return "Bytes";
        case DataUnit::KB:    return "KB";
        case DataUnit::MB:    return "MB";
        case DataUnit::GB:    return "GB";
        case DataUnit::TB:    return "TB";
        default:              return "??";
    }
}

//THREAD FUNCTIONS GLOBAL DECLARATION

void FreshDataFunc(health_sensor* clsptr);
void UICalculatorfunc(health_sensor* clsptr,health_sensor::ResultPackage* ramPkg,
        health_sensor::ResultPackage* pagePkg,health_sensor::ResultPackage* virtualPkg);
void PredictiveCalculationsfunc(health_sensor* sensor,double* cpu,double* ramLvl ,double* swapRatio);
void UIprinterfunc(health_sensor* clsptr,health_sensor::ResultPackage* ramPkg,
        health_sensor::ResultPackage* pagePkg,health_sensor::ResultPackage* virtualPkg);
void PredPrinterfunc(health_sensor* sensor);

//GLOBAL MUTEX VARIABLES
std::mutex DataMutex;     //mutex used to alert the FreshData
std::mutex PrintMutexA;   // shared between UICalculator and UIprinter
std::mutex PrintMutexB;   // shared between PredCalculator and PredPrinter

//condtion variables AND Return VARIABLES
std::condition_variable AlertCalculators;
std::condition_variable AlertFreshData;
std::condition_variable UICalculatorPrint;
std::condition_variable PredCalculatorPrint;

std::condition_variable UIprintTOCalculator;
std::condition_variable predprintTOCalculator;

// Thread-safe exit flag
std::atomic<bool> ProgramRunning(true);

// Flag control variables
bool DataAcquisitionFinished = false;
int CalculationFinished = 0;
bool UIDataReady = false;
bool PredDataReady = false;
bool UIprintDone = false;
bool PredPrintDone = false;

//OBJECTS(class,resultPKG)
health_sensor sensor;
health_sensor::ResultPackage ramPkg;
health_sensor::ResultPackage pagePkg;
health_sensor::ResultPackage virtualPkg;


//Predictive Analysis Global Variable
double cpu ;
double ramLvl ;
double swapRatio;

// Signal handler for graceful shutdown
void signalHandler(int signum) {
    ProgramRunning = false;
}

int main(int argc, char* argv[]) {

    // Register signal handler for Ctrl+C
    std::signal(SIGINT, signalHandler);

    //ALL THREADS
    ////-->capture snapshot of the data
    std::thread FreshDataThread(FreshDataFunc,&sensor);
    //-->RUNS simultaneously TWO THREADS (UI CAL,predictive Levels)
    std::thread UIcalThread(UICalculatorfunc,&sensor,&ramPkg,&pagePkg,&virtualPkg);
    std::thread PredCalThread(PredictiveCalculationsfunc,&sensor,&cpu,&ramLvl,&swapRatio);
    //-->RUNS simultaneously TWO THREADS (UI CAL PRINTER,predictive Levels PRINTER)
    std::thread UIprintThread(UIprinterfunc,&sensor,&ramPkg,&pagePkg,&virtualPkg);
    std::thread PredPrinterThread(PredPrinterfunc,&sensor);

    //THREADS JOIN
    FreshDataThread.join();
    UIcalThread.join();
    PredCalThread.join();
    UIprintThread.join();
    PredPrinterThread.join();

    return 0;
}

void FreshDataFunc(health_sensor* clsptr) {
    while (ProgramRunning) {
        clsptr->CPU_AttributesRetriver();
        clsptr->getsystemtimes();

        {
            std::lock_guard<std::mutex> lock(DataMutex);
            // Reset ALL flags before publishing new data
            DataAcquisitionFinished = true;
            CalculationFinished    = 0;
            UIDataReady            = false;
            PredDataReady          = false;
            UIprintDone            = false;
            PredPrintDone          = false;
        }
        AlertCalculators.notify_all();

        // Wait for both calculators to fully complete their chain
        std::unique_lock<std::mutex> lock(DataMutex);
        AlertFreshData.wait(lock, []{ return CalculationFinished == 2; });
        DataAcquisitionFinished = false; // reset for next cycle
    }
}



void UICalculatorfunc(health_sensor* clsptr,health_sensor::ResultPackage* ramPkg,
    health_sensor::ResultPackage* pagePkg,health_sensor::ResultPackage* virtualPkg){

while(ProgramRunning){
    
    std::unique_lock<std::mutex> lock(DataMutex);
    AlertCalculators.wait(lock, []{ return DataAcquisitionFinished;});
    if (!ProgramRunning) break;
    
    // 2. Run UI Calculators
    clsptr->UsedRamCalculator(ramPkg);
    clsptr->UsedPageFileCalculator(pagePkg);
    clsptr->UsedVirtualMemory(virtualPkg);
    lock.unlock();
    
    std::unique_lock<std::mutex> lockA(PrintMutexA);
    //WORKER ALERT PRINTER
    UIDataReady = true;
    UICalculatorPrint.notify_one();
    //WORKER WAIT FOR PRINTER TO FINISH
    UIprintTOCalculator.wait(lockA,[]{ return UIprintDone; });
    lockA.unlock();
    
    //ALERT FRESHDATA FOR NEXT SNAPSHOT
    std::lock_guard<std::mutex> lockB(DataMutex);
    CalculationFinished++;
    AlertFreshData.notify_all();
}

}

void PredictiveCalculationsfunc(health_sensor* sensor,double* cpu,double* ramLvl ,double* swapRatio){

while(ProgramRunning){
    std::unique_lock<std::mutex> lock(DataMutex);
    //wait till the FreshData Finishes it job
    AlertCalculators.wait(lock, []{ return DataAcquisitionFinished;});
    if (!ProgramRunning) break;
    
    // Predictive Levels
    *cpu = sensor->CpuWorkingLoad();
    *ramLvl = sensor->RamUsageLevel();
    *swapRatio = sensor->MemoryTOSwapRatio();
    lock.unlock();
    
    std::unique_lock<std::mutex> lockB(PrintMutexB);
    //WORKER ALERT PRINTER
    PredDataReady = true;
    PredCalculatorPrint.notify_one();
    predprintTOCalculator.wait(lockB,[]{return PredPrintDone;});
    lockB.unlock();
    
    //ALERT FRESHDATA FOR NEXT SNAPSHOT
    std::lock_guard<std::mutex> lockC(DataMutex);
    CalculationFinished++;
    AlertFreshData.notify_all();
}

}

void UIprinterfunc(health_sensor* clsptr,health_sensor::ResultPackage* ramPkg,
    health_sensor::ResultPackage* pagePkg,health_sensor::ResultPackage* virtualPkg){

while(ProgramRunning){
    std::unique_lock<std::mutex> lock(PrintMutexA);
    UICalculatorPrint.wait(lock,[]{return UIDataReady;});
    
    if (!ProgramRunning) break;
    
    // Build JSON output for usage metrics
    std::stringstream jsonOutput;
    jsonOutput << "{"
        << "\"type\":\"usage_metrics\","
        << "\"ram_used\":" << ramPkg->Value << ","
        << "\"ram_unit\":\"" << UnitToString(ramPkg->unit) << "\","
        << "\"page_file_used\":" << pagePkg->Value << ","
        << "\"page_file_unit\":\"" << UnitToString(pagePkg->unit) << "\","
        << "\"virtual_space\":" << virtualPkg->Value << ","
        << "\"virtual_unit\":\"" << UnitToString(virtualPkg->unit) << "\""
        << "}";
    
    std::cout << jsonOutput.str() << std::endl;
    std::cout.flush();

    //ALERT THE CALCULATOR ,PRINT IS DONE
    UIDataReady = false;
    UIprintDone = true;
    UIprintTOCalculator.notify_one();
}

}

void PredPrinterfunc(health_sensor* sensor){

while(ProgramRunning){
    std::unique_lock<std::mutex> lock(PrintMutexB);
    PredCalculatorPrint.wait(lock, []{return PredDataReady;});
    
    if (!ProgramRunning) break;
    
    // Read values while holding lock to prevent data races
    double cpuVal = cpu;
    double ramVal = ramLvl;
    double swapVal = swapRatio;
    
    // Determine system health status
    bool healthy = true;
    std::string alerts;
    
    if (swapVal > 1.0) {
        if (!alerts.empty()) alerts += " | ";
        alerts += "High Swap Ratio: System is RAM-starved";
        healthy = false;
    }
    if (cpuVal > 90.0) {
        if (!alerts.empty()) alerts += " | ";
        alerts += "Critical CPU bottleneck detected";
        healthy = false;
    }
    if (ramVal > 85.0) {
        if (!alerts.empty()) alerts += " | ";
        alerts += "Physical RAM nearing capacity";
        healthy = false;
    }
    
    std::string status = healthy ? "OPTIMAL" : "WARNING";
    
    // Build JSON output for health levels
    std::stringstream jsonOutput;
    jsonOutput << "{"
        << "\"type\":\"health_metrics\","
        << "\"cpu_load\":" << cpuVal << ","
        << "\"ram_saturation\":" << ramVal << ","
        << "\"memory_to_swap\":" << swapVal << ","
        << "\"status\":\"" << status << "\","
        << "\"alerts\":\"" << (alerts.empty() ? "System status is OPTIMAL" : alerts) << "\""
        << "}";
    
    std::cout << jsonOutput.str() << std::endl;
    std::cout.flush();

    //Printer Alert the Calculator
    PredDataReady = false;
    PredPrintDone = true;
    predprintTOCalculator.notify_one();
}

}
