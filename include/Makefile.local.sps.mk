ifneq (,$(DEBUGMAKE))
$(info ## ====================================================================)
$(info ## File: $$sps/include/Makefile.local.mk)
$(info ## )
endif

## Sps definitions

ifeq (,$(wildcard $(sps)/VERSION))
   $(error Not found: $(sps)/VERSION)
endif
SPS_VERSION0  = $(shell cat $(sps)/VERSION)
SPS_VERSION   = $(notdir $(SPS_VERSION0))
SPS_VERSION_X = $(dir $(SPS_VERSION0))

## Some Shortcut/Alias to Lib Names
SPS_LIBS_DEP = $(RPNPHY_LIBS_V) $(MODELUTILS_LIBS_NOSTUBS_V) $(SPS_LIBS_V) $(RPNPHY_LIBS_V) $(MODELUTILS_LIBS_NOSTUBS_V) $(MODELUTILS_LIBS_DEP)

SPS_LIBS_MERGED = sps_base
SPS_LIBS_OTHER  = 
SPS_LIBS_ALL    = $(SPS_LIBS_MERGED) $(SPS_LIBS_OTHER)
SPS_LIBS        = sps $(SPS_LIBS_OTHER) 
SPS_LIBS_V      = sps_$(SPS_VERSION) $(SPS_LIBS_OTHER) 

SPS_LIBS_ALL_FILES = $(foreach item,$(SPS_LIBS_ALL),$(LIBDIR)/lib$(item).a)
SPS_LIBS_ALL_FILES_PLUS = $(LIBDIR)/libsps.a $(SPS_LIBS_ALL_FILES) 

OBJECTS_MERGED_sps = $(foreach item,$(SPS_LIBS_MERGED),$(OBJECTS_$(item)))

SPS_MOD_FILES   = $(foreach item,$(FORTRAN_MODULES_sps),$(item).[Mm][Oo][Dd])

SPS_ABS         = sps sps_yyencode
SPS_ABS_FILES   = $(BINDIR)/$(mainsps) $(BINDIR)/$(mainsps_yyencode)

## Base Libpath and libs with placeholders for abs specific libs
#MODEL3_LIBAPPL = $(SPS_LIBS_V)
#MODEL3_LIBPATH = $(LIBCHMPATH)

## System-wide definitions

RDE_LIBS_USER_EXTRA := $(RDE_LIBS_USER_EXTRA) $(SPS_LIBS_ALL_FILES_PLUS)
RDE_BINS_USER_EXTRA := $(RDE_BINS_USER_EXTRA) $(SPS_ABS_FILES)

ifeq (1,$(RDE_LOCAL_LIBS_ONLY))
   SPS_ABS_DEP = $(SPS_LIBS_ALL_FILES_PLUS) $(RPNPHY_ABS_DEP)
endif

##
.PHONY: sps_vfiles
SPS_VFILES = sps_version.inc sps_version.h
sps_vfiles: $(SPS_VFILES)
sps_version.inc:
	.rdemkversionfile "sps" "$(SPS_VERSION)" . f
sps_version.h:
	.rdemkversionfile "sps" "$(SPS_VERSION)" . c

#---- Abs targets -----------------------------------------------------

## Sps Targets

.PHONY: sps allbin_sps allbincheck_sps

mainsps  = $(ABSPREFIX)sps$(ABSPOSTFIX)_$(BASE_ARCH).Abs
sps: | sps_rm $(BINDIR)/$(mainsps)
	ls -l $(BINDIR)/$(mainsps)
sps_rm:
	rm -f $(BINDIR)/$(mainsps)
$(BINDIR)/$(mainsps): $(SPS_ABS_DEP) | $(SPS_VFILES)
	export MAINSUBNAME="sps" ;\
	export ATM_MODEL_NAME="$${MAINSUBNAME} $(BUILDNAME)" ;\
	export ATM_MODEL_VERSION="$(SPS_VERSION)" ;\
	export RBUILD_LIBAPPL="$(SPS_LIBS_V) $(SPS_LIBS_DEP)" ;\
	$(RBUILD4objMPI)

mainsps_yyencode=sps_yyencode.Abs
sps_yyencode: | sps_yyencode_rm $(BINDIR)/$(mainsps_yyencode)
	ls -l $(BINDIR)/$(mainsps_yyencode)
sps_yyencode_rm:
	rm -f $(BINDIR)/$(mainsps_yyencode)
$(BINDIR)/$(mainsps_yyencode): $(SPS_ABS_DEP) | $(MODELUTILS_VFILES)
	export MAINSUBNAME="sps_yyencode" ;\
	export ATM_MODEL_NAME="$${MAINSUBNAME} $(BUILDNAME)" ;\
	export ATM_MODEL_VERSION="$(SPS_VERSION)" ;\
	export RBUILD_LIBAPPL="$(SPS_LIBS_V) $(SPS_LIBS_DEP)" ;\
	export RBUILD_COMM_STUBS="$(LIBCOMM_STUBS)  $(MODELUTILS_DUMMYMPISTUBS)";\
	$(RBUILD4objNOMPI)

allbin_sps: | $(SPS_ABS)
allbincheck_sps:
	for item in $(SPS_ABS_FILES) ; do \
		if [[ ! -x $${item} ]] ; then exit 1 ; fi ;\
	done ;\
	exit 0

#---- Lib target - automated ------------------------------------------

.PHONY: sps_libs
sps_libs: $(OBJECTS_sps) $(SPS_LIBS_ALL_FILES_PLUS) | $(SPS_VFILES)
$(foreach item,$(SPS_LIBS_ALL),$(eval $(call LIB_template1,$(item),SPS)))
$(foreach item,$(SPS_LIBS_ALL),$(eval $(call LIB_template2,$(item),SPS)))

$(LIBDIR)/libsps_$(SPS_VERSION).a: $(OBJECTS_sps) | $(SPS_VFILES)
	rm -f $@ $@_$$$$; ar r $@_$$$$ $(OBJECTS_MERGED_sps); mv $@_$$$$ $@
$(LIBDIR)/libsps.a: $(LIBDIR)/libsps_$(SPS_VERSION).a
	cd $(LIBDIR) ; rm -f $@ ;\
	ln -s libsps_$(SPS_VERSION).a $@

ifneq (,$(DEBUGMAKE))
$(info ## ==== $$sps/include/Makefile.local.mk [END] ======================)
endif
