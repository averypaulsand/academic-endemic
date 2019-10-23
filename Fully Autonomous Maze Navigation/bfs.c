/*
 * bfs.c
 *
 *  Created on: Jun 9, 2019
 *      Author: averysand
 */


#include <assert.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <assert.h>
#include <math.h>
#include <string.h>
#include "bfs.h"

//Structs
struct list_element_t_struct; // forward declaration
struct list_element_t_struct
{
    int rank;
    struct list_element_t_struct* next;
};
typedef struct list_element_t_struct list_element_t;
typedef struct {
    list_element_t *head;
    list_element_t *tail;
} list_t;

//creates empty list
list_t init_list(){
  list_t list;
  list.head = NULL;
  list.tail = NULL;
  return list;
}

//took from stack overflow, not sure why its necessary but otherwise the ranks are off
unsigned concatenate(unsigned x, unsigned y) {
    unsigned pow = 10;
    while(y >= pow)
        pow *= 10;
    return x * pow + y;
}

//push element to back of LL
void push_back(list_t* list, int rank){
    list_element_t* tmp = (list_element_t*) malloc(sizeof(list_element_t));
    assert(tmp != NULL);//out of heap memory

    tmp->rank = rank;
    tmp->next = NULL;

    //first element in list is both head and tail
    if (list->head == NULL){
        list->head = tmp;
        list->tail = tmp;
    }
    else{
        list->tail->next = tmp; //current tail points to new element
        list->tail = tmp; //new element is tail
    }

}

//push element to front of LL
void push_front(list_t* list, int rank){
    list_element_t* tmp = (list_element_t*) malloc(sizeof(list_element_t));
    assert(tmp != NULL);//out of heap memory

    tmp->rank = rank;
    tmp->next = list->head;

    //first element in list is both head and tail
    if (list->head == NULL){
        list->head = tmp;
        list->tail = tmp;
    }
    else{
        list->head = tmp; //new element is head
    }
}

//free memory allocated by all elements in the list
void free_list(list_t *list){
    list_element_t *next = list->head, *tmp = NULL;

    while (next != NULL){
        tmp = next->next;
        free(next);
        next = tmp;
    }
    *list = init_list(); //derefernce and set to a new empty list
}

//removes the head of the list
int remove_front(list_t* list){

    //empty list
    if (list->head == NULL){
        return -1;
    }

    list_element_t *new_head = list->head->next;
    int rank = list->head->rank;
    free(list->head);
    list->head = new_head;

    //last element was removed
    if (list->head == NULL){
        *list = init_list(); //dereference and set to a new empty list
    }

    //success - return the rank of the element removed
    return rank;

}

//Find all Neighbors within the Domain [Bottom, Top, Right, Left]
void fill_neighbors(int neighbors[], int rank){

    //Convert rank into Row and Column Values
    int row = ROW(rank);
    int col = COL(rank);

    //*Find Neighbors*
    //Bottom
    if (row + 1 < MAZE_WIDTH){
       neighbors[0]= RANK(row + 1, col);
    }
    else{
        neighbors[0] = -1;     //out of bounds
    }

    //Top
    if (row - 1 >= 0){
       neighbors[1]= RANK(row - 1, col);
    }
    else{
        neighbors[1] = -1;     //out of bounds
    }

    //Right
    if (col + 1 < MAZE_WIDTH){
           neighbors[2]= RANK(row, col + 1);
        }
        else{
            neighbors[2] = -1;     //out of bounds
        }

    //Left
    if (col - 1 >= 0){
        neighbors[3]= RANK(row, col - 1);
    }
    else{
        neighbors[3] = -1;     //out of bounds
    }
}

int find_shortest_path(int start_rank, int goal_rank, const int obstacles[], int path[]){

    int predecessors[ELEMENT_COUNT], neighbors[ELEMENT_COUNT];

    //Initialize predecessors list
    for (int i = 0; i < ELEMENT_COUNT;i++){

        //Blocked
        if(obstacles[i] == 1){
            predecessors[i] = -2;
        }
        //Open
        else{
            predecessors[i] = -1;
        }
    }

    predecessors[start_rank] = start_rank; //starting point

    list_t waiting_list = init_list();
    push_back(&waiting_list, start_rank);

    while(1){

        int rank = remove_front(&waiting_list); //pop top

        //Reached the Goal
        if (rank == goal_rank){
            break;
        }

        fill_neighbors(neighbors, rank); //collect neighbors

        int bottom_neighbor = neighbors[0];
        int top_neighbor = neighbors[1];
        int right_neighbor = neighbors[2];
        int left_neighbor = neighbors[3];

        //Add All Undiscovered Neighbors Within the Boundries to Waiting List
        if (bottom_neighbor != -1 && predecessors[bottom_neighbor] == -1){
            push_back(&waiting_list, bottom_neighbor);
            predecessors[bottom_neighbor] = rank;
        }
        if (top_neighbor != -1 && predecessors[top_neighbor] == -1){
            push_back(&waiting_list, top_neighbor);
            predecessors[top_neighbor] = rank;
        }
        if (right_neighbor != -1 && predecessors[right_neighbor] == -1){
            push_back(&waiting_list, right_neighbor);
            predecessors[right_neighbor] = rank;
        }
        if (left_neighbor != -1 && predecessors[left_neighbor] == -1){
            push_back(&waiting_list, left_neighbor);
            predecessors[left_neighbor] = rank;
        }
    }

    //Traverse Parents to Construct Shortest Path (start->finish)
    list_t shortest_path = init_list();
    int parent = goal_rank;
    while(parent != start_rank){
        push_front(&shortest_path, parent);
        parent = predecessors[parent];
    }
    //add start_rank manually
    parent = predecessors[parent];
    push_front(&shortest_path, parent);

    //Print Shortest Path in Shape (row, col)
    int current_rank = remove_front(&shortest_path); //this will be start_rank
    int index = 0, real_rank  = 0;
    while (current_rank != goal_rank){
        //printintln(current_rank);
        int row = ROW(current_rank);
        int col = COL(current_rank);
        real_rank = concatenate(row, col);
        //printintln(real_rank);
        char row_col[100];
        path[index] = real_rank;
        //sprintf(row_col, "(%i, %i)", row, col);
        //printstrln(row_col);
        current_rank = remove_front(&shortest_path);
        index++;
    }
    //print goal_rank manually
    //int row = ROW(current_rank);
    //int col = COL(current_rank);
    //char row_col[100];
    //sprintf(row_col, "(%i, %i)", row, col);
    //printstrln(row_col);
    path[index] = goal_rank;
    
    //returns the length of the path
    return index + 1;
    
    //Deallocate Memory
    free_list(&waiting_list);
    free_list(&shortest_path);
}
