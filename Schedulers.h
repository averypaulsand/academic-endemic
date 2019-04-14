/*
 * Schedulers - A class that holds two scheduling algorithms, round-robbin and shortest-process-next
 */

/* 
 * File:   Schedulers.h
 * Author: sallyjanestern, averysand
 *
 * Created on February 2, 2019, 3:49 PM
 */

#ifndef SCHEDULERS_H
#define SCHEDULERS_H
#include <vector>
#include <queue>
#include <string>

class Schedulers {
public:
    Schedulers();
    /**
     * RR - Round-Robbin scheduler. Chooses the next process to run by keeping an available list (arrived, non-blocked, non-terminated processes),
     * and selecting them sequentially
     *    
     * @param processes the names of the processes
     * @param arrival_time the arrival times of each process
     * @param total_time the total execution time required for each process
     * @param block_interval how long each process is able to run before blocking, unique to each process
     * @param time_quantum timer interrupt value
     * @param block_duration how long process stay blocked for,same for all processes
     */
    void RR(std::vector<std::string> processes, std::vector<int> arrival_time, std::vector<int> total_time,
            std::vector<int> block_interval, int time_quantum, int block_duration);
    /**
     * RR - Shortest Process Next scheduler. Chooses the next process to run by keeping an available list (arrived, non-blocked, non-terminated processes), 
     * and selecting them in order of shortest block interval
     *    
     * @param processes the names of the processes
     * @param arrival_time the arrival times of each process
     * @param total_time the total execution time required for each process
     * @param block_interval how long each process is able to run before blocking, unique to each process
     * @param block_duration how long process stay blocked for,same for all processes
     */
    void SPN(std::vector<std::string> processes, std::vector<int> arrival_time,
            std::vector<int> total_time, std::vector<int> block_interval, int block_duration);
    /**
     * update_blocked_SPN - helper function for the SPN scheduler, that updates the blocked processes, decreasing their time blocked,
     * and releasing them if they've served their time
     * @param blocked_time_remaining length of time a process still has being blocked
     * @param time_until_blocked length of time a process has until it is blocked 
     * @param block_interval how long each process is able to run before blocking, unique to each process
     * @param available_list a priority queue of the available processes, ordered by blocked_interval length (shortest first)
     * @param time_slice the duration of the current process being run
     */
    void update_blocked_SPN(std::vector<int> &blocked_time_remaining, std::vector<int> &time_until_blocked, std::vector<int> block_interval,
            std::priority_queue<std::pair<int, int>, std::vector<std::pair<int, int>>, std::greater<std::pair<int, int>>> &available_list,
            int time_slice);

    //Other constructors, assignment: prevent copy and move
    Schedulers(const Schedulers &other) = delete;
    Schedulers(Schedulers &&other) = delete;
    Schedulers operator=(const Schedulers &other) = delete;
    Schedulers operator=(Schedulers &&other) = delete;
    /**
     * Destructor - empty destructor
     */
    virtual ~Schedulers(void);
private:
    //private variables shared between both scheduling algorithms
    int cpu_time, termination_count, curr_process, curr_slice;
    double turnaround;
};

#endif /* SCHEDULERS_H */

