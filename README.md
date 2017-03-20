# PROFPRED

PROFPRED is a LLVM-based performance prediction framework for predicting computation and communication performance separately on small-scale prototypes of target systems. For computation prediction, it first predicts the total number of executed IR instructions by constructing a serial prediction program. Then it calculate the processing rate of IR instructions on the target parallel system by constructing a serial test program. Both processes are based on pruning technique which can convert a MPI program into corresponding serial program. For communication prediction, it model each communication operation of parallel programs based on regression-based method and use these models to achieve the prediction on small-scale prototype of target systems. Combining results of two parts can get the final prediction.

=========
# Build

1.  run git submodule init; git submodule update 
2.  Compile and install ***llvm-pred***
	```bash
    $ export CC=clang
    $ export CXX=clang++
	$ cd llvm-pred
    $ mkdir build;cd build
    $ cmake .. -DLLVM_RECOMMAND_VERSION="3.5"
    $ make;make install
	```
Use ``LLVM_RECOMMAND_VERSION`` to change llvm version directly

3.	Compile and install ***llvm-prof***
	```bash
	$ cd llvm-prof
    $ mkdir build;cd build
    $ cmake .. -DLLVM_RECOMMAND_VERSION="3.5"
    $ make;make install
	```

# Description

## Computation Prediction

1.	Convert the source code of given parallel program into corresponding LLVM IR
2.	Construction of a serial ***prediction program*** for a given parallel program
	```bash
    $ llvm-dis test.bc -o test.ll
	$ opt -load libLLVMPred.so -PerfPred -insert-pred-double-profiling test.ll -o test.1.ll -S
	$ opt -load libLLVMPred.so -Reduce test.1.ll -o test.2.ll -S
	$ opt -load libLLVMPred.so -Force -Reduce test.2.ll -o pred_program.ll -S
    $ clang pred_program.ll -o pred_program.o -c
    $ gfortran pred_program.o -o pred_program `pkg-config llvm-prof --variable=profile_rt_lib`
	```

3.	Construction of a serial ***test program*** for the given parallel program
	```bash
	$ opt -load libLLVMPred.so -Reduce test.ll -o test.1.ll -S
	$ opt -load libLLVMPred.so -Force -Reduce test.1.ll -o test_IR.ll -S
	$ opt -load libLLVMPred.so -insert-edge-profiling test_IR.ll -o test_program.ll -S
    $ clang test_program.ll -o test_program.o -c
    $ gfortran test_program.o -o test_program `pkg-config llvm-prof --variable=profile_rt_lib`
	$ llvm-as test_IR.ll -o test_IR.bc
	```

4.	Execute two serial program on one node of target parallel program to collect profiles about basic block frequencies

	If you want to predict the execution time of a given parallel program with 100 processes, the environment variable is set to "MPI_SIZE=100" and "MPI_RANK=0".
	```bash
	$ export MPI_RANK=0
	$ export MPI_SIZE=100
	$ ./pred_program
	$ ./test_program
	```
5.	Predict the computation performance	

	Get the predicted total number of executed IR instructions, and the processing rate of IR instructions on the target parallel system.    
	```bash
	$ llvm-prof test.bc  "the profile of pred_program" -inst-number
	$ llvm-prof test_IR.bc  "the profile of test_program" -inst-number
	```

## Communication Prediction

1.	Get the instrumented MPI program using ***MPI time instrumentation***
	```bash
    $ opt -load libLLVMPred.so -insert-time-profiling test.ll -o test.1.ll -S
    $ clang test.1.ll -o instrumented_program.o -c
    $ mpif90 instrumented_program.o -o instrumented_program `pkg-config llvm-prof --variable=profile_rt_lib`
	```

2.	Execute  the instrumented mpi program to collect execution time of each communication operation of rank 0
	```bash
    MASTER_RANK=0 mpirun -np <num> ./instrumented_program 
	```

3.	Get the results from profiles
	```bash
	llvm-prof test.bc "one profile of instrumented_program"
	```
4.	Model each communication operation based on regression-based method

## Example

This project includes an example (Sweep3D) about predicting performance of parallel program
