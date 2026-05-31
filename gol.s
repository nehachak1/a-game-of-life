.section ".word"
   /* Game state memory locations */
  .equ CURR_STATE, 0x90001000       /* Current state of the game */
  .equ GSA_ID, 0x90001004           /* ID of the GSA holding the current state */
  .equ PAUSE, 0x90001008            /* Is the game paused or running */
  .equ SPEED, 0x9000100C            /* Current speed of the game */
  .equ CURR_STEP,  0x90001010       /* Current step of the game */
  .equ SEED, 0x90001014             /* Which seed was used to start the game */
  .equ GSA0, 0x90001018             /* Game State Array 0 starting address */
  .equ GSA1, 0x90001058             /* Game State Array 1 starting address */
  .equ CUSTOM_VAR_START, 0x90001200 /* Start of free range of addresses for custom vars */
  .equ CUSTOM_VAR_END, 0x90001300   /* End of free range of addresses for custom vars */
  .equ RANDOM, 0x40000000           /* Random number generator address */
  .equ LEDS, 0x50000000             /* LEDs address */
  .equ SEVEN_SEGS, 0x60000000       /* 7-segment display addresses */
  .equ BUTTONS, 0x70000004          /* Buttons address */

  /* States */
  .equ INIT, 0
  .equ RAND, 1
  .equ RUN, 2

  /* Colors (0bBGR) */
  .equ RED, 0x100
  .equ BLUE, 0x400

  /* Buttons */
  .equ JT, 0x10
  .equ JB, 0x8
  .equ JL, 0x4
  .equ JR, 0x2
  .equ JC, 0x1
  .equ BUTTON_2, 0x80
  .equ BUTTON_1, 0x20
  .equ BUTTON_0, 0x40

  /* LED selection */
  .equ ALL, 0xF

  /* Constants */
  .equ N_SEEDS, 4           /* Number of available seeds */
  .equ N_GSA_LINES, 10       /* Number of GSA lines */
  .equ N_GSA_COLUMNS, 12    /* Number of GSA columns */
  .equ MAX_SPEED, 10        /* Maximum speed */
  .equ MIN_SPEED, 1         /* Minimum speed */
  .equ PAUSED, 0x00         /* Game paused value */
  .equ RUNNING, 0x01        /* Game running value */

.section ".text.init"
  .globl main

main:
  li sp, CUSTOM_VAR_END /* Set stack pointer, grows downwards */ 

  while_true:
    call reset_game

    call get_input
    mv s0, a0 # s0: e

    li s1, 0 # s1: done
    
  while_not_done:
    mv a0, s0
    call select_action

    mv a0, s0
    call update_state

    call update_gsa
    call clear_leds
    call mask
    call draw_gsa
    call wait

    call decrement_step # save the output in done
    mv s1, a0

    call get_input # save the output in e
    mv s0, a0

    beqz s1, while_not_done
    j while_true
 
/* BEGIN:clear_leds */
clear_leds: 
  # initialize all LEDs to 0
  # called before drawing a new GSA on the screen
  li t0, 0 # initialize t0

  ori t0, t0, ALL # select all rows
  slli t0, t0, 4
  ori t0, t0, ALL # select all columns
  ori t0, t0, RED
  ori t0, t0, BLUE

  la t1, LEDS
  sw t0, 0(t1)

  ret
/* END:clear_leds */

/* BEGIN:set_pixel */
set_pixel:
  # turn on a specific LED using the memory mapped led register
  # it should keep the state of all the other pixels unmodified
  la t0, LEDS

  # t1: LED control command
  slli t1, a1, 4 # a1: y
  add t1, t1, a0 # a0: x

  li t2, 1
  slli t2, t2, 16
  add t1, t1, t2
  addi t1, t1, RED
  sw t1, 0(t0)

  ret
/* END:set_pixel */

/* BEGIN:wait */
wait:
  # add a delay to the execution of the program
  la t0, SPEED
  lw t1, 0(t0) # t1: game speed

  li t2, 1
  slli t2, t2, 10 # t2: counter variable (2^10)

  wait_loop:
    # decrement the initial value (2^10) by game speed each time
    sub t2, t2, t1
    bgez t2, wait_loop

    ret
/* END:wait */

/* BEGIN:set_gsa */
set_gsa:
  # sets a line at the specified location in the GSA
  slli t2, a1, 2 # a1: y-coordinate, multiplied by 4 (t2 = a1 * 4)

  la t0, GSA_ID
  lw t1, 0(t0) # t1: GSA_ID, either 0 or 1
  bnez t1, set_gsa1
  
  # set_gsa0:
    la t3, GSA0 # t3: GSA address
    j set_gsa_end

  set_gsa1:
    la t3, GSA1

  set_gsa_end:
    add t2, t2, t3 # we need to access (GSA adress + a1 * 4)
    sw a0, 0(t2) # a0: the line

    ret
/* END:set_gsa */

/* BEGIN:get_gsa */
get_gsa:
  # returns the GSA eleemnt at the location of y
  slli t2, a0, 2 # a0: y-coordinate, multiplied by 4 (t2 = a1 * 4)

  la t0, GSA_ID
  lw t1, 0(t0) # t1: GSA_ID, either 0 or 1
  bnez t1, get_gsa1

  # get_gsa0:
    la t3, GSA0 # So we need to access (t3 + t2)
    j get_gsa_end

  get_gsa1:
    la t3, GSA1 

  get_gsa_end:
    add t2, t2, t3
    lw a0, 0(t2) # a0: line at location y in the GSA

    ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
  # takes the GSA currently in use and reproduce it on the LEDs
  addi sp, sp, -8
  sw s0, 4(sp)
  sw ra, 0(sp)

  li s0, 0 # s0: y

  draw_loop:
    mv a0, s0 # a0: y-coordinate

    call get_gsa # a0: line at the location

    # t1: LED control command
    slli t1, s0, 4 # select s0-th row
    addi t1, t1, ALL # select all columns

    addi t1, t1, RED
    slli t0, a0, 16 # shift line (a0) by 16
    add t1, t1, t0 # so we have the new state at t0[27:16]
    
    la t0, LEDS
    sw t1, 0(t0)

    addi s0, s0, 1 # s0++
    li t0, N_GSA_LINES
    blt s0, t0, draw_loop

  draw_gsa_end:
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8

    ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:
  # initialize the current GSA to a random state
  addi sp, sp, -24
  sw s0, 20(sp)
  sw s1, 16(sp)
  sw s2, 12(sp)
  sw s3, 8(sp)
  sw s4, 4(sp)
  sw ra, 0(sp)

  li s0, N_GSA_LINES
  li s1, N_GSA_COLUMNS
  li s2, 0 # s2: number of lines looped (y), to be increased by s0

  random_gsa_over_lines:
    li s3, 0 # s3: number of pixels looped (x), to be increased by s1
    li s4, 0 # line at y

    random_gsa_over_pixels:
      la t0, RANDOM
      lw t1, 0(t0)
      and t1, t1, 1 # take the modulo 2 of LSB
      slli s4, s4, 1 # construct the line by adding new value at LSB
      add s4, s4, t1

      addi s3, s3, 1 # s3 + 1
      beq s3, s1, set_random_line # if s3 = s1
      j random_gsa_over_pixels

      set_random_line:
        mv a0, s4 # a0: line at y
        mv a1, s2 # a1: y-coordinate

        call set_gsa

        addi s2, s2, 1 # s2 + 1 // 11
        beq s2, s0, random_gsa_end # if s2 = s0
        j random_gsa_over_lines

  random_gsa_end:
    lw s0, 20(sp)
    lw s1, 16(sp)
    lw s2, 12(sp)
    lw s3, 8(sp)
    lw s4, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
  
    ret
/* END:random_gsa */

/* BEGIN:change_speed */
change_speed:
  # increment or decrement the Game speed (1~10, inclusive) by 1 depending on the argument
  la t0, SPEED
  lw t1, 0(t0) # t1: game speed before modification
  li t2, MAX_SPEED
  li t3, MIN_SPEED

  bnez a0, decrement_speed # a0: 0 if increment, 1 if decrement

  # increment_speed:
    beq t1, t2, change_speed_end # if t1 is already max, you can't increment it
    addi t1, t1, 1
    j change_speed_end

  decrement_speed:
    beq t1, t3, change_speed_end # if t1 is already min, you can't decrement it
    addi t1, t1, -1
    
  change_speed_end:
    sw t1, 0(t0)
    
    ret
/* END:change_speed */

/* BEGIN:pause_game */
pause_game:
  # pause or resume the game depending on the current state (invert Game paused)
  # 0 if the game is paused, 1 otherwise
  la t0, PAUSE
  lw t1, 0(t0)
  li t2, PAUSED
  li t3, RUNNING

  beq t1, t2, resume_action # if t1 == PAUSED, resume the game

  # pause_action:
    sw t2, 0(t0)
    j pause_game_end

  resume_action:
    sw t3, 0(t0)

  pause_game_end:

    ret
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:  
  # changes the number of steps that the game will run based on the input arguments
  # button 2: hundreds, button 1: tens, button 0: units (in hexadecimal)
  # more than one arguments can be set to 1
  la t0, CURR_STEP
  lw t1, 0(t0)

  change_button0:
    beqz a0, change_button1 # a0: 1 if b0 is pressed, 0 otherwise
    addi t1, t1, 1
  
  change_button1:
    beqz a1, change_button2 # a1: 1 if b1 is pressed, 0 otherwise
    addi t1, t1, 16

  change_button2:
    beqz a2, change_steps_end # a2: 1 if b2 is pressed, 0 otherwise
    addi t1, t1, 256

  change_steps_end:
    sw t1, 0(t0)

    ret
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
  # set the current GSA to the predefined seed state associated with the input (current Seed ID)
  addi sp, sp, -12
  sw s0, 8(sp)
  sw s1, 4(sp)
  sw ra, 0(sp)

  la s0, SEEDS # s0: SEEDS address
  slli a0, a0, 2 # a0: the current seed ID value, multipied by 4
  add s0, s0, a0 # s0: (a0 * 4 + SEEDS address) = seedi address
  lw s0, 0(s0)

  li s1, 0 # s1: y

  set_seed_loop:
    lw a0, 0(s0) # a0: seedi i-th word (the line)
    mv a1, s1 # a1: y

    call set_gsa

    addi s0, s0, 4 # to get next word in seedi
    
    li t0, N_GSA_LINES
    addi s1, s1, 1 # otherwise increase it by 1
    beq s1, t0, set_seed_end # if y (# of loop) was the last line, end loop
    j set_seed_loop

  set_seed_end:
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 12

    ret
/* END:set_seed */

/* BEGIN:increment_seed */
increment_seed:   
  # change the value of game seed based on the current state of the game
  addi sp, sp, -4
  sw ra, 0(sp)
  
  la t0, SEED
  lw t1, 0(t0) # t1: current seed id

  li t2, N_SEEDS
  addi t2, t2, -1
  bge t1, t2, increment_seed_random

  increment_seed_set:
    addi t1, t1, 1
    sw t1, 0(t0)
    
    mv a0, t1 # a0: seed ID
    sw t1, 0(t0) # update the seed in the memory
    call set_seed

    j increment_seed_end

  increment_seed_random:
    la t0, SEED
    li t1, N_SEEDS
    sw t1, 0(t0) # t1: current seed id
    call random_gsa
  
  increment_seed_end:
    lw ra, 0(sp)
    addi sp, sp, 4
  
  ret
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
  # check if the BUTTONS requires a change of state and perform it
  # do nothing but updating state, and corresponding actions will be handled by select_action
  addi sp, sp, -24
  sw s0, 20(sp)
  sw s1, 16(sp)
  sw s2, 12(sp)
  sw s3, 8(sp)
  sw s4, 4(sp)
  sw ra, 0(sp)

  mv s0, a0 # s0 <- a0: BUTTONS

  la s1, CURR_STATE
  lw s1, 0(s1)

  li s2, INIT
  li s3, RAND
  li s4, RUN

  update_state_JB:
    andi t0, s0, JB # t0: 0 if not pressed, JB if pressed
    beqz t0, update_state_JR

    # in RUN state, reset the game
    bne s1, s4, update_state_JR
    call reset_game

  update_state_JR:
    andi t0, s0, JR
    beqz t0, update_state_JC

    # in INIT/RAND, start the game from selected state
    beq s1, s4, update_state_JC

    la t0, CURR_STATE
    sw s4, 0(t0)

    la t0, PAUSE
    li t1, RUNNING
    sw t1, 0(t0)

  update_state_JC:
    andi t0, s0, JC
    beqz t0, update_state_end

    # check if current state is init, otherwise do nothing
    bne s1, s2, update_state_end

    # increase seed while t2 < t5 (jc < N)
    la t3, SEED
    lw t2, 0(t3)

    li t5, N_SEEDS

    # switch to RAND if t2 == t5
    bge t2, t5, update_state_JC_init_to_rand
    j update_state_end
    
    update_state_JC_init_to_rand:
      la t0, CURR_STATE
      sw s3, 0(t0)

  update_state_end:
    lw s0, 20(sp)
    lw s1, 16(sp)
    lw s2, 12(sp)
    lw s3, 8(sp)
    lw s4, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24

  ret
/* END:update_state */

/* BEGIN:select_action */
select_action:
  # call the correct action function depending on the button pressed
  # chose to perform only one action if multiple buttons are pressed
  addi sp, sp, -24
  sw s0, 20(sp)
  sw s1, 16(sp)
  sw s2, 12(sp)
  sw s3, 8(sp)
  sw s4, 4(sp)
  sw ra, 0(sp)

  mv s0, a0 # s0 <- a0: BUTTONS

  la s1, CURR_STATE
  lw s1, 0(s1)

  li s2, INIT
  li s3, RAND
  li s4, RUN

  select_action_JT:
    andi t0, s0, JT # t0: 0 if not pressed, JT if pressed
    beqz t0, select_action_JL

    # in RUN state, replace the current game state with a new random one
    bne s1, s4, select_action_JL
    call random_gsa

  select_action_JL:
    andi t0, s0, JL
    beqz t0, select_action_JR

    # in RUN state, decrease the speed of the game
    bne s1, s4, select_action_JR
    li a0, 1
    call change_speed

  select_action_JR:
    andi t0, s0, JR
    beqz t0, select_action_JC

    beq s1, s4, select_action_JR_run

    # in INIT/RAND, (run the game) with the selected amount of steps
    j select_action_JC

    select_action_JR_run:
      # increase the speed of the game
      li a0, 0
      call change_speed

  select_action_JC:
    andi t0, s0, JC
    beqz t0, select_action_BUTTON

    beq s1, s3, select_action_JC_rand
    beq s1, s4, select_action_JC_run

    select_action_JC_init:
      # go though the predefined seeds, one after the other
      call increment_seed
      j select_action_BUTTON

    select_action_JC_rand:
      # generate a new random game state
      call increment_seed
      j select_action_BUTTON

    select_action_JC_run:
      # start/pause
      call pause_game
      j select_action_BUTTON

  select_action_BUTTON:
    beq s1, s4, select_action_end

    li a0, 0 # initialize used registers
    li a1, 0
    li a2, 0

    # select_action_BUTTON_2
    andi t0, s0, BUTTON_2 # t0: 0 if not pressed
    beqz t0, select_action_BUTTON_1
    li a2, 1 # this line is skipped if the button is not pressed

    select_action_BUTTON_1:
      andi t0, s0, BUTTON_1
      beqz t0, select_action_BUTTON_0
      li a1, 1

    select_action_BUTTON_0:
      andi t0, s0, BUTTON_0
      beqz t0, select_action_BUTTON_end
      li a0, 1

    select_action_BUTTON_end:
      call change_steps

  select_action_end:
    lw s0, 20(sp)
    lw s1, 16(sp)
    lw s2, 12(sp)
    lw s3, 8(sp)
    lw s4, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 24
  
    ret
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
  # return the next state of a cell depending on the number of living neighbours
  # a0: number of live neighbouring cells
  # a1: examined cell state (1 if alive, 0 otherwise)
  li t2, 2
  li t3, 3

  li t1, 0 # to be returned, it should be 1 iff (a0 == 3) || (a0 == 2 && a1 == 1)
  beq a0, t3, cell_fate_alive
  beqz a1, cell_fate_end
  beq a0, t2, cell_fate_alive
  j cell_fate_end

  cell_fate_alive:
    li t1, 1

  cell_fate_end:
    mv a0, t1 # a0: 1 if the cell is alive, 0 otherwise

    ret
/* END:cell_fate */

/* BEGIN:find_neighbours */
find_neighbours:
  # return the number of the cell's living neighbours as well as the value of the cell itself
  addi sp, sp, -32
  sw s0, 28(sp)
  sw s1, 24(sp)
  sw s2, 20(sp)
  sw s3, 16(sp)
  sw s4, 12(sp)
  sw s5, 8(sp)
  sw s6, 4(sp)
  sw ra, 0(sp)

  li s4, 0 # initialize the count of living neighbours

  mv s0, a0 # (s0, s1): the current cell
  mv s1, a1
  li s2, -1 # dx
  li s3, -1 # dy

  find_neighbours_loop_y:
    add s5, s1, s3 # s5: y + dy

    bltz s5, add_ten # we did 0-1, so instead we check 10-1 (+10)
    li t0, N_GSA_LINES
    bge s5, t0, sub_ten # we did 9+1, so instead we check -1+1 (-10)
    j get_the_line

    add_ten:
      addi s5, s5, 10
      j get_the_line

    sub_ten:
      addi s5, s5, -10
      
    get_the_line:
      mv a0, s5 # a0: line y-coordinate
      call get_gsa # a0: the line at y=a0

    find_neighbours_loop_x:
      add t5, s0, s2 # t5: x + dx

      bltz t5, add_twelve # we did 0-1, so instead we check 12-1 (+12)
      li t0, N_GSA_COLUMNS
      bge t5, t0, sub_twelve # we did 11+1, so instead we check -1+1 (-12)
      j check_if_alive

      add_twelve:
        addi t5, t5, 12
        j check_if_alive

      sub_twelve:
        addi t5, t5, -12
        
      check_if_alive: # (t5, s5): the neighboring cell (in question)
        li t1, 1
        sll t1, t1, t5 # t1: mask, only 1 at the x-th position
        and t2, a0, t1 # t2: t1 if the cell is alive, 0 otherwise

        beqz t2, find_neighbours_loop_end # it is dead so we don't care
        addi s4, s4, 1 # increase the counter
      
        # check if (t5, s5) == (s0, s1)
        bne t5, s0, find_neighbours_loop_end
        bne s5, s1, find_neighbours_loop_end
        srl s6, t2, t5 # s6: state of the current cell
        j find_neighbours_loop_end

      find_neighbours_loop_end:
        addi s2, s2, 1 # dx++
        li t2, 2
        blt s2, t2, find_neighbours_loop_x # loop_x while dx < 2
        li s2, -1 # otherwise reset dx
        addi s3, s3, 1 # dy++
        blt s3, t2, find_neighbours_loop_y # loop_y while dy < 2
    
  find_neighbours_end:
    sub s4, s4, s6 # subtract one if the current cell is alive (where s6 == 1)
    mv a0, s4 # a0: number of living neighbours
    mv a1, s6 # a1: state of the current cell

    lw s0, 28(sp)
    lw s1, 24(sp)
    lw s2, 20(sp)
    lw s3, 16(sp)
    lw s4, 12(sp)
    lw s5, 8(sp)
    lw s6, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 32

    ret
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
  # update the next GSA according to the rules
  addi sp, sp, -16
  sw s0, 12(sp)
  sw s1, 8(sp)
  sw s2, 4(sp)
  sw ra, 0(sp)

  la t0, PAUSE
  lw t0, 0(t0)
  li t1, PAUSED

  beq t0, t1, update_gsa_end # it shouldn't do anything if the game is paused

  li s0, 0 # y
  
  update_gsa_loop_y:
    li s1, 0 # x
    li s2, 0 # the line being constructed
    
    update_gsa_loop_x:
      mv a0, s1
      mv a1, s0

      call find_neighbours
      call cell_fate # a0: 1 if the cell is alive, 0 otherwise
      
      sll a0, a0, s1
      add s2, s2, a0

      addi s1, s1, 1
      li t0, N_GSA_COLUMNS
      blt s1, t0, update_gsa_loop_x

    update_gsa_loop_x_end:
      # We are updating the other (next) GSA
      la t0, GSA_ID
      lw t1, 0(t0)
      xori t1, t1, 1
      sw t1, 0(t0)

      mv a0, s2 # a0: the line
      mv a1, s0 # a1: the y-coordinate

      call set_gsa

      # And we need to switch GSA_ID back to the current GSA
      la t0, GSA_ID
      lw t1, 0(t0)
      xori t1, t1, 1
      sw t1, 0(t0)

      addi s0, s0, 1
      li t0, N_GSA_LINES
      blt s0, t0, update_gsa_loop_y

    update_gsa_loop_y_end:
      # WHen the update is done, it must invert the GSA_ID
      la t0, GSA_ID
      lw t1, 0(t0)
      xori t1, t1, 1
      sw t1, 0(t0)

  update_gsa_end:
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 16

    ret
/* END:update_gsa */

/* BEGIN:get_input */
get_input:
  # read the BUTTONS and return its value
  la t0, BUTTONS
  lw a0, 0(t0) # a0: BUTTONS register
  sw zero, 0(t0) # clear BUTTONS register

  ret
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
  # RUN: return 1 if the current step is 0, otherwise return 0 after decrementing the step by 1 & displaying it
  # INIT, RAND: return 0 after displaying the step
  # It should be displayed even when the game is not running
  la t0, CURR_STEP
  lw t1, 0(t0)
  
  la t2, CURR_STATE
  lw t2, 0(t2)
  li t3, RUN

  li a0, 0

  beq t2, t3, decrement_step_run
  j decrement_step_display

  decrement_step_run:
    la t4, PAUSE
    lw t4, 0(t4)
    li t5, PAUSED

    beq t4, t5, decrement_step_display

    # and if CURR_STEP = 0
    beqz t1, decrement_step_return_one

    # otherwise (CURR_STEP > 0), decrement it by one
    addi t1, t1, -1
    sw t1, 0(t0)
    j decrement_step_display

    decrement_step_return_one:
      li a0, 1
  
  decrement_step_display:
    # here transform a decimal number into 3 hex digits
    li t0, 0xF # mask

    and t2, t1, t0 # t2: digit 0
    srli t1, t1, 4
    and t3, t1, t0 # t3: digit 1
    srli t1, t1, 4
    and t4, t1, t0 # t4: digit 2

    li t5, 0 # we'll map each digit to display value in t5
    la t0, font_data

    # now each digit's address: t0 + 4*(ti) !!

    slli t2, t2, 2
    add t2, t2, t0 # t2: address of digit 0's font_data
    lw t2, 0(t2) # t2: digit 0's font_data
    add t5, t5, t2
    
    slli t3, t3, 2
    add t3, t3, t0
    lw t3, 0(t3) # t3: digit 1's font_data
    slli t3, t3, 8 # should be saved at [15:8]
    add t5, t5, t3

    slli t4, t4, 2
    add t4, t4, t0
    lw t4, 0(t4) # t4: digit 2's font_data
    slli t4, t4, 16
    add t5, t5, t4

    lw t6, 0(t0) # t6: digit 3's font-date (always 0)
    slli t6, t6, 24
    add t5, t5, t6

    la t0, SEVEN_SEGS
    sw t5, 0(t0)

  decrement_step_end:

    ret
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
  # put the game in its default state
  addi sp, sp, -4
  sw ra, 0(sp)

  # current step = 1, displayed on the 7-SEG
  la t1, CURR_STEP
  li t0, 1
  sw t0, 0(t1)
  
  # game state = 0, displayed on the leds
  la t0, CURR_STATE
  li t1, INIT
  sw t1, 0(t0)

  # GSA_ID = 0
  la t0, GSA_ID
  li t1, 0
  sw t1, 0(t0)

  # PAUSE = PAUSED
  la t0, PAUSE
  li t1, PAUSED
  sw t1, 0(t0)

  # game speed = MIN_SPEED
  la t0, SPEED
  li t1, MIN_SPEED
  sw t1, 0(t0)

  # seed = 0
  la t0, SEED
  li t1, 0
  sw t1, 0(t0)

  mv a0, t1
  call set_seed

  call clear_leds
  call draw_gsa
  call decrement_step

  lw ra, 0(sp)
  addi sp, sp, 4

  ret
/* END:reset_game */

/* BEGIN:mask */
mask:
  # (1) set all wall locations to the dead state
  # i.e. apply the mask corresponding to the selected seed to the current GSA
  # in case of the random seed, use the last mask (N+1, mask4) -> here SEED_ID == N anyway
  # (2) draw the walls on the screen in blue
  addi sp, sp, -16
  sw s0, 12(sp)
  sw s1, 8(sp)
  sw s2, 4(sp)
  sw ra, 0(sp)

  # adress of MASK word address = MASKS address + SEED content * 4
  la t0, MASKS # t0: MASKS address
  la t1, SEED
  lw t1, 0(t1)
  slli t1, t1, 2 # t1: seed content * 4
  add s0, t0, t1 # s0: address of MASK word address
  lw s0, 0(s0) # s0: MASK word address (increased by 4)

  li s1, 0 # s1: gsa_loop count

  mask_gsa_loop:
    mv a0, s1 # a0: y-coordinate

    call get_gsa # a0: the line

    lw s2, 0(s0) # s2: corresponding MASK word
    and a0, a0, s2 # a0: new line with the mask
    mv a1, s1 # a1: y-coordinate

    call set_gsa

    xori s2, s2, -1 # s2: inverse of MASK (state)

    # t1: LED control command
    slli t1, s1, 4 # select s1-th row
    addi t1, t1, ALL

    addi t1, t1, BLUE
    slli t0, s2, 16 # state at [27:16]
    add t1, t1, t0

    la t0, LEDS
    sw t1, 0(t0)
    
    li t0, N_GSA_LINES
    beq s1, t0, mask_end # if y-coordinate (# of loop) was the last line, end loop
    addi s1, s1, 1 # otherwise s1++
    addi s0, s0, 4 # s0 += 4
    j mask_gsa_loop

  mask_end:
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 16
    
    ret
/* END:mask */

/* 7-segment display */
font_data:
  .word 0x3F
  .word 0x06
  .word 0x5B
  .word 0x4F
  .word 0x66
  .word 0x6D
  .word 0x7D
  .word 0x07
  .word 0x7F
  .word 0x6F
  .word 0x77
  .word 0x7C
  .word 0x39
  .word 0x5E
  .word 0x79
  .word 0x71

  seed0:
	.word 0xC00
	.word 0xC00
	.word 0x000
	.word 0x060
	.word 0x0A0
	.word 0x0C6
	.word 0x006
	.word 0x000
  .word 0x000
  .word 0x000

seed1:
	.word 0x000
	.word 0x000
	.word 0x05C
	.word 0x040
	.word 0x240
	.word 0x200
	.word 0x20E
	.word 0x000
  .word 0x000
  .word 0x000

seed2:
	.word 0x000
	.word 0x010
	.word 0x020
	.word 0x038
	.word 0x000
	.word 0x000
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000

seed3:
	.word 0x000
	.word 0x000
	.word 0x090
	.word 0x008
	.word 0x088
	.word 0x078
	.word 0x000
	.word 0x000
  .word 0x000
  .word 0x000


# Predefined seeds
SEEDS:
  .word seed0
  .word seed1
  .word seed2
  .word seed3

# 0 bit means a wall is at this location
mask0:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
  .word 0xFFF
  .word 0xFFF

mask1:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x1FF
	.word 0x1FF
	.word 0x1FF
  .word 0x1FF
  .word 0x1FF

mask2:
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
	.word 0x7FF
  .word 0x7FF
  .word 0x7FF

mask3:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

mask4:
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0xFFF
	.word 0x000
  .word 0x000
  .word 0x000

MASKS:
  .word mask0
  .word mask1
  .word mask2
  .word mask3
  .word mask4
