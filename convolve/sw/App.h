// Greg Stitt
// University of Florida

#ifndef _APP_H_
#define _APP_H_

#include <iostream>
#include <cstdlib>
#include <cstring>
#include <cmath>

#include "Board.h"

/** \brief App (Application) class.
 *
 * This class provides a base class for all applications that can run
 * on a single FPGA of the PROCStarIII. All applications should be built
 * by creating a new derived class.  
 */

class App {
 public:
  App(Board &board);
  ~App();

  /** \brief A modifed malloc function that allocated a safe amount of memory
   *         for all transfers to/from the board.
   */

  static void *safeMalloc(unsigned long numBytes);

  /** \brief Ensures that the specified number of bytes (usually being
   *   allocated by malloc/new) matches the minimum transfer sizes on
   *   the board. If this method is not used, then data in memory may be
   *   overwritten, or there may be seg faults.
   */

  static unsigned long getSafeTransferSize(unsigned long elements,
					   unsigned int bytesPerElement);

 protected:
  Board &board;
  
  /** \brief Templatized read function for reading a single element of a given type.
   */
  template <class T>
    void read(T& data, unsigned long addr, MemId memId=MEM_INTERNAL);

  /** \brief Templatized read function for reading an array of a given type.
   *  \param size The number of T elements to read.
   *
   * This function will ensure that the correct number of words are transferred from the FPGA for
   * any specified size. Transferred data should be allocated using the App::malloc function.
   */
  template <class T>
    void read(T *data, unsigned long addr, unsigned long size, MemId memId=MEM_INTERNAL);

  /** \brief Templatized write function for writing a single element of a given type.
   */
  template <class T>
    void write(const T &data, unsigned long addr, MemId memId=MEM_INTERNAL);

  /** \brief Templatized write function for writing an array of a given type.
   *  \param size The number of T elements to write.
   *
   * This function will ensure that the correct number of words are transferred to the FPGA for
   * any specified size. Transferred data should be allocated using the App::malloc function.
   */
  template <class T>
    void write(const T *data, unsigned long addr, unsigned long size, MemId memId=MEM_INTERNAL);
};


template <class T>
void App::read(T& data, unsigned long addr, MemId memId) {
  
  unsigned long numWords = (unsigned long) ceil(sizeof(T)/(float) sizeof(boardWord_t));
  boardWord_t *temp = new boardWord_t[numWords];
  bool ok;
  ok = board.read((boardWord_t*)temp, addr, numWords);
  memcpy(&data, temp, sizeof(T));
  delete[] temp;
  if (!ok) throw "Failure in App::read()";    
}


template <class T>
void App::read(T *data, unsigned long addr, unsigned long size, MemId memId) {

  unsigned long numWords = (unsigned long) ceil(size*sizeof(T)/(float) sizeof(boardWord_t));
  bool ok=board.read((boardWord_t*)data, addr, numWords);
  if (!ok) throw "Failure in App::read()";
}


template <class T>
void App::write(const T &data, unsigned long addr, MemId memId) {

  unsigned long numWords = (unsigned long) ceil(sizeof(T)/(float) sizeof(boardWord_t));
  boardWord_t *temp = new boardWord_t[numWords];
  memcpy(temp, &data, sizeof(T));
  bool ok = false;  
  ok = board.write((boardWord_t*)temp, addr, numWords);
  delete[] temp;
  if (!ok) throw "Failure in App::write()";
}


template <class T>
void App::write(const T *data, unsigned long addr, unsigned long size, MemId memId) {
  
  unsigned long numWords = (unsigned long) ceil(size*sizeof(T)/(float) sizeof(boardWord_t));
  bool ok=board.write((boardWord_t*)data, addr, numWords);
  if (!ok) throw "Failure in App::write()";
}

#endif
