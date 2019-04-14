#include <iostream>    
#include <algorithm> 
#include <ctime>   
#include <math.h>  
#include <random>
#include <fstream>
#include <cstring>
#include <time.h>
#include <fstream>

const int population = 304, vehicles = 21, capacity = 794, num_ants = 20, max_iter = 30;
const float trail_persistence = .1, heuristic_weight = 5, pheremone_weight = 1, pheremone_value = .075; 
float xCoord[population], yCoord[population];
float pheremone_trail[population][population], heuristic[population][population], transition_probability[population]; 
float denominator = 0;
int iter = 0, prev_city = 0, chosen = 0;
int demand[population];
std::vector<int> curr_route, best_route;
float best_distance = 1000000;

void ReadData(std::string input);
void print();
void initialize();
int choose();
float get_distance(int i, int j);

float random_float(float min, float max)
{
	std::random_device rd;
	std::mt19937 gen(rd());
	std::uniform_real_distribution<> dis(min, max);
	return dis(gen);
}
float get_route_distance(std::vector<int> route) {
	float distance = 0;
	for (int i = 0; i < population - 1; i++) {
		distance += get_distance(route[i], route[i + 1]);
	}
	return distance;
}


int main() {
	std::ofstream myFile;
	myFile.open("results.txt");
	int start_s = clock();
	std::string input = "s303v21c794.txt"; //s100v25c206.txt, s303v21c794.txt, s1000v43c131.txt
	ReadData(input);
	//print();
	initialize();
	int max_city = 0, curr_city = 0;
	double q = .98, q_prob = 0, max = 0.0000000;
	bool explotation = false;
	while (iter < max_iter) {
		for (int i = 0; i < num_ants; i++) {
			curr_route.clear();
			curr_route.push_back(0); //start from depot
			for (int j = 1; j < population; j++) { // full route per ant
				q_prob = random_float(0, 1);
				explotation = false;
				for (int k = 1; k < population; k++) {//next move
					if (q <= q_prob) { //explotation
						explotation = true;
						curr_city = k;
						k = population;
					}
					else if (std::find(curr_route.begin(), curr_route.end(), k) != curr_route.end() == false) { 
						denominator += ((pow(pheremone_trail[prev_city][k], pheremone_weight)) * (pow(heuristic[prev_city][k], heuristic_weight)));
					}
				}
				if (explotation) {
					for (int d = 0; d < population; d++) { //calculate max city
						if (std::find(curr_route.begin(), curr_route.end(), d) != curr_route.end() || d == curr_city) {
						}
						else if (((pow(pheremone_trail[prev_city][d], pheremone_weight)) * (pow(heuristic[prev_city][d], heuristic_weight))) > max) {
							max = d;
							max_city = d;
						}
					}
					curr_route.push_back(max_city);
					pheremone_trail[prev_city][max_city] = (1 - trail_persistence) * pheremone_trail[prev_city][max_city] + (trail_persistence * (1 / (num_ants *pheremone_value))); //online pheremone update
					prev_city = max_city;
					explotation = false;
				}
				else{
					chosen = choose();
					curr_route.push_back(chosen);
					pheremone_trail[prev_city][chosen] = (1 - trail_persistence) * pheremone_trail[prev_city][chosen] + (trail_persistence * (1 / (num_ants * pheremone_value))); //online pheremone update
					prev_city = chosen;
				}
			}
			if (get_route_distance(curr_route) < best_distance) {
				best_distance = get_route_distance(curr_route);
				best_route.clear();
				for (int a = 0; a < population; a++) {
					best_route.push_back(curr_route[a]);
				}
			}
		}
		
		//offline pheremone update
		for (int i = 0; i < population - 1; i++) {
			pheremone_trail[best_route[i]][best_route[i + 1]] = (1 - trail_persistence) * pheremone_trail[best_route[i]][best_route[i + 1]] + (trail_persistence * (1 / best_distance));
		}
		iter++;
	}

	myFile << "Population: " << population - 1 << ", Vehicles: " << vehicles << ", Capacity: " << capacity << ", Number of Ants: " << num_ants << ", Max Iterations: " << max_iter << ", Heurisitic Weight: " << heuristic_weight << ", Pheromone Weight: " << pheremone_weight << "\n";
	//print results
	myFile << "Best Distance: " << best_distance << "\n" << "Route: ";
	for (int i = 0; i < population; i++) {
		if (i < population - 1) {
			myFile << best_route[i] << ", ";
		}
		else {
			myFile << best_route[i];
		}
	}
	myFile << "\n" << "\n";
	//split best route by truck/demand
	int load = 0, city_index = 0;
	std::vector<int> truck_route;
	for (int i = 0; i < vehicles; i++) {
		truck_route.clear();
		while (load <= capacity && city_index < population) {
			truck_route.push_back(best_route[city_index]);
			load += demand[best_route[city_index]];
			if (load <= capacity) {
				city_index++;
			}
		}
		myFile << "Truck " << i + 1 << ": ";
		for (int j = 0; j < truck_route.size(); j++) {
			if (j < truck_route.size() - 1) {
				myFile << truck_route[j] << ", ";
			}
			else {
				myFile << truck_route[j];
			}
		}
		myFile << "\n";
		load = 0;
	}
	int stop_s = clock();
	myFile << "\n" << "Execution Time: " << (stop_s - start_s) / double(CLOCKS_PER_SEC) << " seconds" << "\n";
	std::cout << "Finished";
	myFile.close();
	system("pause");
	return 0;
}
void ReadData(std::string input)
{
	FILE *infile;//open input file

	fopen_s(&infile, input.c_str(), "r");
	if (infile == NULL)
	{
		std::cout << "can't find the file!";
		exit(0);
	}

	for (int i = 0; i < population; i++)
	{
		fscanf_s(infile, "%f %f %d", &xCoord[i], &yCoord[i], &demand[i]);

	}
}

float get_distance(int i, int j)
{
	return (float) sqrt(pow(xCoord[i] - xCoord[j], 2) + pow(yCoord[i] - yCoord[j], 2));
}

void print() {
	for (int i = 0; i < population; i++) {
		std::cout << "City: " << i << " xCoord: " << xCoord[i] << " yCoord: " << yCoord[i] << " Demand: " << demand[i] << "\n";
	}
}
void initialize() {
	for (int i = 0; i < population; i++)
	{
		for (int j = 0; j < population; j++) {
			if (i != j) {
				heuristic[i][j] =  1 / get_distance(i, j);
				pheremone_trail[i][j] = pheremone_value;
			}
		}
	}
}
int choose() {
	float total = 0;
	int selected = 0;
	float ran = random_float(0, 1);
	for (int i = 0; i < population; i++) {
		if (std::find(curr_route.begin(), curr_route.end(), i) != curr_route.end()) { //already visited
			transition_probability[i] = 0;
		}
		else {
			transition_probability[i] = (((pow(pheremone_trail[prev_city][i], pheremone_weight)) * (pow(heuristic[prev_city][i], heuristic_weight))) / denominator);
		}
	}

	for (int i = 0; i < population; i++) {
		total += transition_probability[i];
		if (total >= ran) {
			selected = i;
			i = population;
		}
	}
	//reset
	for (int i = 0; i < population; i++) {
		transition_probability[i] = 0;
	}
	denominator = 0;
	return selected;
}
