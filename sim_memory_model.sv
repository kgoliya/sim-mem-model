module sim_memory_model();

parameter SIZE = 64*1024;
parameter FILL_RANDOM = 0;
parameter REPORT_INCORRECT_ADDR = 0; 


logic [SIZE-1:0][63:0] seen_addr;

logic [SIZE-1:0][511:0] stored_data;  

logic [31:0] num_seen_addr;

function integer find_existing_entry;
    input [63:0] in_address;
    //output integer out_index;
    
    logic [63:0] int_seen_address;
    
    integer out_index;
    integer i;
    
    begin

        if(num_seen_addr == 32'h0) begin
            out_index = -1;
        end
        else begin
            for(i = num_seen_addr - 1'b1;i>=0;i--) begin
                int_seen_address = seen_addr[i];

                if(in_address >= int_seen_address && in_address < (int_seen_address + 32'd64)) begin
                    break;
                end
            end
            out_index = i;
            
        end
        find_existing_entry = out_index;
    end

endfunction

function [511:0] fill_random;
    
    logic [511:0] data_buffer;
    
    begin
        for(int i = 0;i<16;i++) begin
            data_buffer[i*32 +: 32] = $random;
        end
        
        fill_random = data_buffer;
    end
endfunction


function integer add_new_entry;
    input [63:0] in_address;

    logic [63:0] cba_addr;
    integer current_index;
    
    begin
        cba_addr = {in_address[63:6],6'h0};

        current_index = num_seen_addr;

        seen_addr[current_index] = cba_addr;

        stored_data[current_index] = fill_random();

        num_seen_addr = num_seen_addr + 1'b1;

        add_new_entry = current_index;
    end
endfunction

function integer add_byte_to_existing_entry;

    input [63:0] byte_address;
    input [7:0] data_byte;

    integer entry_index;
    
    logic [9:0] calculated_bit_pos;
    logic [511:0] stored_addr_data;

    integer memory_size_limit;

    begin

        memory_size_limit = SIZE;
        memory_size_limit = memory_size_limit - 16;
        
        entry_index = find_existing_entry(byte_address);


        if(entry_index == -1) begin
            entry_index = add_new_entry(byte_address);
            
            stored_addr_data = fill_random();
            
            calculated_bit_pos = byte_address[5:0] * 8;
            
            stored_addr_data[calculated_bit_pos +: 8] = data_byte;

            stored_data[entry_index] = stored_addr_data;

        end
        else begin
            stored_addr_data = stored_data[entry_index];

            calculated_bit_pos = byte_address[5:0] * 8;

            stored_addr_data[calculated_bit_pos +: 8] = data_byte;
            
            stored_data[entry_index] = stored_addr_data;
        end
        
        if(num_seen_addr >= memory_size_limit) begin
            $display("Seen Cache blocks : %d",num_seen_addr);
            $display("Data Structure full. Increase size of structure");
            add_byte_to_existing_entry = -1;
        end
        else begin
            add_byte_to_existing_entry = 1;
        end
        //$display("Entry Index : %0d,Byte Addr : %d, Addr : %0d,stored_data : %0x",entry_index, byte_address, seen_addr[entry_index], stored_data[entry_index]); 
    end
endfunction


function integer add_cache_block_to_existing_entry;
    input [63:0] block_address;
    input [511:0] data_cache_block;
    
    integer return_val;
    
    begin
        for(int i = 0;i<64;i++) begin
            return_val = add_byte_to_existing_entry((block_address + i),data_cache_block[i*8 +: 8]);
            if(return_val == -1) begin
                break;
            end
        end
        
        add_cache_block_to_existing_entry = return_val;
    end
    
endfunction


function [511:0] get_cache_block_from_entry;
    input [63:0] block_address;

    integer entry_index;

    logic [511:0] data_cache_block;

    begin
        entry_index = find_existing_entry(block_address);

        if(entry_index == -1) begin

            if(FILL_RANDOM == 1) begin
                data_cache_block = fill_random();
            end
            else begin
                data_cache_block = 512'h0;
            end

            if(REPORT_INCORRECT_ADDR == 1) begin
                $display("Reading cache block that was not written previously");
            end
            
        end
        else begin
            data_cache_block = stored_data[entry_index];
        end
        
        get_cache_block_from_entry = data_cache_block;
    end
    
endfunction

function reset_memory;
    begin

        seen_addr = 'h0;

        stored_data = 'h0;  

        num_seen_addr = 'h0;
        
    end
endfunction




endmodule
