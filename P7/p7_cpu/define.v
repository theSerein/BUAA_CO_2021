`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:54:07 12/12/2021 
// Design Name: 
// Module Name:    define 
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
`define ADD4 0
`define BEQ  1
`define JAL  2
`define REG  3
`define BGEZ 4
`define BGTZ 5
`define BLEZ 6
`define BLTZ 7
`define BNE  8
`define IRQ  9
`define ERET 10
//CP0
`define Int 0
`define AdEL 4
`define AdES 5
`define RI 10
`define Ov 12
//NOP
`define NOP 0