#include <stdio.h>
#include <stdlib.h>

int main() {
    int x = -42;
    int y = abs(x);  // This will be folded by GCC at compile time if your fold_abs_const is broken

    printf("y = %d\n", y);

    // A check that will fail if abs folding is wrong
    if (y != 42) {
        printf("BUG DETECTED: abs(-42) != 42\n");
        return 1;  // indicate test failed
    }

    return 0; // test passed
}