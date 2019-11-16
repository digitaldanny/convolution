// Greg Stitt
// University of Florida
// main.cpp
//
// Description: This file is the software portion of the simple pipeline 
// application implemented on the FPGA.

#include <iostream>
#include <sstream>
#include <cstdlib>
#include <cassert>
#include <cstring>
#include <cstdio>

#include <unistd.h>

#include "Board.h"
#include "Timer.h"
#include "Convolve.h"

using namespace std;

//#define DEBUG

#define BIG_KERNEL Convolve::MAX_KERNEL_SIZE
#define MEDIUM_KERNEL 40
#define SMALL_KERNEL 4

#define BIG_SIGNAL Convolve::MAX_SIGNAL_SIZE
#define MEDIUM_SIGNAL 1000
#define SMALL_SIGNAL 10


void convolveSW(const unsigned short* input, unsigned int inputSize,
                const unsigned short* kernel, unsigned int kernelSize,
                unsigned short *output) {

  unsigned int i,j;
  unsigned int outputSize = inputSize+kernelSize-1;
  memset(output, 0, sizeof(unsigned short)*outputSize);

  for (i=0; i < outputSize; i++) {
    for (j=0; j < kernelSize; j++) {

      unsigned int temp;
      unsigned int product;
      unsigned int sum;
      temp = (i>=j && i-j < inputSize) ? input[i-j] : 0;
      product = (unsigned int) kernel[j]*temp;      
      product = product > 0xffff ? 0xffff : product;
      sum = product + (unsigned int) output[i] > 0xffff ? 0xffff : product+output[i];
      output[i] = sum; 
    }
  }
}


bool convolveHW(Convolve &convolve,
                const unsigned short* input, unsigned int inputSize,
                const unsigned short* kernel, unsigned int kernelSize,
                unsigned short *output) {

  unsigned int outputSize = inputSize+kernelSize-1;

  try {
      
      convolve.start(input, inputSize, kernel, kernelSize);
      while(!convolve.isDone());
      convolve.getOutput(output, outputSize);  
  }
  catch(...) {
      
      fflush(stderr);   
      return false;
  }
  
  return true;  
}


bool checkOutput(const unsigned short* sw, const unsigned short *hw, 
                 unsigned int outputSize, float &percentCorrect) {

  unsigned errors = 0;
  bool isCorrect = true;
  
  for (unsigned i=0; i < outputSize; i++) {
      
      if (sw[i] != hw[i]) {
          printf("Error for output %d: HW = %d, SW = %d\n", i, hw[i], sw[i]);
          errors++;
          isCorrect = false;
      }
  }   

  percentCorrect = (outputSize-errors) / (float) outputSize;
  return isCorrect;
}


bool test(Convolve &convolve,
          const unsigned short* input, unsigned int inputSize,
          const unsigned short* kernel, unsigned int kernelSize,
          unsigned short *swOutput, unsigned short *hwOutput,
          float &percentCorrect, float &speedup) {
  
  unsigned int outputSize = inputSize+kernelSize-1;
  Timer sw, hw;

  hw.start();
  convolveHW(convolve, input, inputSize, kernel, kernelSize, hwOutput);
  hw.stop();
  
  sw.start();
  convolveSW(input, inputSize, kernel, kernelSize, swOutput);
  sw.stop();
  
  speedup = (sw.elapsedTime())/(hw.elapsedTime());
  return checkOutput(swOutput, hwOutput, outputSize, percentCorrect);  
}


void testZeros(Convolve &convolve,
               unsigned short* input, unsigned int inputSize,
               unsigned short* kernel, unsigned int kernelSize,
               unsigned short *swOutput, unsigned short *hwOutput,
               float &percentCorrect, float &speedup) {

  for (unsigned i=0; i < inputSize; i++) {
      input[i] = 0;
  }

  for (unsigned i=0; i < kernelSize; i++) {
      kernel[i] = 0;
  }

  test(convolve,
       input, inputSize,
       kernel, kernelSize,
       swOutput, hwOutput,
       percentCorrect, speedup);
}


void testOnes(Convolve &convolve,
              unsigned short* input, unsigned int inputSize,
              unsigned short* kernel, unsigned int kernelSize,
              unsigned short *swOutput, unsigned short *hwOutput,
              float &percentCorrect, float &speedup) {

  for (unsigned i=0; i < inputSize; i++) {
      input[i] = 1;
  }

  for (unsigned i=0; i < kernelSize; i++) {
      kernel[i] = 1;
  }

  test(convolve,
       input, inputSize,
       kernel, kernelSize,
       swOutput, hwOutput,
       percentCorrect, speedup);
}


void testRandNoClip(Convolve &convolve,
                    unsigned short* input, unsigned int inputSize,
                    unsigned short* kernel, unsigned int kernelSize,
                    unsigned short *swOutput, unsigned short *hwOutput,
                    float &percentCorrect, float &speedup) {

  for (unsigned i=0; i < inputSize; i++) {
      input[i] = rand() % 0xf; // this should be small enough to not clip
  }

  for (unsigned i=0; i < kernelSize; i++) {
      kernel[i] = rand() % 0xf;
  }

  test(convolve,
       input, inputSize,
       kernel, kernelSize,
       swOutput, hwOutput,
       percentCorrect, speedup);
}


void testRand(Convolve &convolve,
              unsigned short* input, unsigned int inputSize,
              unsigned short* kernel, unsigned int kernelSize,
              unsigned short *swOutput, unsigned short *hwOutput,
              float &percentCorrect, float &speedup) {

  for (unsigned i=0; i < inputSize; i++) {
      input[i] = rand(); // this should produce values large enough to clip
  }

  for (unsigned i=0; i < kernelSize; i++) {
      kernel[i] = rand();
  }

  test(convolve,
       input, inputSize,
       kernel, kernelSize,
       swOutput, hwOutput,
       percentCorrect, speedup);
}


int main(int argc, char* argv[]) {
   
  if (argc != 2) {
    cerr << "Usage: " << argv[0] << " bitfile" << endl;
    return -1;
  }

  // setup clock frequencies
  vector<float> clocks(Board::NUM_FPGA_CLOCKS);
  clocks[0] = 100.0;
  clocks[1] = 133.0;
  clocks[2] = 100.0;
  clocks[3] = 100.0;
  
  cout << "Programming FPGA....";

  // initialize board
  Board *board;
  try {
    board = new Board(argv[1], clocks);
  }
  catch(...) {
    exit(-1);
  }

  Convolve convolve(*board);
  unsigned short *input;
  unsigned short *kernel;
  unsigned short *hwOutput;
  unsigned short *swOutput;
  unsigned int transferSize;
  float percentCorrect, speedup, score;

  transferSize = App::getSafeTransferSize(Convolve::MAX_SIGNAL_SIZE, sizeof(unsigned short));
  input = new unsigned short[transferSize];
  transferSize = App::getSafeTransferSize(Convolve::MAX_KERNEL_SIZE, sizeof(unsigned short));
  kernel = new unsigned short[transferSize];
  transferSize = App::getSafeTransferSize(Convolve::MAX_OUTPUT_SIZE, sizeof(unsigned short));
  hwOutput = new unsigned short[transferSize];
  swOutput = new unsigned short[Convolve::MAX_OUTPUT_SIZE];

  score = 0.0;
  
  /////////////////////////////////////////////////////////////////////////////

  cout << "Testing small signal/kernel with all 0s..." << endl;

  testZeros(convolve, input, SMALL_SIGNAL, 
            kernel, SMALL_KERNEL, 
            swOutput, hwOutput, 
            percentCorrect, speedup);

  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;

  score += percentCorrect*.05;
  
  /////////////////////////////////////////////////////////////////////////////

  cout << "Testing small signal/kernel with all 1s..." << endl;

  testOnes(convolve, input, SMALL_SIGNAL, 
           kernel, SMALL_KERNEL, 
           swOutput, hwOutput, 
           percentCorrect, speedup);

  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;

  score += percentCorrect*.10;

  /////////////////////////////////////////////////////////////////////////////

  cout << "Testing small signal/kernel with random values (no clipping)..." << endl;

  testRandNoClip(convolve, input, SMALL_SIGNAL, 
                 kernel, SMALL_KERNEL, 
                 swOutput, hwOutput, 
                 percentCorrect, speedup);
  
  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;
  
  score += percentCorrect*.10;

  /////////////////////////////////////////////////////////////////////////////
  
  cout << "Testing medium signal/kernel with random values (no clipping)..." << endl;
  
  testRandNoClip(convolve, input, MEDIUM_SIGNAL, 
                 kernel, MEDIUM_KERNEL, 
                 swOutput, hwOutput, 
                 percentCorrect, speedup);
  
  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;

  score += percentCorrect*.15;
  
  /////////////////////////////////////////////////////////////////////////////
  
  cout << "Testing big signal/kernel with random values (no clipping)..." << endl;
  
  testRandNoClip(convolve, input, BIG_SIGNAL, 
                 kernel, BIG_KERNEL, 
                 swOutput, hwOutput, 
                 percentCorrect, speedup);
  
  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;
  
  score += percentCorrect*.15;

   /////////////////////////////////////////////////////////////////////////////

  cout << "Testing small signal/kernel with random values..." << endl;

  testRand(convolve, input, SMALL_SIGNAL, 
           kernel, SMALL_KERNEL, 
           swOutput, hwOutput, 
           percentCorrect, speedup);
  
  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;
  
  score += percentCorrect*.1;

  /////////////////////////////////////////////////////////////////////////////
  
  cout << "Testing medium signal/kernel with random values..." << endl;
  
  testRand(convolve, input, MEDIUM_SIGNAL, 
           kernel, MEDIUM_KERNEL, 
           swOutput, hwOutput, 
           percentCorrect, speedup);
  
  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;

  score += percentCorrect*.15;
  
  /////////////////////////////////////////////////////////////////////////////
  
  cout << "Testing big signal/kernel with random values..." << endl;
  
  testRand(convolve, input, BIG_SIGNAL, 
           kernel, BIG_KERNEL, 
           swOutput, hwOutput, 
           percentCorrect, speedup);
  
  score += percentCorrect*.20;

  cout << "Percent correct = " << percentCorrect*100.0 << endl;
  cout << "Speedup = " << speedup << endl << endl;
  cout << "TOTAL SCORE = " << score*100 << " out of " << 100 << endl;
  

  delete[] input;
  delete[] kernel;
  delete[] swOutput;
  delete[] hwOutput;
  delete board;
  return 0;
}


