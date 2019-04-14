/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

/* 
 * File:   Schedulers.cpp
 * Author: sallyjanestern, averysand
 * 
 * Created on February 2, 2019, 3:49 PM
 */

#include "Schedulers.h"
#include <vector>
#include <queue>
#include <iostream>

Schedulers::Schedulers() {
}

void Schedulers::RR(std::vector<std::string> processes, std::vector<int> arrival_time,
        std::vector<int> total_time, std::vector<int> block_interval, int time_quantum, int block_duration) {
    cpu_time = 0;
    curr_process = 0;
    termination_count = 0;
    turnaround = 0;
    curr_slice = 0;
    bool re_add = false;
    std::queue<int> available_list; //ready queue
    std::deque<int> blocked_list; //blocked queue
    std::vector<bool> arrived(processes.size(), 0); //tracks processes that have arrived
    std::vector<int> finish_time(processes.size(), 0); //used to calculate turnaround
    std::vector<int> time_until_blocked(processes.size(), 0);
    std::vector<int> time_remaining(processes.size(), 0);
    std::vector<int> blocked_time_remaining(processes.size(), 0);

    for (int i = 0; i < processes.size(); ++i) { //initialize vectors for cpu_time = 0
        time_remaining[i] = total_time[i];
        time_until_blocked[i] = block_interval[i];
        if (arrival_time[i] == 0) {
            available_list.push(i);
            arrived[i] = true;
        } else {
            arrived[i] = false;
        }
    }

    std::cout << "RR " << block_duration << " " << time_quantum << "\n";

    //run RR
    while (termination_count != processes.size()) {
        curr_slice = 0;
        if (available_list.size() > 0) { //select new process from top of available list
            curr_process = available_list.front();
            available_list.pop();

            if (time_remaining[curr_process] <= time_quantum && time_remaining[curr_process] <= time_until_blocked[curr_process]) { //Termination
                curr_slice = time_remaining[curr_process];
                finish_time[curr_process] = cpu_time + curr_slice;
                termination_count++;
                std::cout << cpu_time << " " << processes[curr_process] << " " << curr_slice << " T\n";

            } else if (time_until_blocked[curr_process] <= time_quantum) { //Blocked
                curr_slice = time_until_blocked[curr_process];
                blocked_time_remaining[curr_process] = block_duration;
                blocked_list.push_back(curr_process);
                time_remaining[curr_process] -= curr_slice;
                time_until_blocked[curr_process] = 0;
                std::cout << cpu_time << " " << processes[curr_process] << " " << curr_slice << " B\n";

            } else { //Time Slice Expires
                curr_slice = time_quantum;
                time_until_blocked[curr_process] -= curr_slice;
                time_remaining[curr_process] -= curr_slice;
                re_add = true;
                std::cout << cpu_time << " " << processes[curr_process] << " " << curr_slice << " S\n";
            }
        } else { //Idle
            int peek = blocked_list.front();
            bool no_arrivals = true;
            for (int i = 0; i < processes.size(); ++i) { //check to see if a process will arrive before one becomes unblocked
                if (arrival_time[i] <= cpu_time + blocked_time_remaining[peek] && arrived[i] == false) { //tie goes to arrivals
                    curr_process = i;
                    arrived[i] = true;
                    no_arrivals = false;
                    curr_slice = arrival_time[curr_process] - cpu_time;
                    break;
                }
            }
            if (no_arrivals) { // otherwise next process will be first to unblock from blocked list
                curr_process = peek;
                blocked_list.pop_front();
                curr_slice = blocked_time_remaining[curr_process];
                time_until_blocked[curr_process] = block_interval[curr_process];
            }
            available_list.push(curr_process);
            std::cout << cpu_time << " <idle> " << curr_slice << " I\n";
        }

        cpu_time += curr_slice;

        //new process has arrived during current slice
        for (int i = 0; i < processes.size(); ++i) {
            if (arrival_time[i] <= cpu_time && arrived[i] == false) {
                available_list.push(i);
                arrived[i] = true;
            }
        }
        //check if processes become unblocked during current slice
        int pop_count = 0; //counter for currently unblocking processes
        for (int i = 0; i < blocked_list.size(); ++i) {
            if (curr_process != blocked_list[i]) { //decrease blocked time for blocked processes
                blocked_time_remaining[blocked_list[i]] -= curr_slice;
            }
            if (blocked_time_remaining[blocked_list[i]] <= 0) {
                pop_count++;
            }
        }
        for (int i = 0; i < pop_count; ++i) { //unblock processes that have served their time
            available_list.push(blocked_list.front());
            blocked_time_remaining[blocked_list.front()] = 0;
            time_until_blocked[blocked_list.front()] = block_interval[blocked_list.front()];
            blocked_list.pop_front();
        }
        //in the case of a time slice expiration, re-add the process to the available queue
        if (re_add == true) {
            available_list.push(curr_process);
            re_add = false;
        }

    }
    //calculate turnaround
    for (int i = 0; i < processes.size(); ++i) {
        turnaround += finish_time[i] - arrival_time[i];
    }
    turnaround = turnaround / processes.size();
    std::cout << cpu_time << " <done> " << turnaround << "\n";
}

void Schedulers::SPN(std::vector<std::string> processes, std::vector<int> arrival_time,
        std::vector<int> total_time, std::vector<int> block_interval, int block_duration) {

    std::priority_queue<std::pair<int, int>, std::vector<std::pair<int, int>>, std::greater<std::pair<int, int>>> available_list;
    std::vector<int> time_until_blocked;
    std::vector<int> blocked_time_remaining(processes.size(), 0);
    std::vector<bool> has_arrived(processes.size(), false);
    std::vector<int> time_remaining;
    cpu_time = 0;
    curr_process = 0;
    turnaround = 0;
    termination_count = 0;
    for (int i = 0; i < block_interval.size(); ++i) {

        time_until_blocked.push_back(block_interval[i]);
    }
    
    for (int i = 0; i < total_time.size(); ++i) {
        time_remaining.push_back(total_time[i]);
    }
    
    std::cout << "SPN " << block_duration << "\n";
    while (termination_count != processes.size()) {
        //see if any new processes have arrived
        for (int i = 0; i < processes.size(); ++i) {
            if (arrival_time[i] <= cpu_time && !has_arrived[i]) {
                available_list.push(std::make_pair(block_interval[i], i));
                has_arrived[i] = true;
            }
        }

        //if there is nothing in the available list then the system is idle
        if (available_list.size() == 0) {
            curr_slice = 0; // how long the system is idle for
            //increment by the second until a process has arrived or becomes unblocked
            while (available_list.size() == 0) {
                cpu_time++;
                curr_slice++;
                for (int i = 0; i < processes.size(); ++i) {
                    if (arrival_time[i] <= cpu_time && !has_arrived[i]) {
                        available_list.push(std::make_pair(block_interval[i], i));
                        has_arrived[i] = true;
                    }
                }
                update_blocked_SPN(blocked_time_remaining, time_until_blocked, block_interval, available_list, 1);
            }
            std::cout << cpu_time - curr_slice << " <idle> " << curr_slice << " I\n";
        }            //else, if processes are available
        else {
            //chose to run the first process in the available list and remove it from the list
            //the first process will be the one with the shortest block interval
            curr_process = available_list.top().second;
            available_list.pop();

            //will not terminate before blocks
            if (block_interval[curr_process] < time_remaining[curr_process]) {
                std::cout << cpu_time << " " << processes[curr_process] << " " << time_until_blocked[curr_process] << " B\n";

                //process will run until blocked
                time_remaining[curr_process] -= time_until_blocked[curr_process];
                cpu_time += time_until_blocked[curr_process];
                //update blocked processes
                update_blocked_SPN(blocked_time_remaining, time_until_blocked, block_interval, available_list, time_until_blocked[curr_process]);
                //the process is now blocked;
                blocked_time_remaining[curr_process] = block_duration;
                time_until_blocked[curr_process] = block_interval[curr_process];

            }                
            else {  //process will terminate

                std::cout << cpu_time << " " << processes[curr_process] << " " << time_remaining[curr_process] << " T\n";

                cpu_time += time_remaining[curr_process];
                termination_count++;
                blocked_time_remaining[curr_process] = -1;
                time_until_blocked[curr_process] = -1;
                update_blocked_SPN(blocked_time_remaining, time_until_blocked, block_interval, available_list, time_remaining[curr_process]);
                turnaround += cpu_time - arrival_time[curr_process];
                time_remaining[curr_process] = 0;
            }

        }
    }
    std::cout << cpu_time << " <done> " << turnaround / processes.size() << "\n";


}

void Schedulers::update_blocked_SPN(std::vector<int> &blocked_time_remaining, std::vector<int> &time_until_blocked, std::vector<int> block_interval,
        std::priority_queue<std::pair<int, int>, std::vector<std::pair<int, int>>, std::greater<std::pair<int, int>>> &available_list,
        int time_slice) {
    for (int i = 0; i < blocked_time_remaining.size(); ++i) {
        if (blocked_time_remaining[i] > 0) {
            //will no longer be blocked
            if (blocked_time_remaining[i] <= time_slice) {
                available_list.push(std::make_pair(block_interval[i], i));
                time_until_blocked[i] = block_interval[i];
                blocked_time_remaining[i] = 0;
            } else {
                blocked_time_remaining[i] -= time_slice;
            }
        }
    }

}

Schedulers::~Schedulers(void){}

