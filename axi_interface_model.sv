
`include "sim_memory_model.sv"

module axi_interface_model #(parameter READ_LATENCY = 40, parameter WRITE_LATENCY = 30, parameter MAX_IDS = 64*1024, parameter SIZE = 64*1024, parameter FILL_RANDOM = 0, parameter REPORT_INCORRECT_ADDR = 0) 
(

    input clk,
    input resetn,
        
    input [15:0] awid,
    input [63:0] awaddr,
    input [7:0] awlen,
    input awvalid,
    output logic awready,

    input [15:0] wid,
    input [511:0] wdata,
    input [63:0] wstrb,
    input wlast,
    input wvalid,
    output logic wready,

    output logic [15:0] bid,
    output logic bvalid,
    input bready,

    input [15:0] arid,
    input [63:0] araddr,
    input [7:0] arlen,
    input arvalid,
    output logic arready,

    output logic [15:0] rid,
    output logic [511:0] rdata,
    output logic rvalid,
    output logic rlast,
    input rready
    

);

    sim_memory_model #(.SIZE(SIZE), .FILL_RANDOM(FILL_RANDOM), .REPORT_INCORRECT_ADDR(REPORT_INCORRECT_ADDR)) MEM();
    
    // Write Channel

    logic [MAX_IDS-1:0][15:0] write_queue_id;
    logic [MAX_IDS-1:0] write_queue_valid;
    logic [MAX_IDS-1:0][7:0] write_counter_value;
    logic [15:0] write_queue_head;
    logic [15:0] write_queue_tail;


    logic [15:0] requested_write_id;
    logic [63:0] requested_write_addr;
    logic [63:0] write_addr_offset;

    // Read Channel

    logic [MAX_IDS-1:0][15:0] read_queue_id;
    logic [MAX_IDS-1:0][63:0] read_queue_addr;
    logic [MAX_IDS-1:0][7:0] read_queue_len;
    logic [MAX_IDS-1:0] read_queue_valid;
    logic [MAX_IDS-1:0][7:0] read_counter_value;
    logic [15:0] read_queue_head;
    logic [15:0] read_queue_tail;









    always_ff @(posedge clk) begin
        if(!resetn) begin
            requested_write_id <= 'h0;
            requested_write_addr <= 'h0;
        end
        else if(awready && awvalid) begin
            requested_write_id <= awid;
            requested_write_addr <= awaddr;
        end
        else begin
            requested_write_id <= requested_write_id;
            requested_write_addr <= requested_write_addr;
        end
    end

    always_ff @(posedge clk) begin
        if(!resetn) begin
            write_addr_offset <= 'h0;
        end
        else if(awready && awvalid) begin
            write_addr_offset <= 'h0;
        end
        else if(wready && wvalid) begin
            write_addr_offset <= write_addr_offset + 'd64;
        end
        else begin
            write_addr_offset <= write_addr_offset;
        end
    end

    always_ff @(posedge clk) begin
        if(!resetn) begin
            awready <= 1'b1;
        end
        else if(awready && awvalid) begin
            awready <= 1'b0;
        end
        else if(wready && wvalid && wlast) begin
            awready <= 1'b1;
        end
        else begin
            awready <= awready;
        end
    end

    always_ff @(posedge clk) begin
        if(!resetn) begin
            wready <= 1'b0;
        end
        else if(awready && awvalid) begin
            wready <= 1'b1;
        end
        else if(wready && wvalid && wlast) begin
            wready <= 1'b0;
        end
        else begin
            wready <= wready;
        end
    end
    
    always_ff @(posedge clk) begin
        if(!resetn) begin
            MEM.reset_memory();  
        end
        else if(wvalid && wready) begin
            for(int j = 0;j<64;j++) begin
                if(wstrb[j] == 1'b1) begin
                    MEM.add_byte_to_existing_entry(requested_write_addr + write_addr_offset + j, wdata[j*8 +: 8]);
                end
            end
        end
    end



    always_ff @(posedge clk) begin
        if(!resetn) begin
            write_queue_head <= 'h0;
        end
        else if(wvalid && wlast && wready) begin
            if(write_queue_head == (MAX_IDS-1)) begin
                write_queue_head <= 'h0;
            end
            else begin
                write_queue_head <= write_queue_head + 1'b1;
            end
        end
        else begin
            write_queue_head <= write_queue_head;
        end
    end

    always_ff @(posedge clk) begin
        if(!resetn) begin
            write_queue_tail <= 'h0;
        end
        else if(bvalid && bready) begin
            if(write_queue_tail == (MAX_IDS-1)) begin
                write_queue_tail <= 'h0;
            end
            else begin
                write_queue_tail <= write_queue_tail + 1'b1;
            end
        end
        else begin
            write_queue_tail <= write_queue_tail;
        end
    end




    genvar i;

    for(i = 0;i<MAX_IDS;i++) begin

        always_ff @(posedge clk) begin
            if(!resetn) begin
                write_queue_id[i] <= 'h0;
            end
            else if(i == write_queue_head && awready && awvalid) begin
                write_queue_id[i] <= awid;
            end
            else begin
                write_queue_id[i] <= write_queue_id[i];
            end
        end

        always_ff @(posedge clk) begin
            if(!resetn) begin
                write_queue_valid[i] <= 'h0;
            end
            else if(i == write_queue_head && wvalid && wlast && wready) begin
                write_queue_valid[i] <= 1'b1;
            end
            else if(i == write_queue_tail && write_queue_valid[i] && bvalid && bready) begin
                write_queue_valid[i] <= 1'b0;
            end
            else begin
                write_queue_valid[i] <= write_queue_valid[i];
            end
        end

        always_ff @(posedge clk) begin
            if(!resetn) begin
                write_counter_value[i] <= 'h0;        
            end
            else if(i == write_queue_head && wvalid && wlast && wready) begin
                write_counter_value[i] <= WRITE_LATENCY;
            end
            else if(write_queue_valid[i] && write_counter_value[i] > 'h0) begin
                write_counter_value[i] <= write_counter_value[i] - 1'b1;
            end
            else begin
                write_counter_value[i] <= write_counter_value[i];
            end
        end


    end

    always_ff @(posedge clk) begin
        if(!resetn) begin
            bid <= 'h0;
            bvalid <= 1'b0;
        end
        else if(!bvalid && write_queue_valid[write_queue_tail] && write_counter_value[write_queue_tail] == 'h0) begin
            bid <= write_queue_id[write_queue_tail];
            bvalid <= 1'b1;
        end
        else if(bvalid && bready) begin
            bid <= bid;
            bvalid <= 1'b0;
        end
        else begin
            bid <= bid;
            bvalid <= bvalid;
        end
    end





    // Read Channel

    assign arready = 1'b1;





    logic [63:0] read_addr_offset;

    logic send_new_burst;


    always_ff @(posedge clk) begin
        if(!resetn) begin
            read_queue_head <= 'h0;
        end
        else if(arvalid && arready) begin
            if(read_queue_head == (MAX_IDS-1)) begin
                read_queue_head <= 'h0;
            end
            else begin
                read_queue_head <= read_queue_head + 1'b1;
            end
        end
        else begin
            read_queue_head <= read_queue_head;
        end
    end




    for(i = 0;i<MAX_IDS;i++) begin

        always_ff @(posedge clk) begin
            if(!resetn) begin
                read_queue_id[i] <= 'h0;
                read_queue_addr[i] <= 'h0;
                read_queue_len[i] <= 'h0;
            end
            else if(i == read_queue_head && arvalid && arready) begin
                read_queue_id[i] <= arid;
                read_queue_addr[i] <= araddr;
                read_queue_len[i] <= arlen;
            end
            else begin
                read_queue_id[i] <= read_queue_id[i];
                read_queue_len[i] <= read_queue_len[i];
                read_queue_addr[i] <= read_queue_addr[i];
            end
        end


        always_ff @(posedge clk) begin
            if(!resetn) begin
                read_queue_valid[i] <= 'h0;
            end
            else if(i == read_queue_head && arvalid && arready) begin
                read_queue_valid[i] <= 1'b1;
            end
            else if(i == read_queue_tail && read_queue_valid[i] && read_counter_value[i] == 'h0) begin
                read_queue_valid[i] <= 1'b0;
            end
            else begin
                read_queue_valid[i] <= read_queue_valid[i];
            end
        end

        always_ff @(posedge clk) begin
            if(!resetn) begin
                read_counter_value[i] <= 'h0;        
            end
            else if(i == read_queue_head && arvalid && arready) begin
                read_counter_value[i] <= READ_LATENCY;
            end
            else if(read_queue_valid[i] && read_counter_value[i] > 'h0) begin
                read_counter_value[i] <= read_counter_value[i] - 1'b1;
            end
            else begin
                read_counter_value[i] <= read_counter_value[i];
            end
        end


    end


    logic [15:0] requested_read_id;
    logic [63:0] requested_read_addr;

    logic [7:0] requested_read_len;

    logic requested_read_valid;

    logic read_new_queue_entry;
    
    always_ff @(posedge clk) begin
        if(!resetn) begin
            read_new_queue_entry <= 1'b0;
        end
        else if(read_queue_valid[read_queue_tail] && read_counter_value[read_queue_tail] == 'h0) begin
            read_new_queue_entry <= 1'b1;
        end
        else begin
            read_new_queue_entry <= 1'b0;
        end
    end


    //logic [MAX_IDS-1:0][15:0] read_queue_id;
    //logic [MAX_IDS-1:0][63:0] read_queue_addr;
    //logic [MAX_IDS-1:0][7:0] read_queue_len;

    always_ff @(posedge clk) begin
        if(!resetn) begin
            requested_read_id <= 'h0;
            requested_read_addr <= 'h0;
            requested_read_valid <= 1'b0;
        end
        else if(read_new_queue_entry) begin
            requested_read_id <= read_queue_id[read_queue_tail];
            requested_read_addr <= read_queue_addr[read_queue_tail];
            requested_read_valid <= 1'b1;
        end
        else begin
            requested_read_id <= requested_read_id;
            requested_read_addr <= requested_read_addr;
            requested_read_valid <= 1'b0;
        end
    end


    always_ff @(posedge clk) begin
        if(!resetn) begin
            requested_read_len <= 'h0;
        end
        else if(read_new_queue_entry) begin
            requested_read_len <= read_queue_len[read_queue_tail];
        end
        else if(rvalid && rready && requested_read_len > 'h0) begin
            requested_read_len <= requested_read_len - 1'b1;
        end
        else begin
            requested_read_len <= requested_read_len;
        end
    end
   


    always_ff @(posedge clk) begin
        if(!resetn) begin
           send_new_burst <= 1'b0;
        end
        else if(requested_read_valid || (rready && rvalid && requested_read_len > 'h0)) begin
            send_new_burst <= 1'b1;
        end
        else begin
            send_new_burst <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(!resetn) begin
            read_addr_offset <= 'h0;
        end
        else if(requested_read_valid) begin
            read_addr_offset <= 'h0;
        end
        else if(rready && rvalid) begin
            read_addr_offset <= read_addr_offset + 'd64;
        end
        else begin
            read_addr_offset <= read_addr_offset;
        end
    end
   

    always_ff @(posedge clk) begin
        if(!resetn) begin
            rid <= 'h0;
            rdata <= 'h0;
            rvalid <= 'h0;
            rlast <= 'h0;
        end
        else if(send_new_burst) begin
            rid <= requested_read_id;
            rdata <= MEM.get_cache_block_from_entry(requested_read_addr + read_addr_offset);
            rvalid <= 1'b1;
            rlast <= requested_read_len == 'h0 ? 1'b1 : 1'b0;
        end
        else if(rvalid && rready) begin
            rid <= rid;
            rdata <= rdata;
            rvalid <= 1'b0;
            rlast <= rlast;
        end
        else begin
            rid <= rid;
            rdata <= rdata;
            rvalid <= rvalid;
            rlast <= rlast;
        end
    end


    always_ff @(posedge clk) begin
        if(!resetn) begin
            read_queue_tail <= 'h0;
        end
        else if(rvalid && rlast && rready) begin
            if(read_queue_tail == (MAX_IDS-1)) begin
                read_queue_tail <= 'h0;
            end
            else begin
                read_queue_tail <= read_queue_tail + 1'b1;
            end
        end
        else begin
            read_queue_tail <= read_queue_tail;
        end
    end



endmodule



module multiple_axi_channels #(parameter NUM_CHANNELS = 4, parameter READ_LATENCY = 40, parameter WRITE_LATENCY = 30, parameter MAX_IDS = 64*1024, parameter SIZE = 64*1024, parameter FILL_RANDOM = 0, parameter REPORT_INCORRECT_ADDR = 0) 
(

    input clk,
    input resetn,
        
    input [NUM_CHANNELS-1:0][15:0] awid,
    input [NUM_CHANNELS-1:0][63:0] awaddr,
    input [NUM_CHANNELS-1:0][7:0] awlen,
    input [NUM_CHANNELS-1:0] awvalid,
    output logic [NUM_CHANNELS-1:0] awready,

    input [NUM_CHANNELS-1:0][15:0] wid,
    input [NUM_CHANNELS-1:0][511:0] wdata,
    input [NUM_CHANNELS-1:0][63:0] wstrb,
    input [NUM_CHANNELS-1:0] wlast,
    input [NUM_CHANNELS-1:0] wvalid,
    output logic [NUM_CHANNELS-1:0] wready,

    output logic [NUM_CHANNELS-1:0][15:0] bid,
    output logic [NUM_CHANNELS-1:0] bvalid,
    input [NUM_CHANNELS-1:0] bready,

    input [NUM_CHANNELS-1:0][15:0] arid,
    input [NUM_CHANNELS-1:0][63:0] araddr,
    input [NUM_CHANNELS-1:0][7:0] arlen,
    input [NUM_CHANNELS-1:0] arvalid,
    output logic [NUM_CHANNELS-1:0] arready,

    output logic [NUM_CHANNELS-1:0][15:0] rid,
    output logic [NUM_CHANNELS-1:0][511:0] rdata,
    output logic [NUM_CHANNELS-1:0] rvalid,
    output logic [NUM_CHANNELS-1:0] rlast,
    input [NUM_CHANNELS-1:0] rready
);

   
    genvar i;


    for(i = 0;i<NUM_CHANNELS;i++) begin : CHANNELS
        axi_interface_model #(.READ_LATENCY(READ_LATENCY), .WRITE_LATENCY(WRITE_LATENCY), .MAX_IDS(MAX_IDS), .SIZE(SIZE/NUM_CHANNELS), .FILL_RANDOM(FILL_RANDOM), .REPORT_INCORRECT_ADDR(REPORT_INCORRECT_ADDR))
        CHANNEL (
            .clk(clk),
            .resetn(resetn),

            .awid(awid[i]),
            .awaddr(awaddr[i]),
            .awlen(awlen[i]),
            .awvalid(awvalid[i]),
            .awready(awready[i]),

            .wid(wid[i]),
            .wdata(wdata[i]),
            .wstrb(wstrb[i]),
            .wlast(wlast[i]),
            .wvalid(wvalid[i]),
            .wready(wready[i]),

            .bid(bid[i]),
            .bvalid(bvalid[i]),
            .bready(bready[i]),

            .arid(arid[i]),
            .araddr(araddr[i]),
            .arlen(arlen[i]),
            .arvalid(arvalid[i]),
            .arready(arready[i]),

            .rid(rid[i]),
            .rdata(rdata[i]),
            .rvalid(rvalid[i]),
            .rlast(rlast[i]),
            .rready(rready[i])
        );
    end


endmodule
