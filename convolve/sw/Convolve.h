// Greg Stitt
// University of Florida

#ifndef _CONVOLVE_H_
#define _CONVOLVE_H_

#include "App.h"

#define ADDR_WIDTH 15
#define RAM_WORDS (1 << ADDR_WIDTH)
#define RAM_BYTES RAM_WORDS*4

#define MEM_IN_ADDR 0
#define MEM_OUT_ADDR 0
#define RAM0_CONFIG_ADDR ((1<<MMAP_ADDR_WIDTH)-8)
#define RAM1_CONFIG_ADDR ((1<<MMAP_ADDR_WIDTH)-7)
#define GO_ADDR ((1<<MMAP_ADDR_WIDTH)-6)
#define RST_ADDR ((1<<MMAP_ADDR_WIDTH)-5)
#define KERNEL_LOADED_ADDR ((1<<MMAP_ADDR_WIDTH)-4)
#define KERNEL_DATA_ADDR ((1<<MMAP_ADDR_WIDTH)-3)
#define SIGNAL_SIZE_ADDR ((1<<MMAP_ADDR_WIDTH)-2)
#define DONE_ADDR ((1<<MMAP_ADDR_WIDTH)-1)


typedef unsigned short appWord_t;

class Kernel {
  
 public:   
  Kernel(const appWord_t *kernel, unsigned int size);
  ~Kernel();

  unsigned int getSize() const;
  unsigned int *getKernel() const;

  friend std::ostream & operator<<(std::ostream& stream, const Kernel &k );

 protected:
  unsigned int *kernel;
  unsigned int size;
  bool allocated;
};


class Signal {
  
 public:
  Signal(const appWord_t *signal, unsigned int size);
  ~Signal();

  unsigned int getSize() const;
  unsigned int getUnpaddedSize() const;
  appWord_t *getSignal() const;

  friend std::ostream & operator<<(std::ostream& stream, const Signal &s );

 protected:
  appWord_t *signal;
  unsigned int size;
  unsigned int unpaddedSize;
  bool allocated;
};


class Convolve : public App {

 public:  

  Convolve(Board &board);
  ~Convolve();

  bool isDone();  
  void start(const appWord_t *signal, unsigned int signalSize,
             const appWord_t *kernel, unsigned int kernelSize);
  void getOutput(appWord_t *output, unsigned int outputSize);

  static const unsigned int MAX_KERNEL_SIZE = 128;
  // make sure to leave enough room for pre- and post-padding
  static const unsigned int MAX_SIGNAL_SIZE = (RAM_BYTES/sizeof(appWord_t))-2*(MAX_KERNEL_SIZE-1)*sizeof(appWord_t);
  static const unsigned int MAX_OUTPUT_SIZE = RAM_BYTES/sizeof(appWord_t);
  
protected:
  void start(Signal &signal, Kernel &kernel);

};

#endif
