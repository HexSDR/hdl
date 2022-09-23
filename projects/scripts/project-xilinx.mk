####################################################################################
## Copyright (c) 2018 -2021 Analog Devices, Inc.
## SPDX short identifier: BSD-1-Clause
####################################################################################

# Assumes this file is in prpojects/scripts/project-xilinx.mk
HDL_PROJECT_PATH := $(subst scripts/project-xilinx.mk,,$(lastword $(MAKEFILE_LIST)))
HDL_LIBRARY_PATH := $(HDL_PROJECT_PATH)../library/

include $(HDL_PROJECT_PATH)../quiet.mk

# Parse the config file and convert it to environment variables
PARAMS_REPLACE_LIST := JESD LANE # list of words that should be removed from the parameter names
GEN_SED := '$(foreach name, $(PARAMS_REPLACE_LIST), s/$(name)//g;);s/_//g'
ifdef CFG
    include $(CFG)
    export $(shell sed 's/=.*//' $(CFG) | tr '\n' ' ')
    PARAMS := $(shell cat $(CFG) | tr '\n' ' ')
    DIR_NAME := $(basename $(notdir $(CFG)))
endif

VIVADO := vivado -mode batch -source

# Parse the variables passed to make and convert them to the filename format
CMD_VARIABLES := $(shell echo $(-*-command-variables-*-) | sed -e 's/CFG=[^ \n]*//g' | tac -s ' ')
ifneq ($(strip $(CMD_VARIABLES)), )
    PARAMS := $(shell echo $(CMD_VARIABLES) | sed -e 's/[=]/_/g')
    GEN_NAME := $(shell echo $(PARAMS) | sed -e $(GEN_SED) | sed -e 's/[ .]/_/g')
    DIR_NAME := $(if $(strip $(DIR_NAME)),$(DIR_NAME)_$(GEN_NAME),$(GEN_NAME))
endif

ifneq ($(strip $(DIR_NAME)), )
    PROJECT_NAME := $(DIR_NAME)/$(PROJECT_NAME)
    $(shell test -d $(DIR_NAME) || mkdir $(DIR_NAME))
    ADI_PROJECT_DIR := $(DIR_NAME)/
    export ADI_PROJECT_DIR
	VIVADO := vivado -log $(DIR_NAME)/vivado.log -journal $(DIR_NAME)/vivado.jou -mode batch -source 
endif

CLEAN_TARGET := *.cache
CLEAN_TARGET += *.data
CLEAN_TARGET += *.xpr
CLEAN_TARGET += xgui
CLEAN_TARGET += *.runs
CLEAN_TARGET += *.srcs
CLEAN_TARGET += *.sdk
CLEAN_TARGET += *.hw
CLEAN_TARGET += *.sim
CLEAN_TARGET += *.ip_user_files
CLEAN_TARGET += *.str
CLEAN_TARGET += mem_init_sys.txt
CLEAN_TARGET += *.csv
CLEAN_TARGET += *.hbs
CLEAN_TARGET += *.gen
CLEAN_TARGET += *.xpe
CLEAN_TARGET += *.xsa
ifneq ($(strip $(DIR_NAME)), )
    CLEAN_TARGET := $(addprefix $(DIR_NAME)/,$(CLEAN_TARGET))
endif
CLEAN_TARGET += .Xil
CLEAN_TARGET += *.log
CLEAN_TARGET += *.jou

CLEAN_DIRS := $(dir $(wildcard */*_vivado.log))

# Common dependencies that all projects have
M_DEPS += system_project.tcl
M_DEPS += system_bd.tcl
M_DEPS += $(wildcard system_top*.v)
M_DEPS += $(wildcard system_constr.xdc) # Not all projects have this file
M_DEPS += $(HDL_PROJECT_PATH)scripts/adi_project_xilinx.tcl
M_DEPS += $(HDL_PROJECT_PATH)../scripts/adi_env.tcl
M_DEPS += $(HDL_PROJECT_PATH)scripts/adi_board.tcl

M_DEPS += $(foreach dep,$(LIB_DEPS),$(HDL_LIBRARY_PATH)$(dep)/component.xml)

.PHONY: all lib clean clean-all

all: lib $(PROJECT_NAME).sdk/system_top.xsa

clean:
	-rm -f reference.dcp
	$(call clean, \
		$(CLEAN_TARGET), \
		$(HL)$(PROJECT_NAME)$(NC) project)
	-rm -Rf ${DIR_NAME}

clean-all: clean
	@for lib in $(LIB_DEPS); do \
		$(MAKE) -C $(HDL_LIBRARY_PATH)$${lib} clean; \
	done
	@for dir in ${CLEAN_DIRS}; do \
		rm -Rf $${dir}; \
	done

MODE ?= "default"

$(PROJECT_NAME).sdk/system_top.xsa: $(M_DEPS)
	@if [ $(MODE) = incr ]; then \
		if [ -f */impl_1/system_top_routed.dcp ]; then \
			echo Found previous run result at `ls */impl_1/system_top_routed.dcp`; \
			cp -u */impl_1/system_top_routed.dcp ./reference.dcp ; \
		fi; \
		if [ -f ./reference.dcp ]; then \
			echo Using reference checkpoint for incremental compilation; \
		fi; \
	else \
		rm -f reference.dcp; \
	fi;
	-rm -rf $(CLEAN_TARGET)
	$(call build, \
		$(VIVADO) system_project.tcl, \
		$(PROJECT_NAME)_vivado.log, \
		$(HL)$(PROJECT_NAME)$(NC) project)

lib:
	@for lib in $(LIB_DEPS); do \
		if [ -n "${REQUIRED_VIVADO_VERSION}" ]; then \
			$(MAKE) -C $(HDL_LIBRARY_PATH)$${lib} xilinx REQUIRED_VIVADO_VERSION=${REQUIRED_VIVADO_VERSION} || exit $$?; \
		else \
			$(MAKE) -C $(HDL_LIBRARY_PATH)$${lib} xilinx || exit $$?; \
		fi; \
	done

