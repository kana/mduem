# mduem - Little utility for little software development
#
# This is a library Makefile to maintain software development, especially for
# Vim script.  Note that this Makefile requires GNU make to use.
# Coding Rules  #{{{1
#
# - Use non-empty string as true and empty string as false.
#
#
# Naming Rules:
#
# - Use UPPER_CASE variables to be configured by user.
#
# - Use lower_case variables for internal use of mduem.
#
# - Use suffix "_p" to indicate that a boolean value is resulted from
#   a variable.
#   Example: SHOULD_INSTALL_ASIS_P
#
# - Use noun for ordinary variables.
#   Example: repos_name, TARGETS_GENERATED
#
# - Use verb for variables as functions.
#   Example: resolve_dep_uri, RENAME_TARGET
#
# - Use prefix "generate_rule_" for variables to generate make rules.
#   Example: generate_rule_to_install_a_target
#
# - Use abbreviations for words which names are too long to code.
#   Example: dependency => dep, directory => dir, repository => repos
#
# - Use lower-case names for phony targets.
#
# - Use verb for phony targets.
#   Example: clean, install, pack, ...
#
# - Use hyphens to join words in names of phony targets.
#   Example: clean-junks, fetch-deps
#
# - Use prefix "," for names of files which are automatically generated by
#   mduem and they are temporary ones.
#   Example: t/,good-case.output
#
# - Use directory ".mduem" to contain stuffs for internal use.
#   Example: .mduem/cache/
#
# - All rules may be violated if there is a strong custom from old times.
#   Example: all (phony target)








# Common  #{{{1

# Use "all" as the default target if no targets were specified on the command
# line or any other rules were defined before including this Makefile.
.DEFAULT_GOAL := all
all:

SHELL := /bin/bash
this_makefile := $(lastword $(MAKEFILE_LIST))
cache_makefile := .mduem/cache/Makefile.variables
user_makefiles := $(filter-out \
                    $(this_makefile) $(cache_makefile), \
                    $(MAKEFILE_LIST))

not = $(if $(1),,t)
toplevel_dir := $(shell git rev-parse --show-toplevel 2>/dev/null)
inner_dir := $(shell git rev-parse --show-prefix 2>/dev/null)
git_controlled_p := $(toplevel_dir)
toplevel_dir_p := $(and $(git_controlled_p),$(call not,$(inner_dir)))

ifneq '$(git_controlled_p)' ''
$(cache_makefile): \
		$(toplevel_dir)/.git/config \
		$(toplevel_dir)/.git/index \
		$(this_makefile)
	@echo 'GENERATE $@'
	@mkdir -p '$(dir $@)'
	@{ \
	   current_branch="$$(git symbolic-ref -q HEAD \
	                      | sed -e 's|^refs/heads/||')"; \
	   _origin_name="$$(git config "branch.$$current_branch.remote")"; \
	   origin_name="$${_origin_name:-origin}"; \
	   _origin_uri="$$(git config "remote.$$origin_name.url")"; \
	   origin_uri="$${_origin_uri:-../.}"; \
	   \
	   echo "all_files_in_repos := \
	         $(filter-out .gitmodules \
	                      $(shell cd $(toplevel_dir) && \
	                              git submodule foreach 'echo "$$path"'),\
	           $(shell git ls-files))"; \
	   echo "current_branch := $${current_branch}"; \
	   echo "origin_name := $${origin_name}"; \
	   echo "origin_uri := $${origin_uri}"; \
	   echo 'repos_name := $(notdir $(shell pwd))'; \
	   echo 'version := $(shell git describe --tags --always --dirty)'; \
	 } >'$@'
endif
include $(cache_makefile)

	# The type of a repository.  It must be one of the following values:
	#
	# generic       For any software.
	# vim-script    For Vim plugins, etc.
REPOS_TYPE ?= $(if $(filter vim-%,$(repos_name)),vim-script,generic)
vim_script_repos_p := $(filter vim-script,$(REPOS_TYPE))








# all  #{{{1

.PHONY: all
all: build








# build  #{{{1

TARGETS_ARCHIVED ?= $(all_files_in_repos)
TARGETS_GENERATED ?=# Empty
TARGETS_STATIC ?=# Empty

targets_all_installed := $(TARGETS_GENERATED) $(TARGETS_STATIC)
targets_all_archived := $(sort \
                          $(TARGETS_ARCHIVED) \
                          $(targets_all_installed) \
                          $(cache_makefile) \
                          )




.PHONY: build
build: $(targets_all_installed)








# clean  #{{{1

.PHONY: clean
clean: clean-generated clean-junks

.PHONY: clean-generated
clean-generated:
	@echo 'CLEAN-GENERATED'
	@rm -rf $(TARGETS_GENERATED)
	@find -name '.mduem' | xargs rm -rf

.PHONY: clean-junks
clean-junks:
	@echo 'CLEAN-JUNKS'
	@find -name '*~' -or -name ',*' | xargs rm -rf








# fetch-deps  #{{{1

DEPS ?=# Empty
vim_script_deps := $(if $(vim_script_repos_p),vim-vspec vimup,)
all_deps := $(vim_script_deps) $(DEPS)

DEP_vim_vspec_URI ?= ../vim-vspec
DEP_vim_vspec_VERSION ?= 1.0.2

DEP_vimup_URI ?= ../vimup
DEP_vimup_VERSION ?= 0.0.1


	# BUGS: This resolves "../" just once, but it's enough for usual cases.
resolve_dep_uri = $(strip $(if $(filter ../%,$(1)), \
                            $(dir $(origin_uri))$(1:../%=%), \
                            $(1)))
normalize_dep_name = $(subst -,_,$(1))
get_dep_raw_uri = $(DEP_$(call normalize_dep_name,$(1))_URI)
get_dep_dir_name = $(patsubst %.git,%,$(notdir $(call get_dep_uri,$(1))))

get_dep_uri = $(call resolve_dep_uri,$(call get_dep_raw_uri,$(1)))
get_dep_version = $(DEP_$(call normalize_dep_name,$(1))_VERSION)
get_dep_dir = .mduem/deps/$(call get_dep_dir_name,$(1))




.PHONY: fetch-deps
fetch-deps: $(all_deps:%=.mduem/deps/,%)

# FIXME: Update for changes on only DEPS and other values.
.mduem/deps/,%: $(user_makefiles)
	@echo 'FETCH-DEP $*'
	@mkdir -p '$(dir $@)'
	@   ( \
	         if [ -d '$(call get_dep_dir,$*)' ] \
	      ;  then \
	           cd './$(call get_dep_dir,$*)' \
	      &&   git fetch \
	      &&   git checkout -f mduem-master \
	      ;  else \
	           git clone '$(call get_dep_uri,$*)' '$(call get_dep_dir,$*)'\
	      &&   cd './$(call get_dep_dir,$*)' \
	      &&   git checkout -b mduem-master \
	      ;  fi \
	      && git reset --hard '$(call get_dep_version,$*)' \
	 ;  ) &>'$@.log' \
	 || { cat '$@.log'; false; }
	@touch '$@'








# install  #{{{1
# Core  #{{{2

INSTALLATION_DIR ?= $(error Please set INSTALLATION_DIR)

RENAME_TARGET ?= $(patsubst %,$(INSTALLATION_DIR)/%,$(1))
SHOULD_INSTALL_ASIS_P ?=# All files are version-filtered by default.




.PHONY: install
install: build


define generate_rule_to_install_a_target  # (build_target, install_target)
install: $(2)
$(2): $(1)
	@echo 'INSTALL $(1)'
	@mkdir -p '$(dir $(2))'
	@cp '--preserve=mode,ownership' '$(1)' '$(2)'
ifeq '$(call SHOULD_INSTALL_ASIS_P,$(1))' ''
	@sed -i -e 's/@@VERSION@@/$(version)/' '$(2)'
endif

endef
$(eval \
  $(foreach t, \
    $(targets_all_installed), \
    $(call generate_rule_to_install_a_target,$(t),$(call RENAME_TARGET,$(t)))))


# This should be placed at the last to ensure that post-install is executed
# after any other rules to install.
install: post-install




# post-install  #{{{2

TARGETS_POST_INSTALL ?=# Empty
targets_post_install_builtin :=# Empty


ifneq '$(vim_script_repos_p)' ''
target_vim_helptags := $(call RENAME_TARGET,doc/tags)
$(target_vim_helptags): $(filter doc/%.txt,$(targets_all_installed))
	@echo 'POST-INSTALL vim helptags'
	@vim -n -N -u NONE -U NONE -e -c 'helptags $(dir $@) | qall!'

targets_post_install_builtin += $(target_vim_helptags)
endif


.PHONY: post-install
post-install: $(targets_post_install_builtin) $(TARGETS_POST_INSTALL)








# pack  #{{{1

archive_basename = $(repos_name)-$(version)
archive_name = $(archive_basename).zip


.PHONY: pack
pack: $(archive_name)

$(archive_name): $(cache_makefile)
	rm -rf '$(archive_basename)' '$(archive_name)'
	$(MAKE) \
	  'INSTALLATION_DIR=$(archive_basename)' \
	  'targets_all_installed=$(targets_all_archived)' \
	  install
	zip -r $(archive_name) $(archive_basename)/
	rm -rf '$(archive_basename)'








# release  #{{{1

.PHONY: release
release: $(if $(vim_script_repos_p),release-vim-script,release-default)


.PHONY: release-default
release-default:
	@echo 'Rules to release are not defined.'


.PHONY: release-vim-script
release-vim-script: fetch-deps $(repos_name).vimup pack
	./.mduem/deps/vimup/vimup update-script $(repos_name)
	rm $(repos_name).vimup

.PHONY: release-new-vim-script
release-new-vim-script: fetch-deps $(repos_name).vimup pack
	./.mduem/deps/vimup/vimup new-script $(repos_name)
	rm $(repos_name).vimup

$(repos_name).vimup: $(firstword $(sort $(filter doc/%.txt, \
                                                 $(all_files_in_repos))))
	./.mduem/deps/vimup/vimup-info-generator \
	  <$< \
	  >$(repos_name).vimup








# test  #{{{1

PROVE_OPTIONS ?= --comments --failure --directives
TEST_TARGETS ?=# Empty
test_t_targets := $(filter %.t,$(TEST_TARGETS))
test_vim_targets := $(filter %.vim,$(TEST_TARGETS))

.PHONY: test
test: fetch-deps
	@if [ -z '$(TEST_TARGETS)' ] || [ -n '$(test_t_targets)' ]; then \
	   prove \
	     --ext '.t' \
	     $(PROVE_OPTIONS) \
	     $(test_t_targets); \
	 else \
	   true; \
	 fi
ifneq '$(vim_script_repos_p)' ''
	@if [ -z '$(TEST_TARGETS)' ] || [ -n '$(test_vim_targets)' ]; then \
	   prove \
	     --ext '.vim' \
	     $(PROVE_OPTIONS) \
	     --exec './$(call get_dep_dir,vim-vspec)/bin/vspec \
	             $(PWD) \
	             $(foreach d,$(all_deps),$(call get_dep_dir,$(d)))' \
	     $(test_vim_targets); \
	 else \
	   true; \
	 fi
endif








# __END__  #{{{1
# vim: foldmethod=marker
