
ifeq ($(NVIDIA_CLEARED),false)
$(error $(LOCAL_PATH): NVIDIA variables not cleared)
endif
NVIDIA_CLEARED := false

# output directory for generated files

ifneq ($(findstring $(LOCAL_MODULE_CLASS),EXECUTABLES STATIC_LIBRARIES SHARED_LIBRARIES),)

intermediates := $(local-intermediates-dir)

# idl rules

$(foreach stub,$(LOCAL_NVIDIA_STUBS), \
  $(eval _stubFrom := $(TEGRA_ROOT)/include/$(patsubst %_stub.c,%.idl,$(stub))) \
  $(eval _stubTo := $(intermediates)/$(stub)) \
  $(eval $(call nvidl-rule,-s,$(_stubFrom),$(_stubTo))) \
  $(eval LOCAL_GENERATED_SOURCES += $(_stubTo)) \
 )
_stubFrom :=
_stubTo :=

$(foreach disp,$(LOCAL_NVIDIA_DISPATCHERS), \
  $(eval _dispFrom := $(TEGRA_ROOT)/include/$(patsubst %_dispatch.c,%.idl,$(disp))) \
  $(eval _dispTo := $(intermediates)/$(disp)) \
  $(eval $(call nvidl-rule,-d,$(_dispFrom),$(_dispTo))) \
  $(eval LOCAL_GENERATED_SOURCES += $(_dispTo)) \
 )
_dispFrom :=
_dispTo :=

ifneq ($(strip $(LOCAL_NVIDIA_PKG_DISPATCHER)),)
$(eval $(call nvidl-rule,-g, \
	$(TEGRA_ROOT)/include/$(LOCAL_NVIDIA_PKG).idl, \
	$(intermediates)/$(LOCAL_NVIDIA_PKG_DISPATCHER)))
LOCAL_GENERATED_SOURCES += $(intermediates)/$(LOCAL_NVIDIA_PKG_DISPATCHER)
endif

# shader rules

# LOCAL_NVIDIA_SHADERS is relative to LOCAL_PATH
# LOCAL_NVIDIA_GEN_SHADERS is relative to intermediates

ifneq ($(strip $(LOCAL_NVIDIA_SHADERS) $(LOCAL_NVIDIA_GEN_SHADERS)),)

# Cg and GLSL shader binaries (.cghex) and source (.xxxh)

$(foreach shadertype,glslv glslf cgv cgf,\
	$(eval $(call shader-rule,$(shadertype),\
		$(LOCAL_NVIDIA_SHADERS),\
		$(LOCAL_NVIDIA_GEN_SHADERS))))

$(ALL_SHADERS_COMPILE_glslv): PRIVATE_CGOPTS := -profile ar20vp -ogles
$(ALL_SHADERS_COMPILE_glslf): PRIVATE_CGOPTS := -profile ar20fp -ogles
$(ALL_SHADERS_COMPILE_cgv): PRIVATE_CGOPTS := -profile ar20vp
$(ALL_SHADERS_COMPILE_cgf): PRIVATE_CGOPTS := -profile ar20fp

$(ALL_SHADERS_COMPILE_glslv) $(ALL_SHADERS_COMPILE_glslf) $(ALL_SHADERS_COMPILE_cgv) $(ALL_SHADERS_COMPILE_cgf): $(NVIDIA_CGC)
$(ALL_SHADERS_glslv) $(ALL_SHADERS_glslf) $(ALL_SHADERS_cgv) $(ALL_SHADERS_cgf): $(NVIDIA_SHADERFIX)

# Ar20 assembly to header (.h)

GEN_AR20FRG := $(addprefix $(intermediates)/shaders/, \
	$(patsubst %.ar20frg,%.h,$(filter %.ar20frg,$(LOCAL_NVIDIA_SHADERS))))
$(GEN_AR20FRG): $(intermediates)/shaders/%.h : $(LOCAL_PATH)/%.ar20frg
	$(transform-ar20asm-to-h)
$(GEN_AR20FRG): $(NVIDIA_AR20ASM)

# Common dependencies and declarations

ALL_GENERATED_FILES := $(foreach shadertype,glslv glslf cgv cgf,\
		           $(ALL_SHADERS_$(shadertype)) \
		           $(ALL_SHADERS_NOFIX_$(shadertype)) \
			   $(ALL_SHADERSRC_$(shadertype))) $(GEN_AR20FRG)

LOCAL_GENERATED_SOURCES += $(ALL_GENERATED_FILES)
LOCAL_C_INCLUDES += $(sort $(dir $(ALL_GENERATED_FILES)))

endif
endif

# NVIDIA build targets

ifneq ($(LOCAL_MODULE),)
NVIDIA_TARGET_NAME := $(LOCAL_MODULE)
else
NVIDIA_TARGET_NAME := $(LOCAL_PACKAGE_NAME)
endif

ifeq ($(NVIDIA_TARGET_NAME),)
$(error $(LOCAL_PATH): Neither LOCAL_MODULE nor LOCAL_PACKAGE_NAME is defined!)
endif

# Add to nvidia module list
ALL_NVIDIA_MODULES += $(NVIDIA_TARGET_NAME)

# Add dependency to Android.mk
ifeq ($(filter $(LOCAL_PATH)/%,$(NVIDIA_MAKEFILE)),)
$(warning $(NVIDIA_MAKEFILE) not under $(LOCAL_PATH) for module $(NVIDIA_TARGET_NAME))
else
LOCAL_ADDITIONAL_DEPENDENCIES += $(NVIDIA_MAKEFILE)
endif

# Add to nvidia goals
nvidia-clean: clean-$(NVIDIA_TARGET_NAME)

ifneq ($(findstring nvidia_tests,$(LOCAL_MODULE_TAGS)),)
nvidia-tests: $(NVIDIA_TARGET_NAME)
else
nvidia-modules: $(NVIDIA_TARGET_NAME)
endif

NVIDIA_TARGET_NAME :=
