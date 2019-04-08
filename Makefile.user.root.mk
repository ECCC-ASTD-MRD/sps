ifneq (,$(DEBUGMAKE))
$(info ## ====================================================================)
$(info ## File: $$sps/Makefile.user.root.mk)
$(info ## )
endif
#VERBOSE=1

components_install:
	$(MYTIME) $(MAKE) -f Makefile.build.mk $(NOPRINTDIR) $@ $(MYMAKE_VARS)
components_uninstall:
	$(MYTIME) $(MAKE) -f Makefile.build.mk $(NOPRINTDIR) $@ $(MYMAKE_VARS)

ifneq (,$(DEBUGMAKE))
$(info ## ==== $$sps/Makefile.user.mk [END] ==================================)
endif
