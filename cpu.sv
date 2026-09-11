// ============================================================================
// MODULE: Memory (Single-Port RAM)
// ============================================================================
module memory_module (
    input  logic       clk,
    input  logic [7:0] addr,          // Memory address
    input  logic       write_en,      // Write enable
    input  logic [7:0] data_in,       // Data to write
    output logic [7:0] data_out       // Data read
);
    // Memory storage - exposed for testbench initialization
    logic [7:0] mem [0:255];

    // Initialize memory to 0
    initial begin
        for (int i=0; i<256; i++) mem[i] = 0;
    end

    // Asynchronous read
    assign data_out = mem[addr];

    // Synchronous write
    always_ff @(posedge clk) begin
        if (write_en) begin
            mem[addr] <= data_in;
        end
    end
endmodule

// ============================================================================
// MODULE: ALU
// ============================================================================
module alu (
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [1:0] func, // 00: NAND, 01: MULT, 10: SUB, 11: ADD
    output logic [7:0] result,
    output logic       zero // Indicates if result is zero
);
    // TODO: Implement ALU operations

    always @(*) begin
        case (func)
            0: result = ~(a && b);
            1: result = a * b;
            2: result = b - a;
            3: result = a + b;
        endcase
        zero = result == 0 ? 1 : 0;
    end

endmodule

function logic [1:0] ALUcontrolbits;
input [3:0] opcode;
begin
    case(opcode)
        4'b0000: ALUcontrolbits = 2'b00;
        4'b0100: ALUcontrolbits = 2'b10;
        4'b0101: ALUcontrolbits = 2'b01;
        4'b1000: ALUcontrolbits = 2'b10;
        default: ALUcontrolbits = 2'b11;
    endcase
end
endfunction

// ============================================================================
// MODULE: Control Unit
// ============================================================================
module control_unit (
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] opcode,
    input  logic       alu_zero,  // From ALU, for BEQ
    
    // Status
    output logic       halted,

    // Control Signals
    output logic       PCin,
    output logic       PCout,
    output logic       PCcontrol,
    output logic       IRin,
    output logic       IRout,
    output logic       Rdsin,
    output logic       Rdsout,
    output logic       Rsout,
    output logic       Imm,
    output logic       Xin,
    output logic       Zin,
    output logic       Zout,
    output logic       MARin,
    output logic       MDRin,
    output logic       MDRout,
    output logic       Read,
    output logic       Write
);
    
    typedef enum logic [4:0] {
        A, B, C, D, E, F, G, H, I, J, K, L, M, N, A2, H2, B2, M2
    } state_t;

    state_t state = A;
    //state change on clk cycle
    always @(posedge clk) begin
        if (reset) begin
            state <= A;
        end else if(state == A) begin
            state <= A2;
        end else if(state == A2) begin
            state <= B;
        end else if(state == B) begin 
            state <=B2;
        end else if(state == N || (state == B2 && opcode == 4'b1111)) begin 
            state <= N;
        end else if((state == B2 && opcode == 4'b0110) || (state == C && opcode == 4'b0010)) begin
            state <= H;
        end else if(state == B2 && opcode == 4'b0111) begin
            state <= L;
        end else if((state == C && opcode == 4'b0011) || (state == F)) begin
            state <= G;
        end else if(state == C) begin 
            state <= D;
        end else if((state == D && opcode == 4'b1000 && alu_zero) || (state == B2 && opcode == 4'b1001)) begin
            state <= F;
        end else if(state == B2) begin
            state <= C;
        end else if(state == L) begin
            state <= M;
        end else if(state == M) begin
            state <=M2;
        end else if(state == G && opcode[3] == 1) begin
            state <= K;
        end else if(state == H) begin
            state <= H2;
        end else if(state == H2 && opcode == 4'b0010) begin
            state <= J;
        end else if(state == H2) begin
            state <= I;
        end else if(state == G || state == F || state == J || (state == D && opcode != 4'b1000)) begin
            state <=E;
        end else begin
            state <=A;
        end
    end

    always @(*) begin
        //clear all the control signals
        halted = 0;
        PCin = 0;
        PCout = 0;
        IRin = 0;
        IRout = 0;
        Rdsin = 0;
        Rdsout = 0;
        Rsout = 0;
        Imm = 0;
        Xin = 0;
        Zin = 0;
        Zout = 0;
        MARin = 0;
        MDRin = 0;
        MDRout = 0;
        Read = 0;
        Write = 0;
        PCcontrol = 0;
        if(!reset) begin
            case(state) 
                A: begin    
                    PCout = 1;
                    PCin = 1;
                    MARin = 1;
                    
                end
                A2: begin
                    Read = 1;
                    MDRin = 1;
                end
                B: begin
                    MDRout = 1;
                    Read = 1;
                    IRin = 1;
                end
                C: begin
                    Rdsout = 1;
                    Xin = 1;
                end
                D: begin
                    Rsout = 1;
                    Zin = 1;
                end
                E: begin
                    Zout = 1;
                    Rdsin = 1;
                end
                F: begin
                    PCout = 1;
                    Xin = 1;
                end
                G: begin
                    IRout = 1;
                    Imm = 1;
                    Zin = 1;
                end
                H: begin
                    Rsout = 1;
                    MARin = 1;      
                end
                H2: begin
                    Read = 1;
                    MDRin = 1;
                end
                I: begin
                    MDRout = 1;
                    Rdsin = 1;
                end
                J: begin
                    MDRout = 1;
                    Zin = 1;
                end
                K: begin
                    Zout = 1;
                    PCin = 1;
                    PCcontrol = 1;
                end
                L: begin
                    Rdsout = 1;
                    MDRin = 1;
                end
                M: begin
                    Rsout = 1;
                    MARin = 1;
                end
                M2: begin
                    Write = 1;
                end
                N: halted = 1;    
            endcase
        end 
    end
endmodule


// ============================================================================
// MODULE: CPU (Datapath Top Level)
// ============================================================================
module cpu (
    input logic clk,
    input logic reset, 
    output logic halted
);

    // -- Storage --
    // Registers kept here so the testbench can access 'dut.registers'
    logic [7:0] registers [0:1];
    
    // -- Architectural Registers --
    logic [7:0] PC;
    logic [7:0] IR;

    // TODO: Define other necessary signals
    reg [7:0] X;
    reg [7:0] Z;
    reg [7:0] MDR;
    reg [7:0] MAR;
    logic [7:0] BUS;
    // ------------------------------------------------------------------------
    // 1. Instruction Decoding
    // ------------------------------------------------------------------------

    logic [3:0] opcode;
    logic ds_idx;
    logic s_idx;
    logic [3:0] immediate;
    logic [7:0] offset;

    assign opcode = IR[7:4];
    assign ds_idx = IR[3];
    assign s_idx  = IR[2];

    assign immediate = (opcode == 4'b0011) ? IR[2:0] : IR[3:0];
    assign offset = (immediate[3]) ? 8'b11110000 : 8'd0;
    //assign off_jmp = // TODO do i even need this?

    // ------------------------------------------------------------------------
    // 2. Memory Module Instantiation & Address Multiplexing
    // ------------------------------------------------------------------------
    // TODO: Define memory address logic
    
    logic[7:0] data_read;

    // Memory module instantiation
    memory_module mem_inst (
        .clk(clk),
        .addr(MAR),
        .write_en(write),
        .data_in(MDR),       // Data to write (from rds register)
        .data_out(data_read) // Data read from memory
    );

    // ------------------------------------------------------------------------
    // 3. Register File Access
    // ------------------------------------------------------------------------
    //done in control flow in step 5

    // ------------------------------------------------------------------------
    // 4. ALU & Datapath Muxes
    // ------------------------------------------------------------------------
    
    // TODO: Define ALU input multiplexing logic

    logic[7:0] alu_in_a;
    logic[7:0] alu_in_b;
    logic[1:0] alusel;
    logic[7:0] alu_result;
    logic alu_zero;
    assign alu_in_a = imm ? offset + immediate : BUS;
    assign alu_in_b = X;
    assign alusel = imm ? 3 : ALUcontrolbits(opcode);

    alu cpu_alu (
        .a(alu_in_a),
        .b(alu_in_b),
        .func(alusel),
        .result(alu_result),
        .zero(alu_zero)
    );

    // ------------------------------------------------------------------------
    // 5. Control Unit Instance
    // ------------------------------------------------------------------------

    //assign wires/logic to all control signals
    logic pcin;
    logic pcout;
    logic pccontrol;
    logic irin;
    logic irout;
    logic rdsin;
    logic rdsout;
    logic rsout;
    logic imm;
    logic xin;
    logic zin;
    logic zout;
    logic marin;
    logic mdrin;
    logic mdrout;
    logic read;
    logic write;

    control_unit cu (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .alu_zero(alu_zero),
        .halted(halted),
        .PCin(pcin),
        .PCout(pcout),
        .PCcontrol(pccontrol),
        .IRin(irin),
        .IRout(irout),
        .Rdsin(rdsin),
        .Rdsout(rdsout),
        .Rsout(rsout),
        .Imm(imm),
        .Xin(xin),
        .Zin(zin),
        .Zout(zout),
        .MARin(marin),
        .MDRin(mdrin),
        .MDRout(mdrout),
        .Read(read),
        .Write(write)
    );

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            PC <= 0;
            IR <= 0;
            X <= 0;
            Z <= 0;
            MAR <= 0;
            MDR <= 0;
            registers[0] <= 0;
            registers[1] <= 0;
        end else begin
            if(pcin && pccontrol) begin
                PC <= BUS;
            end else if(pcin) begin
                PC <= BUS + 1;
            end 
            
            if(irin) begin
                IR <= BUS;
            end

            if(marin) begin
                MAR <= BUS;
            end

            if(mdrin) begin
                if(read) begin
                    MDR <= data_read;
                end else begin
                    MDR <= BUS;
                end
                
            end
            
            if(xin) begin
                X <= BUS;
            end

            if(rdsin) begin
                registers[ds_idx] <= BUS;
            end

            if(zin) begin
                Z <= alu_result;
            end   
        end
    end

    always @(*) begin
        BUS = 0;
        if(pcout) begin
            BUS = PC;
        end else if(irout) begin
            BUS = IR;
        end else if(rdsout) begin
            BUS = registers[ds_idx];
        end else if(rsout) begin
            BUS = registers[s_idx];
        end else if(zout) begin
            BUS = Z;
        end else if(mdrout) begin
            BUS = MDR;
        end
        
    end

    // TODO
    

endmodule


        