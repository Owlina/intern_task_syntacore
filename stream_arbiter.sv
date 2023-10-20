/******************************************************************

             Task intern 2: module stream_arbiter.

  Engineer: Alina Dovzhenko
  Create Date: 17.10.2023

******************************************************************/

module stream_arbiter #(
  parameter T_DATA_WIDTH = 8,
  parameter T_QOS_WIDTH  = 4,
  parameter STREAM_COUNT = 2,

  /// In task following parameter is declared as localparam
  /// Setting it as `parameter` is completely OK, though setting it as
  /// `localparam` is for reason: user of this module would not be able
  /// to change `T_ID_WIDTH`, meanwhile you can declare ports with width `T_ID_WIDTH`
  parameter T_ID_WIDTH   = $clog2(STREAM_COUNT)
)(
  input  logic                           clk,
  input  logic                           rst_n,

  // Input streams
  input  logic [T_DATA_WIDTH-1:0]        s_data_i [STREAM_COUNT-1:0],
  input  logic [T_QOS_WIDTH -1:0]        s_qos_i  [STREAM_COUNT-1:0],
  input  logic [STREAM_COUNT-1:0]        s_last_i,
  input  logic [STREAM_COUNT-1:0]        s_valid_i,
  output logic [STREAM_COUNT-1:0]        s_ready_o,

  // Output stream
  output logic [T_DATA_WIDTH-1:0]        m_data_o,
  output logic [T_QOS_WIDTH -1:0]        m_qos_o,
  output logic [T_ID_WIDTH - 1:0]        m_id_o,
  output logic                           m_last_o,
  output logic                           m_valid_o,
  input  logic                           m_ready_i
);

  integer state = 0;         // Varriable for machine state

  logic [T_QOS_WIDTH -1:0] sorted_priorities [STREAM_COUNT-1:0] = '{default: 0}; // Array of sorted priorities
  logic [T_ID_WIDTH:0] sorted_streams = '{default: 0};                           // Array of sorted streams

  integer sorted_count = 0;  // Element counter in the array
  integer cnt = 0;           // Counter for outputting all streams
  integer i = 0;             // Variable for sorting function
  integer j = 0;             // Variable for sorting function

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset
      m_data_o <= '0;  // Reset data on output
      m_qos_o <= '0;   // Reset QoS on output
      m_id_o <= '0;    // Reset ID on output
      m_last_o <= '0;  // Reset last on output
      m_valid_o <= 0;  // Reset valid on output
      s_ready_o <= '0; // Reset ready on output

      cnt <= 0;
      sorted_streams <= '{default: 0};
      sorted_priorities <= s_qos_i;
      state <= 2;
    end
    else begin
      case(state)
      0: begin
        if (!m_ready_i) begin
          state = 2;
        end
        // Sorting
        sorted_priorities = s_qos_i;
        for (int i = 0; i < STREAM_COUNT; i = i + 1) begin
          /// This array is defined as single-dimension packed, but here we assign i to it,
          /// So we are likely to get smthn like 6'b101010, when T_ID_WIDTH == 6
          /// But, yes, it shall work for T_ID_WIDTH == 2
          /// Please, fix this
          sorted_streams[i] = i;
        end
        sorted_count = 0; // Element counter in the array

        // During sorting, the data transmitted by the arbiter is invalid, and it's not ready to receive data
        m_valid_o <= 0;
        s_ready_o <= '0;

        // Fill arrays with priorities and stream numbers
        for (i = 0; i < STREAM_COUNT; i = i + 1) begin
          if (s_valid_i[i]) begin
            // Compare priorities and sort using insertion sort
            for (j = i - 1; j >= 0; j = j - 1) begin
              if (s_qos_i[i] == 0 || (s_qos_i[i] > s_qos_i[sorted_priorities[j]] && s_qos_i[sorted_priorities[j]] != 0))

                begin
                  sorted_priorities[j + 1] = sorted_priorities[j];
                  sorted_priorities[j] = i;

                  // Update the array with stream numbers
                  sorted_streams[j + 1] = sorted_streams[j];
                  sorted_streams[j] = i;
                end

              else begin
                // Priorities are sorted, exit the inner loop
                break;
              end
            end
            sorted_count = sorted_count + 1; // Increment the counter
          end
        end
        if(sorted_count > 0) begin
          state = 1;
        end
      end
      1: begin
        if (!m_ready_i) begin
          state = 2;
        end
        if (cnt < sorted_count) begin
          // If the master is ready to receive data, the transmitted data is valid, and the packet is not the last, then the data is transmitted
          if (m_ready_i && s_valid_i[sorted_streams[cnt]] && !s_last_i[sorted_streams[cnt]]) begin
            m_data_o <= s_data_i[sorted_streams[cnt]];
            m_qos_o <= sorted_priorities[cnt];
            m_id_o <= sorted_streams[cnt];
            m_last_o <= s_last_i[sorted_streams[cnt]];
            m_valid_o <= 1;
            s_ready_o[sorted_streams[cnt]] <= 1;
          end
          // If the packet is the last, after its transmission, the counter for processed streams is increased by 1
          else if (m_ready_i && s_valid_i[sorted_streams[cnt]] && s_last_i[sorted_streams[cnt]]) begin
            m_data_o <= s_data_i[sorted_streams[cnt]];
            m_qos_o <= sorted_priorities[cnt];
            m_id_o <= sorted_streams[cnt];
            m_last_o <= s_last_i[sorted_streams[cnt]];
            m_valid_o <= 1;
            s_ready_o[sorted_streams[cnt]] <= 0;
            cnt <= cnt + 1;
          end
        end
        // After processing all streams, the arbiter goes back to sorting
        else begin
          cnt = 0;
          state = 0;
          /// It is not the best option to combine <= and =, it affects readability and makes synthesis less predictable
          /// So is usage of = in always_ff block
          /// This should be fixed

          // Reset output data during sorting
          m_data_o <= '0; // Reset data on output
          m_qos_o <= '0;  // Reset QoS on output
          m_id_o <= '0;   // Reset ID on output
          m_last_o <= '0; // Reset last on output
          m_valid_o <= 0; // Reset valid on output

          /// At this point we may also lose some data, because if it arrives in the following cycle,
          /// state will be 0, while s_ready_o is (STREAM_COUNT)'(1) yet (because s_ready_o <= '0 ), so we lose data
          ///                                                                               ^~
          s_ready_o = '1;
        end
      end
      default: begin
        // All zeros
        /// When ~m_ready_i, s_ready_o becomes (STREAM_COUNT)'(1), so all the requesters start sending data,
        /// Which is not OK, because ~m_ready_i, so the data will be lost. Please fix this bug

        m_data_o <= '0;  // Reset data on output
        m_qos_o <= '0;   // Reset QoS on output
        m_id_o <= '0;    // Reset ID on output
        m_last_o <= '0;  // Reset last on output
        m_valid_o <= 0;  // Reset valid on output
        s_ready_o <= '1; // Set ready on output
        if (m_ready_i) begin
          state <= 0;
        end
      end
      endcase
    end
  end

/// Probably, there is option to avoid sorting stage and to work with transactions "in flight",
/// so that you spare time, that you need for sorting (that is either some cycles, or single cycle length)
/// For instance, you can find highest priority by comparison in cycle,
/// then fix s_ready_o until slave is not ready
/// to accept, or last packet of transaction is reached.
/// This is not a feature request), but just information for consideration

/// Please fix the bugs

/// Please, also append your testbench so that it checks cases when ~m_ready_i

endmodule

