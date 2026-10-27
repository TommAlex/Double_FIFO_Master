/*
    Модуль контроля частоты (Frequency Watchdog).
    Считает аппаратные фронты clk_test внутри измерительного окна.
    Если за окно пришло меньше 500 фронтов или частота пропала — areset_out = 1.
*/
module freq_watchdog (
    input  logic clk_ref,     // Эталонная частота (56 МГц)
    input  logic clk_test,    // Измеряемая частота от FT60X (CLK_FIFO)
    output logic areset_out   // Выход сброса для PLL: 1 - сброс, 0 - норма
);

    localparam logic [10:0] REF_WINDOW = 11'd1024;
    localparam logic [15:0] MIN_TICKS  = 16'd500; 

    // Домен эталонной частоты (clk_ref)
    logic [10:0] clk_ref_cnt = '0;
    logic        window_strobe = 1'b0;

    always_ff @(posedge clk_ref) begin
        if (clk_ref_cnt >= REF_WINDOW - 1'b1) begin
            clk_ref_cnt   <= '0;
            window_strobe <= 1'b1; 
        end else begin
            clk_ref_cnt   <= clk_ref_cnt + 1'b1;
            window_strobe <= 1'b0;
        end
    end

    // Безопасный перенос строба в домен clk_test
    logic [2:0] strobe_sync = '0;
    always_ff @(posedge clk_test) begin
        strobe_sync <= {strobe_sync[1:0], window_strobe};
    end
    
    wire sample_and_reset = (strobe_sync[1] && !strobe_sync[2]);

    // Домен измеряемой частоты (clk_test)
    logic [15:0] raw_edge_cnt = '0; 
    logic        freq_ok_test = 1'b0; // Флаг нормы внутри домена теста

    always_ff @(posedge clk_test) begin
        if (sample_and_reset) begin
            if (raw_edge_cnt >= MIN_TICKS) begin
                freq_ok_test <= 1'b1; 
            end else begin
                freq_ok_test <= 1'b0; 
            end
            raw_edge_cnt <= '0; 
        end else begin
            raw_edge_cnt <= raw_edge_cnt + 1'b1; 
        end
    end

    // ЗАЩИТА ОТ 0 ГЦ: Переносим флаг нормы обратно в домен clk_ref
    logic [1:0] freq_status_sync = '0;
    always_ff @(posedge clk_ref) begin
        freq_status_sync <= {freq_status_sync[0], freq_ok_test};
    end

    // Если частота пропала, триггеры freq_status_sync перестанут обновляться.
    // Выход сброса: активен, если стабильный домен clk_ref не видит флага готовности
    assign areset_out = !freq_status_sync[1];

endmodule : freq_watchdog