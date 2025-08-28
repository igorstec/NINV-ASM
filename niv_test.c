// niv_test.c
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

// assembly function
extern void ninv(uint64_t *y, const uint64_t *x, uint64_t n);

// helper to print 128-bit results (for debugging)
static void print_result(const char *label, const uint64_t *val, size_t words) {
    printf("%s = 0x", label);
    for (ssize_t i = words - 1; i >= 0; i--) {
        printf("%016lx", val[i]);
    }
    printf("\n");
}

// compare result with expected (little endian word order)
static void check_result(const char *desc, const uint64_t *got, const uint64_t *expected, size_t words) {
    printf("Test: %s\n", desc);
    for (size_t i = 0; i < words; i++) {
        assert(got[i] == expected[i] && "Mismatch in result!");
    }
    printf("  -> Passed ✅\n\n");
}

int main(void) {
    const size_t words = 2; // 128-bit tests (n = 128, so n/64 = 2)

    uint64_t y[2];
    uint64_t expected[2];


    // --- Test 0: smallest x = 2---
    uint64_t x0[2] = {2, 0}; // x = 2
    for (size_t i = 0; i < words; i++) y[i] = 3;
    ninv(y, x0, 128);
    // TODO: put expected value for x=5 into expected[]
    expected[0] = 0x0000000000000000; expected[1] = 0x8000000000000000;
    // expected[0] = ...; expected[1] = ...;
    check_result("x = 2 (smallest x)", y, expected, words);


    // --- Test 1: Small odd x ---
    uint64_t x1[2] = {5, 0}; // x = 5
    for (size_t i = 0; i < words; i++) y[i] = 3;
    ninv(y, x1, 128);
    
    // TODO: put expected value for x=5 into expected[]
    expected[0] = 0x3333333333333333; expected[1] = 0x3333333333333333;
    // expected[0] = ...; expected[1] = ...;
    check_result("x = 5 (small odd number)", y, expected, words);

    // --- Test 2: Small even x ---
    uint64_t x2[2] = {10, 0}; // x = 10
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x2, 128);
    // TODO: fill in expected
    expected[0] = 0x9999999999999999; expected[1] = 0x1999999999999999;
    check_result("x = 10 (small even number)", y, expected, words);

    // --- Test 3: x close to power of two ---
    uint64_t x3[2] = { (1ULL << 63) - 1, 0 }; // just below 2^63
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x3, 128);
    // TODO: fill in expected
    expected[0] = 0x0000000000000004; expected[1] = 0x0000000000000002;
    check_result("x = 2^63 - 1 (edge near power of two)", y, expected, words);

    // --- Test 5: Large x near maximum for 128-bit ---
    uint64_t x5[2] = {0xffffffffffffffffULL, 0xffffffffffffffffULL}; // max value
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x5, 128);
    // TODO: fill in expected
    expected[0] = 0x0000000000000001; expected[1] = 0x0000000000000000;
    check_result("x = max 128-bit value", y, expected, words);

    // --- Test 6: x = 2^64 ---
    uint64_t x6[2] = {0, 1}; // 128-bit: 2^64
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x6, 128);
    expected[0] = 0x0000000000000000; expected[1] = 0x0000000000000001;
    check_result("x = 2^64 ", y, expected, words);

    // --- Test 8: x = 2^64 - 1 ---
    uint64_t x8[2] = {0xffffffffffffffffULL, 0}; // 128-bit: 2^64 - 1
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x8, 128);
    expected[0] = 0x0000000000000001; expected[1] = 0x0000000000000001;
    check_result("x = 2^64 -1 ", y, expected, words);

    


    // --- Test 4: x = 2^64 + 1 ---
    uint64_t x4[2] = {1, 1}; // 128-bit: 2^64 + 1
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x4, 128);
    // TODO: fill in expected
    expected[0] = 0xFFFFFFFFFFFFFFFF; expected[1] = 0x0000000000000000;
    print_result("Computed", y, words);
    check_result("x = 2^64 + 1 (multi-word input)", y, expected, words);

 
    // --- Test 7: x = 2^64 + 2 ---
    uint64_t x7[2] = {2, 1}; // 128-bit: 2^64 + 2
    for (size_t i = 0; i < words; i++) y[i] = 0;
    ninv(y, x7, 128);
    expected[0] = 0xFFFFFFFFFFFFFFFE; expected[1] = 0x0000000000000000;
    print_result("Computed", y, words);
    check_result("x = 2^64 +2 ", y, expected, words);



    printf("All tests completed.\n");
    return 0;
}
