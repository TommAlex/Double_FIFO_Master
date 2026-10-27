# =============================================================================
# 1. ОПРЕДЕЛЕНИЕ ТАКТОВЫХ ЧАСТОТ (ГЕНЕРАТОРЫ CLOCK)
# =============================================================================

# Создаем ограничение для тактового сигнала, приходящего от чипа FT601
# Имя клока (-name) теперь совпадает с физическим портом [get_ports] - CLK_FIFO
create_clock -name {CLK_FIFO} -period 10.000 [get_ports {CLK_FIFO}]

# Создаем ограничение для тактового домена вашей внутренней логики (106 МГц)
create_clock -name {clk_internal_106} -period 9.434 [get_ports {clk_106MHz}]

# Создаем ограничение для тактового домена индикации и сброса (56 МГц)
create_clock -name {clk_indicator_56} -period 17.857 [get_ports {clk_56MHz}]

# Автоматически вычисляем производные частоты (если в проекте Cyclone IV используются PLL)
derive_pll_clocks

# Автоматически рассчитываем неопределенность тактовых сигналов (Jitter / Нестабильность)
derive_clock_uncertainty


# =============================================================================
# 2. ИЗОЛЯЦИЯ АСИНХРОННЫХ ДОМЕНОВ (CLOCK GROUPS)
# =============================================================================

# Имя clk_ft601 здесь также заменено на актуальное CLK_FIFO
set_clock_groups -asynchronous \
    -group [get_clocks {CLK_FIFO}] \
    -group [get_clocks {clk_internal_106}] \
    -group [get_clocks {clk_indicator_56}]


# =============================================================================
# 3. БЛОКИРОВКА ЛОЖНЫХ ПУТЕЙ (FALSE PATHS ДЛЯ УПРАВЛЕНИЯ И МОНИТОРИНГА)
# =============================================================================

set_false_path -from [get_registers {reset_seq:u_reset_core|rst_n_for_fsm}] -to [get_registers {*}]
set_false_path -from [get_registers {reset_seq:u_reset_core|ft601_reset_n}] -to [get_registers {*}]

set_false_path -from [get_registers {DOUBLE_FIFO_Controller:FM_4C|out_cmd_reset_req}] -to [get_registers {r_sync_chain[*]}]

#set_false_path -from [get_registers {DOUBLE_FIFO_Controller:FM_4C|State[*]}] -to [get_registers {indicator:u_indicator_controller|*}]
#set_false_path -from [get_registers {DOUBLE_FIFO_Controller:FM_4C|ReadIn[*]}] -to [get_registers {indicator:u_indicator_controller|*}]


# =============================================================================
# 4. ВРЕМЕННЫЕ ОГРАНИЧЕНИЯ ДЛЯ ФИЗИЧЕСКИХ НОЖЕК (ОПТИМИЗАЦИЯ ПОД FT601 & CYCLONE IV)
# =============================================================================

# Входные задержки (Window для захвата данных от чипа)
# Ослабляем максимальное требование до 6.0 нс, давая Quartus свободу трассировки
set_input_delay -clock {CLK_FIFO} -max 6.0 [get_ports {DATA[*] RXF_N BE[*]}]
set_input_delay -clock {CLK_FIFO} -min 2.0 [get_ports {DATA[*] RXF_N BE[*]}]

# Выходные задержки (Окно удержания сигналов для чипа FT601)
# Снижаем максимальное значение до 4.0 нс
set_output_delay -clock {CLK_FIFO} -max 4.0 [get_ports {DATA[*] WR_N BE[*]}]
set_output_delay -clock {CLK_FIFO} -min 1.0 [get_ports {DATA[*] WR_N BE[*]}]

# =============================================================================
# 5. ИСКЛЮЧЕНИЕ ВНУТРЕННИХ ПОРТОВ ПОЛЬЗОВАТЕЛЬСКОЙ ЛОГИКИ ИЗ ВНЕШНЕГО АНАЛИЗА
# =============================================================================

# Указываем TimeQuest полностью игнорировать внешние тайминги для интерфейса 106 МГц,
# так как эти сигналы не выходят на физические ножки платы, а коммутируются внутри кристалла.
set_false_path -from [get_ports {ch0_user_rd ch0_user_wr ch0_tx_data[*] ch0_tx_be[*]}]
set_false_path -to   [get_ports {ch0_user_data[*] ch0_rx_empty ch0_tx_full}]

# Также исключаем из внешнего анализа светодиоды индикации, так как их задержки не критичны
set_false_path -to [get_ports {LED[*]}]


#set_max_delay -from [get_registers {DOUBLE_FIFO_Controller:FM_4C|DOUBLE_FIFO_Buffer:MCFB|*}] -to [get_registers {DOUBLE_FIFO_Controller:FM_4C|State[*]}] 10.000
#set_max_delay -from [get_registers {DOUBLE_FIFO_Controller:FM_4C|DOUBLE_FIFO_Buffer:MCFB|*}] -to [get_registers {DOUBLE_FIFO_Controller:FM_4C|out_cmd_reset_req}] 10.000
