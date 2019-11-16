// Greg Stitt
// University of Florida

#ifndef _DRAM_TEST_H_
#define _DRAM_TEST_H_

#include "App.h"

#define ADDR_WIDTH 15
#define RAM_WORDS (1 << ADDR_WIDTH)

#define MEM_IN_ADDR 0
#define MEM_OUT_ADDR 0
#define RST_ADDR ((1<<MMAP_ADDR_WIDTH)-8)
#define RAM0_CONFIG_ADDR ((1<<MMAP_ADDR_WIDTH)-7)
#define RAM1_CONFIG_ADDR ((1<<MMAP_ADDR_WIDTH)-6)
#define GO_ADDR ((1<<MMAP_ADDR_WIDTH)-5)
#define RAM0_ADDR_ADDR ((1<<MMAP_ADDR_WIDTH)-4)
#define RAM1_ADDR_ADDR ((1<<MMAP_ADDR_WIDTH)-3)
#define SIZE_ADDR ((1<<MMAP_ADDR_WIDTH)-2)
#define DONE_ADDR ((1<<MMAP_ADDR_WIDTH)-1)

#define NUM_RAND_TESTS 500

class DramTest : public App {

 public:  

  typedef unsigned short appWord_t;

  DramTest(Board &board);
  ~DramTest();

  bool start(unsigned int input, unsigned int addr);

  static const unsigned int MAX_SIZE = RAM_WORDS*sizeof(boardWord_t)/sizeof(appWord_t);

};

#endif
