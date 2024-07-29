module mips32_test1;
reg clk1,clk2;
integer k;

MIPS32_pipeline mips(clk1,clk2);

initial begin
	clk1=0;clk2=0;
	repeat(20) begin
	#5 clk1=1; #5 clk1=0;
	#5 clk2=1; #5 clk2=0;
	end
end

initial begin
	for(k=0;k<32;k++)
		mips.REG[k]=k;
	mips.MEM[0]=32'h2801000a;//ADDI R1,R0,10
	mips.MEM[1]=32'h28020014;//ADDI R2,R0,20
	mips.MEM[2]=32'h2803001e;//ADDI R3,R0,30
	mips.MEM[3]=32'h0ce77800;
	mips.MEM[4]=32'h0ce77800;
	mips.MEM[5]=32'h00222000;//ADD R4,R1,R2
	//Adding dummy instruction to prevent pipeline hazard
	mips.MEM[6]=32'h0ce77800;//OR R7,R7,R7
	mips.MEM[7]=32'h00832800;//ADD R5,R3,R4
	mips.MEM[8]=32'hfc000000;//HLT

	mips.HALTED=0;
	mips.TAKEN_BRANCH=0;
	mips.PC=0;
	
	#280
	for(k=0;k<6;k++)
	$display("R%1d = %2d",k,mips.REG[k]);
end

initial begin
	$dumpfile("MIPS32_pipeline.vcd");
	$dumpvars(0,mips32_test1);
	#300 $finish();
end

endmodule


