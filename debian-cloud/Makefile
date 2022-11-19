APPLIANCE_NAME := frr-debian-cloud

PACKER_TEMPLATE := packer.json
IMAGE := output-qemu/image.qcow2
SCRIPTS := $(shell find scripts -type f -iname '*.sh')
IMAGE_PREREQ := $(PACKER_TEMPLATE) $(SCRIPTS)
GNS3A_TEMPLATE := gns3a.json
GNS3A := $(APPLIANCE_NAME).gns3a
TIMESTAMP := $(shell TZ=Etc/UTC date '+%Y%m%d%H%M%S')

.PHONY: all
all: appliance

$(IMAGE): $(IMAGE_PREREQ)
# Prepare cloud-init configuration
	$(MAKE) -C cloud-init
# Build using packer
	packer build -force '$(PACKER_TEMPLATE)'
# Test we have build artifacts
	qemu-img info '$(IMAGE)'
	test -f frr-version

# Building the "appliance" is relatively trivial. It involves renaming the image
# file and creating an appliance template file. Because of this, and since we
# cannot predict the FRR version, make this PHONY.
.PHONY: appliance
# Note that the following must be recursively expanded
APPLIANCE_VERSION = $(shell cat frr-version)-$(TIMESTAMP)
APPLIANCE_DISK_IMAGE = $(APPLIANCE_NAME)-$(APPLIANCE_VERSION).qcow2
appliance: $(IMAGE) $(GNS3A_TEMPLATE)
# Hard link the image
	ln -f '$(IMAGE)' '$(APPLIANCE_DISK_IMAGE)'
# Create appliance template file and test it is valid JSON
	cat '$(GNS3A_TEMPLATE)' \
		| jq '.images[0].filename = "$(APPLIANCE_DISK_IMAGE)"' \
		| jq '.images[0].version = "$(APPLIANCE_VERSION)"' \
		| jq ".images[0].md5sum = \"$$(md5sum '$(APPLIANCE_DISK_IMAGE)' | awk '{print $$1}')\"" \
		| jq ".images[0].filesize = $$(stat -c %s '$(APPLIANCE_DISK_IMAGE)')" \
		| jq '.versions[0].name = "$(APPLIANCE_VERSION)"' \
		| jq '.versions[0].images.hda_disk_image = "$(APPLIANCE_DISK_IMAGE)"' \
		> '$(GNS3A)'
	jq empty '$(GNS3A)'

.PHONY: clean-build
clean-build:
	rm -rf output-qemu
	rm -f $(APPLIANCE_NAME)*.qcow2 $(APPLIANCE_NAME)*.gns3a frr-version
	$(MAKE) -C cloud-init clean

.PHONY: clean
clean: clean-build
	rm -f *.qcow2 *.gns3a

.PHONY: check
check:
	packer validate '$(PACKER_TEMPLATE)'
	shellcheck $(SCRIPTS)
	jq empty '$(GNS3A_TEMPLATE)'
