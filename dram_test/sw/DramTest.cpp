// Greg Stitt
// University of Florida

#include <iostream>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <cstdlib>

#include "DramTest.h"

using namespace std;

DramTest::DramTest(Board &board) : App(board) {

}

DramTest::~DramTest() {
  
}

bool DramTest::start(unsigned int size, unsigned int addr) {

  unsigned dmaWords = (unsigned long) ceil(size*sizeof(appWord_t)/(float) sizeof(boardWord_t));
  
  // make sure test doesn't exceed dram address space in memory map
  if (size+addr > MAX_SIZE)
    size = MAX_SIZE-addr;
  
  //  cout << "Testing size " << size << " and address " << addr << endl;
  
  // change to test smaller amounts  
  unsigned config = (dmaWords << ADDR_WIDTH) | addr;
  appWord_t go, done, rst;
  appWord_t *input, *output;
  
  input = (appWord_t *) safeMalloc(size*sizeof(appWord_t));
  output = (appWord_t *) safeMalloc(size*sizeof(appWord_t));
  assert(input != NULL);
  assert(output != NULL);

  // initialize input and output arrays
  for (unsigned i=0; i < size; i++) {
    
    input[i] = rand();
    output[i] = 0;    
  }

  // assert rst, cleared by memory map
  rst = 1;
  write(rst, RST_ADDR); 

  // enable dma transfer from software into ram 0
  write(config, RAM0_CONFIG_ADDR);
  
  // transfer all inputs
  write(input, MEM_IN_ADDR, size);
  write(size, SIZE_ADDR); 
  write(addr, RAM0_ADDR_ADDR); 
  write(addr, RAM1_ADDR_ADDR); 
  
  // assert go, cleared by memory map
  go = 1;
  write(&go, GO_ADDR, 1);
  
  // wait for the board to assert done
  done = 0;
  while (!done) {
    read(done, DONE_ADDR);
    
#ifdef DEBUG
    // wait 100 ms
    usleep(100000); 
#endif
  }
  
  // configure dma transfer from ram1 to software
  write(config, RAM1_CONFIG_ADDR);
  
  // read the outputs back from the FPGA
  read(output, MEM_OUT_ADDR, size);

  /*  for (unsigned i=0; i < size; i++) {

    cout << "Input = " << input[i] << " output = " << output[i] << endl;
  }
  */
  bool result = (memcmp(input, output, size*sizeof(appWord_t)) == 0);
  delete[] input;
  delete[] output;
  return result;
}



