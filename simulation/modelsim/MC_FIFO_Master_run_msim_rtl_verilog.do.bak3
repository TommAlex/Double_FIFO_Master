transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/fifo_pll.v}
vlog -vlog01compat -work work +incdir+Z:/MC_FIFO_M_FT601/db {Z:/MC_FIFO_M_FT601/db/fifo_pll_altpll.v}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/freq_watchdog.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/pwm_pulse.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/MC_FIFO_Master.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/MC_FIFO_Counter.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/MC_FIFO_Controller.sv}

vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/tb_MC_FIFO_Master.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/freq_watchdog.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/pwm_pulse.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/MC_FIFO_Counter.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/MC_FIFO_Controller.sv}
vlog -sv -work work +incdir+Z:/MC_FIFO_M_FT601 {Z:/MC_FIFO_M_FT601/MC_FIFO_Master.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  tb_MC_FIFO_Master

add wave *
view structure
view signals
run -all
