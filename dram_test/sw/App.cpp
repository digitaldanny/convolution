// Greg Stitt
// University of Florida

#include <stdlib.h>
#include <cmath>

#include "App.h"

using namespace std;

App::App(Board &board) : board(board) {

}

App::~App() {

}

void *App::safeMalloc(unsigned long numBytes) {

  return malloc(getSafeTransferSize(numBytes,1));
}

unsigned long App::getSafeTransferSize(unsigned long elements,
                                       unsigned int bytesPerElement) {
  
  return (unsigned long) ceil(elements*bytesPerElement/(float) sizeof(boardWord_t))*sizeof(boardWord_t);
}
