module MIPS32_pipeline(clk1,clk2);
input clk1,clk2;
reg [31:0] PC,IF_ID_IR , IF_ID_NPC;
reg [31:0] ID_EX_IR , ID_EX_NPC , ID_EX_A , ID_EX_B , ID_EX_IMM ;
reg [2:0] ID_EX_type , EX_MEM_type , MEM_WB_type;
reg [31:0] EX_MEM_IR , EX_MEM_ALUOUT , EX_MEM_cond , EX_MEM_B;
reg [31:0] MEM_WB_IR , MEM_WB_ALUOUT , MEM_WB_LMD;
reg [31:0] REG [0:31];//32*32
reg [31:0] MEM [0:1023]; //1024*32

parameter 
ADD=6'b000000 ,
SUB=6'b000001 ,
AND=6'b000010 ,
OR=6'b000011 ,
SLT=6'b000100 ,
MUL=6'b000101 ,
HLT=6'b111111 ,
LW=6'b001000 ,
SW=6'b001001 ,
ADDI=6'b001010 ,
SUBI=6'b001011 ,
SLTI=6'b001100 ,
BNEQZ=6'b001101 ,
BEQZ=6'b001110 ;

parameter RR_ALU=3'b000,
RM_ALU=3'b001,
LOAD=3'b010,
STORE=3'b011,
BRANCH=3'b100,
HALT=3'b101;

//1 bit variables
reg HALTED; //to set the HLT function so that the process stops after WB stage (not in ID stage itself)
reg TAKEN_BRANCH;// to set the Branch function so tht it discards the incoming instructions in the pipeline

//IF STAGE

always @(posedge clk1)
if (HALTED==0) begin
if ( ((IF_ID_IR[31:26]==BEQZ) && (EX_MEM_cond==1)) || ((IF_ID_IR[31:26]==BNEQZ) && (EX_MEM_cond==0)) )
begin
IF_ID_IR <= #2 MEM[EX_MEM_ALUOUT] ;
TAKEN_BRANCH <= #2 1'b1;
IF_ID_NPC <= #2 EX_MEM_ALUOUT+1;
PC <= #2  EX_MEM_ALUOUT+1;
end
else
begin
IF_ID_IR <= #2 MEM[PC];
IF_ID_NPC <= #2 PC+1;
PC <= #2 PC+1;
end
end

//ID STAGE 

always @(posedge clk1)

if(HALTED==0)
begin

if (IF_ID_IR[25:21]==5'b00000) ID_EX_A <= 0;// rs
else ID_EX_A <= #2 REG[IF_ID_IR[25:21]];
if (IF_ID_IR[20:16]==5'b00000) ID_EX_B <= 0; //rt
else ID_EX_B <= #2 REG[IF_ID_IR[20:16]];

ID_EX_NPC <= #2 IF_ID_NPC;
ID_EX_IR <= #2 IF_ID_IR;
ID_EX_IMM <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};//Sign extending to 32 bits by concatenating the repeated 15th bit

case(IF_ID_IR[31:26])
ADD,SUB,AND,OR,SLT,MUL  : ID_EX_type <= #2 RR_ALU;
ADDI,SUBI,SLTI          : ID_EX_type <=#2 RM_ALU;
BEQZ,BNEQZ              : ID_EX_type <= #2 BRANCH;
LW 		        : ID_EX_type <= #2 LOAD;
SW			: ID_EX_type <= #2 STORE;
HLT			: ID_EX_type <= #2 HALT;
default :  ID_EX_type <= #2 HALT;//if any invalid opcode
endcase

end

//EX STAGE

always @(posedge clk1)
if(HALTED==0)

begin
EX_MEM_type <= ID_EX_type;
EX_MEM_IR <= ID_EX_IR ; 
TAKEN_BRANCH <= 1'b0;

case(ID_EX_type)

	RR_ALU: begin
		  case(ID_EX_IR[31:26])
			ADD : EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_B ; 
			SUB : EX_MEM_ALUOUT <= #2 ID_EX_A - ID_EX_B ; 
			AND : EX_MEM_ALUOUT <= #2 ID_EX_A & ID_EX_B ; 
			OR  : EX_MEM_ALUOUT <= #2 ID_EX_A | ID_EX_B ; 
			SLT : EX_MEM_ALUOUT <= #2 ID_EX_A < ID_EX_B ; 
			MUL : EX_MEM_ALUOUT <= #2 ID_EX_A * ID_EX_B ; 
			default : EX_MEM_ALUOUT <= #2 32'hxxxxxxxx ; 
		  endcase	
		end

	RM_ALU: begin
		  case(ID_EX_IR[31:26])
			ADDI : EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM;
			SUBI : EX_MEM_ALUOUT <= #2 ID_EX_A - ID_EX_IMM;
			SLTI : EX_MEM_ALUOUT <= #2 ID_EX_A < ID_EX_IMM;
			default: EX_MEM_ALUOUT <= #2 32'hxxxxxxxx ; 
		  endcase
		end

	LOAD , STORE :
		begin
		EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM;
		EX_MEM_B <= ID_EX_B;
		end

	BRANCH :
		begin
		EX_MEM_ALUOUT <= #2 ID_EX_NPC + ID_EX_IMM;
		EX_MEM_cond <= (ID_EX_A==0);
		end

endcase

end

//MEM STAGE

always @(posedge clk2)
if (HALTED==0)
begin
MEM_WB_type <= EX_MEM_type;
MEM_WB_IR <= EX_MEM_IR;
	case(EX_MEM_type)
	  RR_ALU , RM_ALU :
		  MEM_WB_ALUOUT <= #2 EX_MEM_ALUOUT;
		  
	  LOAD:
		  MEM_WB_LMD <= MEM[EX_MEM_ALUOUT];
		  
	  STORE: if(TAKEN_BRANCH == 0) // if BRANCH instruction then discard these or disable write
		  MEM[EX_MEM_ALUOUT] <= #2 EX_MEM_B;
	endcase  
end

//WRITE BACK STAGE

always @(posedge clk1)
if(TAKEN_BRANCH==0)//If barnch is taken disables write
begin
case (MEM_WB_type)
  RR_ALU : REG[MEM_WB_IR[15:11]] <= MEM_WB_ALUOUT; //rd
  RM_ALU : REG[MEM_WB_IR[20:16]] <= MEM_WB_ALUOUT; //rt
  LOAD   : REG[MEM_WB_IR[20:16]] <= MEM_WB_LMD; //rt
  HALT   : HALTED <= 1'b1;
endcase

end
endmodule
  


