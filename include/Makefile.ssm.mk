ifneq (,$(DEBUGMAKE))
$(info ## ====================================================================)
$(info ## File: $$sps/include/Makefile.ssm.mk)
$(info ## )
endif
#---- SSM build  upport  -------------------------------------------

SPS_SSMALL_NAME  = sps$(SPS_SFX)_$(SPS_VERSION)_all
SPS_SSMARCH_NAME = sps$(SPS_SFX)+$(COMP_ARCH)_$(SPS_VERSION)_$(SSMARCH)
SPS_SSMALL_FILES  = $(SPS_SSMALL_NAME).ssm
SPS_SSMARCH_FILES = $(SPS_SSMARCH_NAME).ssm

SPS_SSM_RELDIRBNDL = ENV/SPS/$(SPS_VERSION_X)

SSM_DEPOT_DIR := $(HOME)/SsmDepot
SSM_BASE      := $(HOME)/SsmBundles
SSM_BASE2     := $(HOME)/SsmBundles
SPS_SSM_BASE_DOM  = $(SSM_BASE)/ENV/SPS/d/$(SPS_VERSION_X)sps
SPS_SSM_BASE_BNDL = $(SSM_BASE)/ENV/SPS/$(SPS_VERSION_X)sps
SPS_INSTALL   = sps_install
SPS_UNINSTALL = sps_uninstall

.PHONY: sps_ssm sps_ssm_all.ssm rm_sps_ssm_all.ssm sps_ssm_all rm_sps_ssm_all sps_ssm_arch.ssm rm_sps_ssm_arch.ssm sps_ssm_arch sps_ssm_arch_rm
sps_ssm: sps_ssm_all.ssm sps_ssm_arch.ssm
rm_sps_ssm: rm_sps_ssm_all.ssm rm_sps_ssm_all rm_sps_ssm_arch.ssm sps_ssm_arch_rm

sps_ssm_all.ssm: $(SPS_SSMALL_FILES)
$(SPS_SSMALL_FILES): sps_ssm_all rm_sps_ssm_all.ssm $(SSM_DEPOT_DIR)/$(SPS_SSMALL_NAME).ssm
rm_sps_ssm_all.ssm:
	rm -f $(SSM_DEPOT_DIR)/$(SPS_SSMALL_NAME).ssm
$(SSM_DEPOT_DIR)/$(SPS_SSMALL_NAME).ssm:
	cd $(BUILDSSM) ;\
	chmod a+x $(basename $(notdir $@))/bin/* 2>/dev/null || true ;\
	tar czvf $@ $(basename $(notdir $@))
	ls -l $@

sps_ssm_all: rm_sps_ssm_all $(BUILDSSM)/$(SPS_SSMALL_NAME)
rm_sps_ssm_all:
	rm -rf $(BUILDSSM)/$(SPS_SSMALL_NAME)
$(BUILDSSM)/$(SPS_SSMALL_NAME):
	rm -rf $@ ; mkdir -p $@ ; \
	rsync -av --exclude-from=$(DIRORIG_sps)/.ssm.d/exclude $(DIRORIG_sps)/ $@/ ; \
	echo "Dependencies (s.ssmuse.dot): " > $@/BUILDINFO ; \
	cat $@/ssmusedep.bndl >> $@/BUILDINFO ; \
	.rdemk_ssm_control sps $(SPS_VERSION) all $@/BUILDINFO $@/DESCRIPTION > $@/.ssm.d/control
	.rdemkversionfile sps $(SPS_VERSION) $@/include/$(EC_ARCH) sh
	export ATM_MODEL_BNDL="$(SPS_SSM_RELDIRBNDL)$(SPS_VERSION)" ;\
	export ATM_MODEL_DSTP="`date '+%Y-%m-%d %H:%M %Z'`" ;\
	cat $@/bin/.env_setup.dot0 \
	| sed "s|__MY_BNDL__|$${ATM_MODEL_BNDL#./}|" \
	| sed "s|__MY_DSTP__|$${ATM_MODEL_DSTP}|" \
	> $@/bin/.env_setup.dot

sps_ssm_arch.ssm: $(SPS_SSMARCH_FILES)
$(SPS_SSMARCH_FILES): sps_ssm_arch rm_sps_ssm_arch.ssm $(SSM_DEPOT_DIR)/$(SPS_SSMARCH_NAME).ssm
rm_sps_ssm_arch.ssm:
	rm -f $(SSM_DEPOT_DIR)/$(SPS_SSMARCH_NAME).ssm
$(SSM_DEPOT_DIR)/$(SPS_SSMARCH_NAME).ssm:
	cd $(BUILDSSM) ; tar czvf $@ $(basename $(notdir $@))
	ls -l $@

sps_ssm_arch: sps_ssm_arch_rm $(BUILDSSM)/$(SPS_SSMARCH_NAME)
sps_ssm_arch_rm:
	rm -rf $(BUILDSSM)/$(SPS_SSMARCH_NAME)
$(BUILDSSM)/$(SPS_SSMARCH_NAME):
	mkdir -p $@/lib/$(EC_ARCH) ; \
	ln -s $(EC_ARCH) $@/lib/$(COMP_ARCH)/. ; \
	touch $@/lib/libdummy_$(SPS_SSMARCH_NAME).a ; \
	cd $(LIBDIR) ; \
	rsync -av `ls libsps*.a libsps*.a.fl libsps*.so 2>/dev/null` $@/lib/$(EC_ARCH)/ ; \
	if [[ x$(MAKE_SSM_NOMOD) != x1 ]] ; then \
		mkdir -p $@/include/$(EC_ARCH) ; \
		ln -s $(EC_ARCH) $@/include/$(COMP_ARCH)/. ; \
		touch $@/include/dummy_$(SPS_SSMARCH_NAME).inc ; \
		cd $(MODDIR) ; \
		cp $(SPS_MOD_FILES) $@/include/$(EC_ARCH) ; \
	fi ; \
	if [[ x$(MAKE_SSM_NOINC) != x1 ]] ; then \
		mkdir -p $@/include/$(EC_ARCH) ; \
		touch $@/include/dummy_$(SPS_SSMARCH_NAME).mod ; \
		echo $(BASE_ARCH) > $@/include/$(BASE_ARCH)/.restricted ; \
		echo $(ORDENV_PLAT) >> $@/include/$(BASE_ARCH)/.restricted ; \
		echo $(EC_ARCH) > $@/include/$(EC_ARCH)/.restricted ; \
		echo $(ORDENV_PLAT)/$(COMP_ARCH) >> $@/include/$(EC_ARCH)/.restricted ; \
		.rdemkversionfile sps $(SPS_VERSION) $@/include/$(EC_ARCH) f ; \
		.rdemkversionfile sps $(SPS_VERSION) $@/include/$(EC_ARCH) c ; \
		.rdemkversionfile sps $(SPS_VERSION) $@/include/$(EC_ARCH) sh ; \
	fi ; \
	if [[ x$(MAKE_SSM_NOABS) != x1 ]] ; then \
		mkdir -p $@/bin/$(BASE_ARCH) ; \
		touch $@/bin/dummy_$(SPS_SSMARCH_NAME).bin ; \
		cd $(BINDIR) ; \
		cp $(SPS_ABS_FILES) $@/bin/$(BASE_ARCH) ; \
	fi ; \
	cp -R $(DIRORIG_sps)/.ssm.d $@/ ; \
	.rdemk_ssm_control sps $(SPS_VERSION) $(SSMORDARCH) $@/BUILDINFO $@/DESCRIPTION > $@/.ssm.d/control 


.PHONY: sps_install sps_uninstall
sps_install: 
	if [[ x$(CONFIRM_INSTALL) != xyes ]] ; then \
		echo "Please use: make $@ CONFIRM_INSTALL=yes" ;\
		exit 1;\
	fi
	cd $(SSM_DEPOT_DIR) ;\
	rdessm-install -v \
			--dest=$(SPS_SSM_BASE_DOM)/sps_$(SPS_VERSION) \
			--bndl=$(SPS_SSM_BASE_BNDL)/$(SPS_VERSION).bndl \
			--pre=$(sps)/ssmusedep.bndl \
			--post=$(sps)/ssmusedep_post.bndl \
			--base=$(SSM_BASE2) \
			sps{_,+*_,-d+*_}$(SPS_VERSION)_*.ssm

sps_uninstall:
	if [[ x$(UNINSTALL_CONFIRM) != xyes ]] ; then \
		echo "Please use: make $@ UNINSTALL_CONFIRM=yes" ;\
		exit 1;\
	fi
	cd $(SSM_DEPOT_DIR) ;\
	rdessm-install -v \
			--dest=$(SPS_SSM_BASE_DOM)/sps_$(SPS_VERSION) \
			--bndl=$(SPS_SSM_BASE_BNDL)/$(SPS_VERSION).bndl \
			--base=$(SSM_BASE2) \
			--uninstall

ifneq (,$(DEBUGMAKE))
$(info ## ==== $$sps/include/Makefile.ssm.mk [END] ========================)
endif
