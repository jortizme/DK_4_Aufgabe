# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DELAY_SLOT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SDI_BAUDRATE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SYS_FREQUENCY" -parent ${Page_0}


}

proc update_PARAM_VALUE.DELAY_SLOT { PARAM_VALUE.DELAY_SLOT } {
	# Procedure called to update DELAY_SLOT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DELAY_SLOT { PARAM_VALUE.DELAY_SLOT } {
	# Procedure called to validate DELAY_SLOT
	return true
}

proc update_PARAM_VALUE.SDI_BAUDRATE { PARAM_VALUE.SDI_BAUDRATE } {
	# Procedure called to update SDI_BAUDRATE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SDI_BAUDRATE { PARAM_VALUE.SDI_BAUDRATE } {
	# Procedure called to validate SDI_BAUDRATE
	return true
}

proc update_PARAM_VALUE.SYS_FREQUENCY { PARAM_VALUE.SYS_FREQUENCY } {
	# Procedure called to update SYS_FREQUENCY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SYS_FREQUENCY { PARAM_VALUE.SYS_FREQUENCY } {
	# Procedure called to validate SYS_FREQUENCY
	return true
}


proc update_MODELPARAM_VALUE.SYS_FREQUENCY { MODELPARAM_VALUE.SYS_FREQUENCY PARAM_VALUE.SYS_FREQUENCY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SYS_FREQUENCY}] ${MODELPARAM_VALUE.SYS_FREQUENCY}
}

proc update_MODELPARAM_VALUE.SDI_BAUDRATE { MODELPARAM_VALUE.SDI_BAUDRATE PARAM_VALUE.SDI_BAUDRATE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SDI_BAUDRATE}] ${MODELPARAM_VALUE.SDI_BAUDRATE}
}

proc update_MODELPARAM_VALUE.DELAY_SLOT { MODELPARAM_VALUE.DELAY_SLOT PARAM_VALUE.DELAY_SLOT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DELAY_SLOT}] ${MODELPARAM_VALUE.DELAY_SLOT}
}

