/******************************************************************

                 Testbench for stream_arbiter:
  
  T_DATA_WIDTH = 8;
  T_QOS_WIDTH = 4;
  STREAM_COUNT = 2;
  
  Stream 1.1: 
    qos = 3, data = A, B (last)
  Stream 1.2: 
    qos = 2, data = C, D (last)
 
  Stream 2.1: 
    qos = 1, data = E, F (last)
  Stream 2.2: 
    qos = 0, data = 8, 9 (last)
 
  (data from task example for better comparison)


******************************************************************/

module tb_stream_arbiter;

  reg clk;
  reg rst_n;
  reg [7:0] s_data_i [1:0];
  reg [3:0] s_qos_i [1:0];
  reg [1:0] s_last_i;
  reg [1:0] s_valid_i;
  wire [1:0] s_ready_o;
  
  wire [7:0] m_data_o;
  wire [3:0] m_qos_o;
  wire [1:0] m_id_o;
  wire m_last_o;
  wire m_valid_o;
  reg m_ready_i;

  // Instantiate the stream_arbiter module
  stream_arbiter #(
    .T_DATA_WIDTH(8),
    .T_QOS_WIDTH(4),
    .STREAM_COUNT(2),
    .T_ID_WIDTH(1)
  ) uut (
    .clk(clk),
    .rst_n(rst_n),
    .s_data_i(s_data_i),
    .s_qos_i(s_qos_i),
    .s_last_i(s_last_i),
    .s_valid_i(s_valid_i),
    .s_ready_o(s_ready_o),
    .m_data_o(m_data_o),
    .m_qos_o(m_qos_o),
    .m_id_o(m_id_o),
    .m_last_o(m_last_o),
    .m_valid_o(m_valid_o),
    .m_ready_i(m_ready_i)
  );

  // Generate clock signal
  always begin
    #10 clk = ~clk;
  end
  
  // Control for generating transactions
  initial begin
    clk = 0;
    rst_n = 0;
    m_ready_i = 0; // Start with zero readiness
    #10 rst_n = 1;
    
    // Wait for the arbiter to set readiness for reception
    wait(s_ready_o == 2'b11);
    
    // Start transmitting transactions
    m_ready_i = 1; // Set readiness for transmission
    
    // Transaction 1
    s_data_i[0] = 8'hA;
    s_qos_i[0] = 3;
    s_data_i[1] = 8'hC;
    s_qos_i[1] = 2;
    s_valid_i = 2'b11;
    s_last_i = 2'b00;
    
    // Wait for transmission
    wait(s_ready_o == 2'b01);
    #10
    // On the next positive clock edge, change the data and indicate that the packet is the last
    wait(clk == 1);
    s_data_i[0] = 8'hB;
    s_last_i[0] = 1;
    
    // Wait for the transmission of the next transaction and reset stream 0
    wait(s_ready_o == 2'b10);
    s_last_i[0] = 0;
    s_valid_i[0] = 0;
    
    #10
    // On the next positive clock edge, change the data and indicate that the packet is the last
    wait (clk == 1)
    s_data_i[1] = 8'hD;
    s_last_i[1] = 1;
    
    // Wait for the arbiter to finish the transaction (all ready signals will be 1 since the stream was the last)
    wait(s_ready_o == 2'b11);
    
    // Move to the next transaction
    m_ready_i = 1; // Set readiness for transmission
    
    // Transaction 2
    s_data_i[0] = 8'hE;
    s_qos_i[0] = 0;
    s_data_i[1] = 8'h8;
    s_qos_i[1] = 1;
    s_valid_i = 2'b11;
    s_last_i = 2'b00;
    
    // Wait for transmission
    wait(s_ready_o == 2'b01);
    #10
    // On the next positive clock edge, change the data and indicate that the packet is the last
    wait (clk == 1) 
    s_data_i[0] = 8'hF;
    s_last_i[0] = 1;
    
    // Wait for the transmission of the next transaction and reset stream 0
    wait(s_ready_o == 2'b10);
    s_last_i[0] = 0;
    s_valid_i[0] = 0;
    
    #10
    // On the next positive clock edge, change the data and indicate that the packet is the last
    wait (clk == 1)
    s_data_i[1] = 8'h9;
    s_last_i[1] = 1;
    
    // Wait for the arbiter to finish the transaction (all ready signals will be 1 since the stream was the last)
    wait(s_ready_o == 2'b11);
    
    // Finish the work
    m_ready_i = 0; 
    #10 $finish;
  end
endmodule 
