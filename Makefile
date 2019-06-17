################################################################################
# Description:
#  Executes validations and tests for this puppet module
#
ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PUPPET_VERSION := "~> 6.0"
KITCHEN_GEMFILE ?= $(ROOT_DIR)/build/kitchen/Gemfile
TEST_NAME ?= puppet6

RBENV_PATH := $(HOME)/.rbenv
export RBENV_VERSION := 2.5.1

# Run all targets
.PHONY: all
# Not running unit tests since we don't have any
all: setup test

# list all makefile targets
.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

# setup CI environment
.PHONY: setup
setup: .setup .rbenv

# setup CI environment
.PHONY: test
test: .setup .test-setup .test

# cleanup CI environment
.PHONY: clean
clean: .clean

# runs kitchen unit tests
.PHONY: kitchen
kitchen: setup .kitchen

################################################################################

.PHONY: .rbenv
.rbenv:
	@echo
	@echo "==================== rbenv ===================="
	@echo
	if [ ! -d "$(RBENV_PATH)" ]; then \
		git clone https://github.com/rbenv/rbenv.git $(RBENV_PATH); \
		cd $(RBENV_PATH) && src/configure && make -C src; \
		echo 'export PATH="$$HOME/.rbenv/bin:$$PATH"' >> ~/.bashrc; \
		echo 'eval "$$(rbenv init -)"' >> ~/.bashrc; \
		git clone https://github.com/rbenv/ruby-build.git $(RBENV_PATH)/plugins/ruby-build; \
	fi;

.PHONY: .setup
.setup: .rbenv
	@echo
	@echo "==================== setup ===================="
	@echo
# TODO install bundler (yum -y install rubygem-bundler)
# TODO install rake (yum -y install rubygem-rake)
# TODO install ruby-devel (yum -y install ruby-devel)
# TODO install docker (yum -y install docker)
	whoami
	echo $(HOME)
	echo $(SHELL)
	echo $(PATH)
# https://github.com/rbenv/ruby-build/wiki#suggested-build-environment
#yum install -y gcc bzip2 openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel
	rbenv install --skip-existing $(RBENV_VERSION)
	ruby --version
	rbenv local $(RBENV_VERSION)
	ruby --version

.PHONY: .test-setup
.test-setup:
	@echo
	@echo "==================== test-setup ===================="
	@echo
	bundle -v
	gem install bundler
	bundle -v
	rm -f $(ROOT_DIR)/Gemfile.lock
	gem --version
	PUPPET_GEM_VERSION=$(PUPPET_VERSION) bundle install --without system_tests --path="$${BUNDLE_PATH:-$(ROOT_DIR)/vendor/bundle}"

.PHONY: .test
.test:
	@echo
	@echo "==================== test ===================="
	@echo
	PUPPET_GEM_VERSION=$(PUPPET_VERSION) bundle exec rake syntax lint metadata_lint check:symlinks check:git_ignore check:dot_underscore check:test_file rubocop parallel_spec

.PHONY: .clean
.clean:
	@echo
	@echo "==================== clean ===================="
	@echo
	rm -rf $(ROOT_DIR)/.bundle
	rm -rf $(ROOT_DIR)/vendor
	rm -f $(ROOT_DIR)/Gemfile.lock
	find "$(ROOT_DIR)" -type d -name '.kitchen' | xargs -r -t -n1 rm -rf
	find "$(ROOT_DIR)" -type d -name '.librarian' -or -type d -name '.tmp' | xargs -r -t -n1 rm -rf
	rm -rf $(ROOT_DIR)/build/kitchen/.bundle
	rm -rf $(ROOT_DIR)/build/kitchen/vendor
	rm -rf $(ROOT_DIR)/spec/fixtures

.PHONY: .kitchen
.kitchen:
	@echo
	@echo "==================== kitchen ===================="
	@echo
	BUNDLE_GEMFILE=$(KITCHEN_GEMFILE)	bundle install
	BUNDLE_GEMFILE=$(KITCHEN_GEMFILE) bundle exec kitchen test --debug $(TEST_NAME)
