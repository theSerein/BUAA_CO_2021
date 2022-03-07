`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:56:25 12/17/2021 
// Design Name: 
// Module Name:    CPU 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
`include "define.v"
module CPU(
    input clk,
    input reset,
    input [31:0] i_inst_rdata,//i_inst_addr  
	input [31:0] m_data_rdata,//m_data_addr  
	input [5:0] HWInt, 


	output IRP,
	output [31:0] macro_pc,
	output [31:0] i_inst_addr,// F PC
    output [31:0] m_data_addr,//Addr
    output [31:0] m_data_wdata,//WD
    output [3 :0] m_data_byteen,//byte-en
    output [31:0] m_inst_addr,//M PC
    output w_grf_we,//grf   
	output [4:0] w_grf_addr,//grf A3
	output [31:0] w_grf_wdata,//grf WD
    output [31:0] w_inst_addr//W PC
);
	//ifu if_id
	wire zero,E,lez,lz,gez,gz;
	wire [3:0] D_Branch;
	wire [31:0] imm_jal,imm_1,PC,F_I,F_PC,npc;
	//D
	wire [31:0] D_I,D_RD1,D_RD2,D_PC;
	wire [4:0] D_A1,D_A2,W_A3;
	//grf
	wire GRF_WE;
	wire [4:0] GRF_A3;
	wire [31:0] GRF_PC,RD1,RD2,GRF_WD;

	wire [3:0] RD1_s, RD2_s;
	//E
	wire [31:0] E_I,E_PC;
	wire E_shamt;
	wire ExtOp,E_s,Busy,start;  
	wire [3:0] ALUOP,mdu_op,MDU_OP,AO_s;
	wire [31:0] E_RD1,E_RD2,E_AO,hi,lo;

	wire [31:0] SrcA,SrcB;
	wire [3:0] SrcA_s,SrcB_s;
	wire [31:0] AO;
	//M
	wire ext,HitDM,HitTC0,HitTC1;
	wire s_w,s_h,s_b;
	wire l_w,l_h,l_b;
	wire [31:0] M_I,M_PC,M_AO,M_RD2;
	wire [31:0] M_Addr,M_Data;
	wire [3:0] M_Data_s;
	wire [31:0]M_RD;
	//W
	wire RaWrite,RegDst,W_WE;
	wire [2:0] WD_sel;
	wire [31:0] W_AO,W_RD,W_I,W_PC,W_Data;
	//SFU
	wire Stall;
	//CP0
	wire W_eret;
	wire [31:0] D_Out,W_Out;
	wire EXLClr,IntReq;
	wire [31:0] M_EPC,W_EPC,EPC;
	wire [4:0] CP0_A1,CP0_A2,W_A2;
	wire [31:0] CP0_in,CP0_Out,CP0_PC;
	//ExcCode
	wire BD;
	wire F_BD;
	wire D_BD0,D_BD;
	wire E_BD0,E_BD;
	wire M_BD0,M_BD;
	wire pc_addr_exc;
	wire RI;
	wire cal_ov,overflow,E_OV,M_OV;
	wire load_exc,store_exc;
	wire [6:2] F_Exc;
	wire [6:2] D_Exc0,D_Exc;
	wire [6:2] E_Exc0,E_Exc;
	wire [6:2] M_Exc0,M_Exc;
	wire [6:2] ExcCode;

	
	NPC next_pc(
		.D_PC(D_PC),
		.PC(PC),
		.D_Branch(D_Branch),
		.imm_1(imm_1),
		.imm_jal(imm_jal),
		.EPC(EPC),

		.IntReq(IntReq),
		.zero(zero),
		.gz(gz),
		.gez(gez),
		.lz(lz),
		.lez(lez),
		.D_RD1(D_RD1),
		
		.npc(npc)
		);


	IFU ifu(.clk(clk),
			.reset(reset),
			.npc(npc),
			.WE(E),
			
			.PC(PC)
			);

	assign pc_addr_exc = (|PC[1:0] || !(PC >= 32'h3000 && PC <= 32'h6ffc));

	assign F_Exc =  pc_addr_exc ? `AdEL :
									0;
	assign F_BD = D_Branch != 0 && D_Branch != `ERET;

	//
	assign F_I = (D_Branch == `ERET) ? 0 :
				(pc_addr_exc) ? 0 :
								i_inst_rdata;
	assign i_inst_addr = PC;

	//
	assign imm_1 = {{16{D_I[15]}}, D_I[15:0]};
	
	assign imm_jal = {{D_PC[31:28]}, D_I[25:0], 2'b0};


	assign F_PC = PC;


	IF_ID if_id(.reset(reset),
				.IntReq(IntReq),
				.clk(clk),
				.F_I(F_I),
				.F_PC(F_PC),
				.F_Exc(F_Exc),
				.WE(E),
				.F_BD(F_BD),

				.D_BD0(D_BD0),
				.RI(RI),
				.D_Exc0(D_Exc0),
				.D_I(D_I),
				.D_PC(D_PC),
				.D_Branch(D_Branch)
				);

	assign D_A1 = D_I[25:21];
	assign D_A2 = D_I[20:16];


	assign D_Exc = RI ? `RI :
						D_Exc0;

	assign D_BD = D_BD0;



	
	GRF grf(.clk(clk),
			.reset(reset),
			.A1(D_A1),
			.A2(D_A2),

			.A3(GRF_A3),
			.Data(GRF_WD),
			.WE(GRF_WE),
			.PC(GRF_PC),
			
			.RD1(RD1),
			.RD2(RD2)
			);
	
	
	CMP cmp(
		.A(D_RD1),
		.B(D_RD2),
		.zero(zero),
		.gez(gez),
		.gz(gz),
		.lez(lez),
		.lz(lz)
	);
	
	assign D_RD1 = 	RD1_s == 1 ? E_PC + 8 :
					RD1_s == 2 ? M_PC + 8 :
					RD1_s == 3 ? M_AO :
					RD1; 
	//D_RD2 = RD2 / AO / mem_pc + 8 
	assign D_RD2 = 	RD2_s == 1 ? E_PC + 8 :
					RD2_s == 2 ? M_PC + 8 :
					RD2_s == 3 ? M_AO :
					RD2;
	wire store,if_ex_reset;
	ID_EX id_ex(.reset(reset),
				.Stall(Stall),
				.IntReq(IntReq),
				
				.clk(clk),
				.D_I(D_I),
				.D_PC(D_PC),
				.D_RD1(D_RD1),
				.D_RD2(D_RD2),
				.D_Exc(D_Exc),
				.D_BD(D_BD),


				.E_BD0(E_BD0),
				.E_Exc0(E_Exc0),
				.cal_ov(cal_ov),
				.E_I(E_I),
				.E_PC(E_PC),
				.ExtOp(ExtOp),
				.E_s(E_s),
				.E_ALUOP(ALUOP),
				.E_RD1(E_RD1),
				.E_RD2(E_RD2),
				.E_shamt(E_shamt),
				.E_MDU_OP(mdu_op),
				.start(start),
				.E_AO_S(AO_s)
				);


	wire [31:0] E32;
	wire [15:0] imm_16 = E_I[15:0];		
	
	Ext EXT(.imm_16(imm_16),
			.ExtOp(ExtOp),
			.Result(E32)
			);

	
	// wire [31:0] SrcA,SrcB;
	// wire [3:0] SrcA_s,SrcB_s;
	// assign SrcA = E_RD1;
	//mem_AO 
	//wb_WD
	//E_RD1
	wire [31:0] n_RD1;
	assign n_RD1 = 	SrcA_s == 2 ? (M_PC + 8):
					SrcA_s == 3 ? M_AO :
					SrcA_s == 4 ?  GRF_WD : 
								E_RD1;
	assign SrcA = E_shamt == 1'b1 ? {0,{E_I[10:6]}}:
							n_RD1;
	// assign SrcB = E_s ? E32 :
	// 					E_RD2;
	//mem_AO
	//wb_WD
	//E_RD1
	wire [31:0] n_RD2;
	assign n_RD2 = 	SrcB_s == 2 ? (M_PC + 8) :
					SrcB_s == 3 ? M_AO :
					SrcB_s == 4 ? GRF_WD :
								E_RD2;
	assign SrcB = 	E_s == 1'b1 ? E32 :
								n_RD2;


	assign MDU_OP = IntReq ? 0 :
							mdu_op;
	/*
	MDU mdu(
		.clk(clk),
		.reset(reset),
		.start(start),
		.A(SrcA),
		.B(SrcB),
		.MDU_OP(MDU_OP),
		.Busy(Busy),
		.hi(hi),
		.lo(lo)
	);*/
	ALU alu(  .A(SrcA),
			.B(SrcB),
			.op(ALUOP),
			
			.res(AO),
			.overflow(overflow)
			);
	
	assign E_AO = 	AO_s == 1 ? lo :
					AO_s == 2 ? hi :
								AO;
	
	assign E_Exc = cal_ov && overflow ? `Ov :
										E_Exc0;

	assign E_OV = overflow;
	assign E_BD = E_BD0;


	EX_MEM ex_mem(.reset(reset),
				.IntReq(IntReq),
				.clk(clk),
				.E_I(E_I),
				.E_PC(E_PC),
				.E_AO(E_AO),
				.E_RD2(n_RD2),
				.E_OV(E_OV),
				.E_Exc(E_Exc),
				.E_BD(E_BD),


				.M_BD0(M_BD0),
				.M_Exc0(M_Exc0),
				.M_OV(M_OV),
				.M_I(M_I),
				.M_PC(M_PC),
				.M_AO(M_AO),
				.M_RD2(M_RD2),
				.s_w(s_w),
				.s_h(s_h),
				.s_b(s_b),
				.l_w(l_w),
				.l_h(l_h),
				.l_b(l_b),
				.ext(ext),
				.cp0_we(cp0_rwe)
					);
	

	assign M_Addr = M_AO;
	
	
	assign M_Data = M_Data_s == 4 ?  GRF_WD ://sw
									M_RD2;
	
	// DM dm( .clk(clk),
	// 		.reset(reset),
	// 		.WE(M_WE),
	// 		.Addr(M_Addr),
	// 		.WD(M_Data),
	// 		.PC(M_PC),
			
	// 		.RD(M_RD)
	// 		);
	assign load_exc = 	l_w && |m_data_addr[1:0] ||
						l_h && m_data_addr[0] ||
						(l_h | l_b) && (!HitDM && (HitTC0 | HitTC1)) ||
						(l_w | l_h | l_b) && M_OV ||
						(l_w | l_h | l_b) && (!HitDM && !HitTC0 && !HitTC1);

	assign store_exc = 	s_w && |m_data_addr[1:0] ||
						s_h && m_data_addr[0] ||
						(s_h | s_b) && (!HitDM && (HitTC0 | HitTC1)) || 
						(s_w | s_h | s_b) && M_OV ||
						(s_w | s_h | s_b) && (!HitDM && !HitTC0 && !HitTC1) || 
						(s_w | s_h | s_b) && (!HitDM && (HitTC0 | HitTC1) && (m_data_addr[3:2] == 2));

	assign M_Exc = 	load_exc ? `AdEL :
					store_exc ? `AdES :
								M_Exc0;
	assign M_BD = M_BD0;


	assign macro_pc = M_PC;
	//CP0
	assign ExcCode = HWInt != 0 ? 0 :
							M_Exc;
	assign BD = M_BD;
	assign CP0_PC = M_PC;
	

	assign CP0_A1 = M_I[15:11];
	assign CP0_A2 = M_I[15:11];
	assign CP0_in = M_Data; 
	assign EXLClr = W_eret;
	assign cp0_we = IntReq ? 0 : cp0_rwe;

	CP0 cp0(
		.clk(clk),
		.reset(reset),
		.A1(CP0_A1),

		.A2(CP0_A2),
		.Din(CP0_in),

		.PC(CP0_PC),
		.ExcCode(ExcCode),
		.HWInt(HWInt),
		.nBD(BD),

		.EXLClr(EXLClr),
		.WE(cp0_we),

		.IntReq(IntReq),
		.EPC(M_EPC),
		.DOut(D_Out),
		.IRP(IRP)
	);
	

	assign m_data_addr =  M_AO;
	assign m_data_wdata = 	s_w ? M_Data :
							s_h ? (M_AO[1] == 1 ? {{M_Data[15:0]},16'b0} : {0,{M_Data[15:0]}}) :
							s_b ? (M_AO[1:0] == 0 ? {0,{M_Data[7:0]}} :
									M_AO[1:0] == 1 ? {0,{M_Data[7:0]},8'b0}:
									M_AO[1:0] == 2 ? {0,{M_Data[7:0]},16'b0} :
									M_AO[1:0] == 3 ? {{M_Data[7:0]},24'b0}:
									0):
									0; 
	assign m_data_byteen = 	IntReq ? 0 :
							s_w ? 4'b1111 :
							s_h ? (M_AO[1] == 1 ? 4'b1100 : 4'b0011) :
							s_b ?   (M_AO[1:0] == 0 ? 4'b0001 :
									M_AO[1:0] == 1 ? 4'b0010 :
									M_AO[1:0] == 2 ? 4'b0100 :
									M_AO[1:0] == 3 ? 4'b1000 :
									0):
									0; 
	assign m_inst_addr = M_PC;
	// 0x0000_0000 - 0x0000_2FFF
	assign HitDM = m_data_addr >= 0 && m_data_addr <= 32'h0000_2FFF;
	assign HitTC0 = m_data_addr >= 32'h0000_7F00 && m_data_addr <= 32'h0000_7F0B;
	assign HitTC1 = m_data_addr >= 32'h0000_7F10 && m_data_addr <= 32'h0000_7F1B;

	assign M_RD = 	(l_w && (HitDM | HitTC0 | HitTC1)) ? m_data_rdata :
					l_h ? (M_AO[1] == 1 ? (ext == 1 ? {{16{m_data_rdata[31]}},{m_data_rdata[31:16]}} : {0,{m_data_rdata[31:16]}}) : 
										(ext == 1 ? {{16{m_data_rdata[15]}},{m_data_rdata[15:0]}} : {0, {m_data_rdata[15:0]}})):
					l_b ? (M_AO[1:0] == 0 ? (ext == 1 ? {{24{m_data_rdata[7]}},{m_data_rdata[7:0]}} : {0,{m_data_rdata[7:0]}}) :
							M_AO[1:0] == 1 ? (ext == 1 ? {{24{m_data_rdata[15]}},{m_data_rdata[15:8]}} : {0,{m_data_rdata[15:8]}}) :
							M_AO[1:0] == 2 ? (ext == 1 ? {{24{m_data_rdata[23]}},{m_data_rdata[23:16]}} : {0,{m_data_rdata[23:16]}}) :
							M_AO[1:0] == 3 ? (ext == 1 ? {{24{m_data_rdata[31]}},{m_data_rdata[31:24]}} : {0,{m_data_rdata[31:24]}}) :
							0) :
							0;

	
	
	MEM_WB mem_wb(.reset(reset | IntReq),
				.clk(clk),
				.M_I(M_I),
				.M_PC(M_PC),
				.M_RD(M_RD),
				.M_AO(M_AO),
				.M_Out(D_Out),
				.M_EPC(M_EPC),

				.W_EPC(W_EPC),
				.WE(W_WE),
				.GRF_PC(W_PC),
				.GRF_I(W_I),
				.WD_S(WD_sel),
				.ra(RaWrite),
				.RegDst(RegDst),
				.W_AO(W_AO),
				.W_RD(W_RD),
				.W_Out(W_Out),
				.W_eret(W_eret)
				);	
	
	assign EPC = W_EPC;
	assign GRF_WD = (WD_sel == 1) ? W_RD :
					(WD_sel == 2) ? (W_PC + 8):
					(WD_sel == 3) ? W_Out :
									W_AO;
	

	assign GRF_WE = W_WE;
	assign GRF_PC = W_PC;
	
	assign GRF_A3 = RegDst == 1 ? W_I[15:11]:
					RaWrite == 1 ? 5'd31 :
									W_I[20:16];
	//outputs
	assign w_grf_we = GRF_WE;
	assign w_grf_addr = GRF_A3;
	assign w_grf_wdata = GRF_WD;
	assign w_inst_addr = GRF_PC;

	SFU sfu(.d_I(D_I),
			.ex_I(E_I),
			.mem_I(M_I),
			.wb_I(W_I),
			.Stall(Stall),
			.busy(Busy),
			.start(start),

			.RD1_s(RD1_s),
			.RD2_s(RD2_s),
			.SrcA_s(SrcA_s),
			.SrcB_s(SrcB_s),
			.M_Data_s(M_Data_s)
	);
	assign E = !Stall | IntReq;
	assign if_ex_reset = Stall | reset;

endmodule