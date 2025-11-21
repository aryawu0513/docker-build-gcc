1. podman build -t my-gcc .
2. configure  and build my local gcc
mkdir build
cd /gcc-src/build
../configure --disable-bootstrap --disable-multilib --enable-languages=c,c++
make -j$(nproc)
make install


3. mount my local workdir to my container, so any changes in my local dir is immediately reflected.
podman run -it -v $(pwd)/gcc-src:/gcc-src my-gcc bash

4. Because i disabled bootstrap, i only have xgcc. 
root@32ed31d5fdf8:/gcc-src/build# find . -type f -executable -name 'xgcc*'
./gcc/xgcc


## An example.
Do one change in source file. 
Try gcc/fold-const.cc
fold_abs_const off-by-one error: add line   val = wi::add (val, wi::one (TYPE_PRECISION (type)));
let’s create a minimal test that exercises fold_abs_const. Since fold_abs_const is internal to GCC, we can’t call it directly from a normal test.c. But we can trigger it indirectly by compiling a program that uses abs() on a constant, because GCC’s constant folding will invoke fold_abs_const.

We run:
make -j$(nproc)     (this is sometimes not neccesray. Inside the same container, after one full build, small source changes sometimes appear “automatically” in make install because the previous build artifacts are still there.)
make install (in our example running this suffice)

Lets see if an outsider test.c can show that the bug is introduced.
Create test_foldconst.c in gcc-src.
Compile:
gcc -O2 -o /gcc-src/test_foldconst /gcc-src/test_foldconst.c
Execute:
/gcc-src/test_foldconst
root@32ed31d5fdf8:/gcc-src# /gcc-src/test_foldconst
y = 43
BUG DETECTED: abs(-42) != 42


Now i want to write a test suite for the fold_abs_const function. an entire cc test suite. i want to do #include test_fold_abs_const.cc inside the fold-const.cc.

GCC has a single entry point, its main() function. it is in gcc.c

 I want to do what i do for coretuils. which is, have a test_cat.c that have a mainfunction, remove the main function in  cat.c, have it #include test_cat.c, so when i do make src/cat.c and ./src/cat,.c, it executes the test file's main.

 Problem:
 I'm trying to:
	1.	Modify gcc/gcc/fold-const.cc (a .cc file in GCC source).
	2.	Test my changes by having a custom main() in a test file (foldconst_test.c), which has #include fold-const.cc
	3.	Include that test file into GCC’s build by doing #include

But compilation fails with multiple definition linker errors.
Why it Happens:

1. GCC Compilation Model
	•	GCC source files (.cc) are compiled individually into object files (.o):
	•	e.g., fold-const.cc → fold-const.o
	•	main.cc contains int main() for the compiler driver.
	•	All .o files are linked together to produce final binaries (cc1, cc1plus, etc.)

2. What I Tried: #include foldconst_test.c in main.cc
	•	Compiler now generates main.o containing another copy of all functions from fold-const.cc.
	•	fold-const.o already exists from normal compilation.
	•	During linking, the linker finds two definitions of the same function:
fold-const.o: fold_init()
main.o: fold_init()  <-- included again
	•	Result: multiple definition linker errors.


3. Why This Works in Coreutils
	•	In coreutils, when you do #include test_cat.c:
	•	You removed main() from the original cat.c
	•	You included a single new main, not duplicating already compiled functions.
	•	GCC is large and modular:
	•	Including .cc that already has other functions breaks the build.


I then try to not have foldconst_test.c include fold-const.cc. 
This give me a new error: not linker errors, but dependency/bootstrap build errors caused by modifying main.cc.

/usr/bin/nm: _floatundisf_s.o: no symbols
...
mv: cannot stat '.deps/gload.Tpo': No such file or directory
make[4]: *** [Makefile:656: gload.lo] Error 1

	•	GCC build system uses automake-generated .Tpo files for tracking dependencies.
	•	.Tpo files are created during compilation using the bootstrap compiler (xgcc).
	•	If .Tpo files are missing:
	•	The mv -f .deps/*.Tpo .deps/*.Plo command fails.
	•	This causes a fatal make error.
Swapping main():
•	Breaks the build system’s assumptions.
•	Causes missing .Tpo files and dependency failures.
•	Leads to compilation errors in independent libraries (libatomic, libgcc).


