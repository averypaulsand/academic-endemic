/*
 * bfs.h
 *
 *  Created on: Jun 9, 2019
 *      Author: averysand
 */

#ifndef BFS_H_
#define BFS_H_

#define MAZE_WIDTH (5)
#define ELEMENT_COUNT (MAZE_WIDTH * MAZE_WIDTH)
#define RANK(row, col) ((row) * MAZE_WIDTH + (col))
#define ROW(rank) ((rank)/MAZE_WIDTH)
#define COL(rank) ((rank)%MAZE_WIDTH)

int find_shortest_path(int start_rank, int goal_rank, const int obstacles[], int path[]);
#endif /* BFS_H_ */
