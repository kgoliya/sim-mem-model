# sim-mem-model
A lightweight simulation memory model for use with axi interface models.

## Description
This is a lightweight simulation memory model that can be easily incorporated into users' current testing environment. This memory model works best
if there is a need to simulate the very diverse memory structures while giving the illusion of a very large memory structure. This was developed as a memory model to be used with 
AWS FPGA Developer Environment to reduce the setup and calibration time of the DRAM memory simulators. This model can potentially decrease development and debug time. The model
keeps track of individual cache blocks of memory, each block being 64 bytes in size. 

An axi simualtion model is also provided for use with the memory model to mimick the bank infrastructure provided by AWS. For accurate simulation of the dram channel behavior 
please use models provided by AWS.

## Memory Simulation
The memory model has the following parameters:<br />
    **SIZE** - The number of cache blocks that the memory can hold <br />
    **FILL_RANDOM** - Set this parameter to 1 if the empty memory is to be filled with random bytes, otherwise its set to 0 <br />
    **REPORT_INCORRECT_ADDR** - Set the parameter to 1 to report read commands to addresses which have not been writtem yet <br />

The functions provided for memory simualtion are

### find_existing_exntry(in_address[63:0])
This function takes in a 64 bit address and searches for that address among all cache blocks and returns the index of the address where it is located. If the address 
is not found, the function returns -1

### fill_random 
This function returns a cache block of random 64 bytes.

### add_byte_to_existing_entry
This function writes a byte to the input address.

### add_cache_block_to_existing_entry
This function writes a full cache block starting from the input address.

### get_cache_block_from_entry
This function reads from the memory and returns the data stored in it.

### reset_memory
This function resets the memory.

## AXI Channel Simulation
The AXI simulation model has two models for use. If only one channel is required, use axi_interface_model and for multiple channels use multiple_axi_channels.<br />
The parameters are:<br />
    **NUM_CHANNELS** - The number of channels wanted for simulation. Each channel is an independant axi bus with its own memory structure<br />
    **READ_LATENCY** - Read latency required in cycles<br />
    **WRITE_LATENCY** - Write latency required in cycles<br />
    **MAX_IDS** - Maximum outstanding requests allowed. Set this to the correct value required for better simulation runtimes and memory usage<br />
    **SIZE** - Total size across all channels. If used with axi_interface_model, this parameter is the size of the memory for that channel. If used with multiple_axi_channels, this parameter will be divided for among NUM_CHANNELS<br />
    **FILL_RANDOM** - Set this parameter to 1 if the empty memory is to be filled with random bytes, otherwise its set to 0<br />
    **REPORT_INCORRECT_ADDR** - Set the parameter to 1 to report read commands to addresses which have not been writtem yet<br />
