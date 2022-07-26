module CSA (
	input [31:0]a, b, cin,
	output [31:0]sum, cout);
	
	assign sum = a ^ b ^ cin;
	assign cout[0] = 1'b0;
	assign cout[31:1] = (a&b)|(b&cin)|(a&cin);
endmodule

module wallace_multiplier (
	input [15:0] a, b,
	output[31:0] prod_final);
	
	reg [31:0] pProd[15:0];
	
	integer i;
	
	always @(*)
	begin
		for(i = 0; i < 16; i = i+1)
		begin
			if(b[i] == 1)
			begin
				pProd[i] = a << i;
			end
			else
			begin
				pProd[i] = 32'h0000_0000;
			end
		end
	end
	
	//level 7
	wire [31:0] l7pProd[10:0];
	genvar j;
	generate 
		for(j = 0; j < 5; j = j + 1) 
		begin : lev7
			CSA l7 (pProd[3*j], pProd[3*j+1], pProd[3*j+2], l7pProd[2*j], l7pProd[2*j+1]);
		end
	endgenerate
	
	assign l7pProd[10] = pProd[15];
	
	//level 6
	wire [31:0] l6pProd[7:0];
	genvar k;
	generate
		for(k = 0; k < 3; k = k + 1)
		begin : lev6
			CSA l6 (l7pProd[3*k], l7pProd[3*k+1], l7pProd[3*k+2], l6pProd[2*k], l6pProd[2*k+1]);
		end
	endgenerate
	
	assign l6pProd[6] = l7pProd[9];
	assign l6pProd[7] = l7pProd[10];
	
	//level 5
	wire [31:0] l5pProd[5:0];
	genvar l;
	generate
		for(l = 0; l < 2; l = l + 1)
		begin : lev5
			CSA l5 (l6pProd[3*l], l6pProd[3*l+1], l6pProd[3*l+2], l5pProd[2*l], l5pProd[2*l+1]);
		end
	endgenerate
	
	assign l5pProd[4] = l6pProd[6];
	assign l5pProd[5] = l6pProd[7];
	
	//level 4
	wire [31:0] l4pProd[3:0];
	genvar m;
	generate
		for(m = 0; m < 2; m = m + 1)
		begin : lev4
			CSA l4 (l5pProd[3*m], l5pProd[3*m+1], l5pProd[3*m+2], l4pProd[2*m], l4pProd[2*m+1]);
		end
	endgenerate
	
	//level 3
	wire [31:0] l3pProd[2:0];
	CSA l3 (l4pProd[0], l4pProd[1], l4pProd[2], l3pProd[0], l3pProd[1]);
	assign l3pProd[2] = l4pProd[3];
	
	//level 2
	wire [31:0] l2pProd[1:0];
	CSA l2 (l3pProd[0], l3pProd[1], l3pProd[2], l2pProd[0], l2pProd[1]);
	
	// answer
	assign prod_final = l2pProd[0] + l2pProd[1];
	
	// level = 1
	wire ignore_carry;
	BK_adder32bit adder1 (l2pProd[0],l2pProd[1],1'b0, prod_final,ignore_carry);	
	
	
endmodule

module BK_adder32bit (
	input [31:0]x, y,
	input cin,
	output [31:0] sum,
	output cout);
	
	wire [32:0] carry;
	assign carry[0] = cin; //input carry
	
	wire [31:0] G_1, P_1;
	assign G_1 = x & y;
	assign P_1 = x ^ y;
	
	//level1
	genvar i;
	wire [15:0] G_2, P_2;
	generate
		for(i=0;i<16;i=i+1) begin
			assign G_2[i] = G_1[2*i+1] | P_1[2*i+1] & G_1[2*i];
			assign P_2[i] = P_1[2*i+1] & P_1[2*i];
		end
	endgenerate
	
	//level2
	genvar j;
	wire [7:0] G_3, P_3;
	generate
		for(j=0;j<8;j=j+1) begin
			assign G_3[j] = G_2[2*j+1] | P_2[2*j+1] & G_2[2*j];
			assign P_3[j] = P_2[2*j+1] & P_2[2*j];
		end
	endgenerate
	
	//level3
	genvar k;
	wire [3:0] G_4, P_4;
	generate
		for(k=0;k<4;k=k+1) begin
			assign G_4[k] = G_3[2*k+1] | P_3[2*k+1] & G_3[2*k];
			assign P_4[k] = P_3[2*k+1] & P_3[2*k];
		end
	endgenerate
	
	//level4
	genvar l;
	wire [1:0] G_5, P_5;
	generate
		for(l=0;l<2;l=l+1) begin
			assign G_5[l] = G_4[2*l+1] | P_4[2*l+1] & G_4[2*l];
			assign P_5[l] = P_4[2*l+1] & P_4[2*l];
		end
	endgenerate
	
	//level5
	wire G_6, P_6;
	assign G_6 = G_5[1] | P_5[1] & G_5[0];
	assign P_6 = P_5[1] & P_5[0];
	
	//carry generation
	//1st iteration
	assign carry[32] = G_6 | P_6 & carry[0];
	assign carry[16] = G_5[0] | P_5[0] & carry[0];
	
	//2nd iteration
	assign carry[8] = G_4[0] | P_4[0] & carry[0];
	assign carry[24] = G_4[2] | P_4[2] & carry[16];
	
	//3rd iteration
	assign carry[4] = G_3[0] | P_3[0] & carry[0];
	assign carry[12] = G_3[2] | P_3[2] & carry[8];
	assign carry[20] = G_3[4] | P_3[4] & carry[16];
	assign carry[28] = G_3[6] | P_3[6] & carry[24];
	
	//4th iteration
	assign carry[2] = G_2[0] | P_2[0] & carry[0];
	assign carry[6] = G_2[2] | P_2[2] & carry[4];
	assign carry[10] = G_2[4] | P_2[4] & carry[8];
	assign carry[14] = G_2[6] | P_2[6] & carry[12];
	assign carry[18] = G_2[8] | P_2[8] & carry[16];
	assign carry[22] = G_2[10] | P_2[10] & carry[20];
	assign carry[26] = G_2[12] | P_2[12] & carry[24];
	assign carry[30] = G_2[14] | P_2[14] & carry[28];
	
	//5th iteration
	assign carry[1] = G_1[0] | P_1[0] & carry[0];
	assign carry[3] = G_1[2] | P_1[2] & carry[2];
	assign carry[5] = G_1[4] | P_1[4] & carry[4];
	assign carry[7] = G_1[6] | P_1[6] & carry[6];
	assign carry[9] = G_1[8] | P_1[8] & carry[8];
	assign carry[11] = G_1[10] | P_1[10] & carry[10];
	assign carry[13] = G_1[12] | P_1[12] & carry[12];
	assign carry[15] = G_1[14] | P_1[14] & carry[14];
	assign carry[17] = G_1[16] | P_1[16] & carry[16];
	assign carry[19] = G_1[18] | P_1[18] & carry[18];
	assign carry[21] = G_1[20] | P_1[20] & carry[20];
	assign carry[23] = G_1[22] | P_1[22] & carry[22];
	assign carry[25] = G_1[24] | P_1[24] & carry[24];
	assign carry[27] = G_1[26] | P_1[26] & carry[26];
	assign carry[29] = G_1[28] | P_1[28] & carry[28];
	assign carry[31] = G_1[30] | P_1[30] & carry[30];
	
	assign sum = P_1 ^ carry[31:0];
	
endmodule
