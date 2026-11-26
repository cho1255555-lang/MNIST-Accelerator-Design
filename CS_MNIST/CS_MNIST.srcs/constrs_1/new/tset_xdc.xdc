# 100MHz 클럭 정의 (주기 10ns)
 create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]
# 200Mhz 클럭 정의 
#create_clock -period 5.000 -name sys_clk_pin -waveform {0.000 2.500} [get_ports clk]