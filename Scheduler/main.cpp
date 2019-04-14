/*
 * main - reads in an input file specifying processes and their attributes
 * outputs the results of running two scheduling algorithms, round-robbin and shortest-process-next
 */

/* 
 * File:   main.cpp
 * Author: averysand
 *
 * Created on February 2, 2019, 9:37 AM
 */

#include <cstdlib>
#include <iostream>
#include <fstream>
#include <vector>
#include <sstream>
#include <queue>
#include <string>

#include "Schedulers.h"

using std::cerr;
using std::cout;

int main(int argc, char** argv) {

    if (argc != 4) {
        cerr << "usage: assignment 1 file_name, block_duration, time_quantum\n";
        exit(1);
    }
    std::ifstream file;
    file.open(argv[1]);
    int block_duration = std::stoi(argv[2]);
    int time_quantum = std::stoi(argv[3]);
    if (!file.is_open()) {
    std::cout << "Error opening file\n";
    }
    std::vector<std::string> process;
    std::vector<int> arrival_time;
    std::vector<int> total_time;
    std::vector<int> block_interval;
    std::string line;
    std::string p;
    int a, t, b;
    while (std::getline(file, line)) {
        std::istringstream stream(line);
        stream >> p;
        stream >> a;
        stream >> t;
        stream >> b;
        process.push_back(p);
        arrival_time.push_back(a);
        total_time.push_back(t);
        block_interval.push_back(b);
    }
    Schedulers s;
    s.RR(process, arrival_time, total_time, block_interval, time_quantum, block_duration);
    s.SPN(process, arrival_time, total_time, block_interval, block_duration);
    file.close();
    return 0;
}
