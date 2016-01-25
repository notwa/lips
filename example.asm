; lips example code: fibonacci numbers
; this isn't a particularily useful or realistic example,
; but it demonstrates syntax and various features in lips.

[max_n]: 47

fib:
    ; calculate the nth fibonacci number, caching results 1 to 47 to a table
    ; only valid for values of n between 0 and 47 inclusive.
    ; a0: n
    ; v0: Fn

    ; branch to return 0 if a0 <= 0.
    ; the + refers to the next + label, relative to here.
    ; ++ would refer to the + label after that, and so on.
    blez    a0, +

    ; note that this executes even if the branch is taken,
    ; due to the single delay slot of this MIPS CPU.
    ; pseudo-instruction clears (sets to 0) the 32-bit value of a register:
    cl      v0

    ; check if the input is within the bounds specified earlier.
    ; pseudo-instruction to branch if register > immediate:
    bgti    a0, @max_n, +

    ; offset the input for use with the look-up table.
    ; note that this executes even if the branch is taken,
    ; but won't break the functionality of the routine either way.
    ; pseudo-instruction translates into an addiu with a negated immediate:
    subiu   t0, a0, 1

    ; multiply by sizeof(word) which is 4, or 1 << 2.
    sll     t0, t0, 2

    ; load the value from the look-up table.
    ; pseudo-instruction utilizing addressing modes:
    lw      t9, fib_cache(t0)

    ; branch to return the look-up value if it's non-zero, meaning it has been cached.
    bnez    t9, +

    ; once again, note that this is the delay slot of the branch instruction.
    ; pseudo-instruction to copy the 32-bit value of one register to another:
    mov     v0, t9

    ; set up the following loop to calculate the fibonacci number.
    ; pseudo-instruction to load a 32-bit value into a register:
    li      t1, 0 ; F(0)
    li      t2, 1 ; F(1)

-:  ; here's a - label referred to later.
    ; - labels are like + labels, except
    ; they look upwards in the file instead of downwards.

    ; calculate the next fibonacci number.
    addu    t3, t1, t2

    ; push the previous values back, part 1.
    mov     t1, t2

    ; iterate to the next number.
    subiu   a0, a0, 1

    ; loop if it hasn't yet reached the nth fibonacci number.
    bnez    a0, -

    ; push the previous values back, part 2.
    ; this is put in the branch delay as a simple optimization.
    mov     t2, t3

    ; loop finished, copy the result to return.
    mov     v0, t1

    ; cache the result for next time.
    ; pseudo-instruction not unlike the previous lw:
    sw      v0, fib_cache(t0)

    ; here's the + label used at the start of the routine.
+:
    ; return to the function that called this routine.
    ; when jr is given without any arguments, `jr ra` is implied.
    jr

    ; there's nothing to do in the delay slot, so don't do anything.
    ; this is necessary, otherwise the next instruction or data
    ; following the routine would be executed.
    ; pseudo-instruction to do nothing:
    nop

    ; set up initial values in the look-up table.
fib_cache:
    ; lips doesn't yet have a way to specify "x, n times",
    ; so this will do for now.
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, 0
