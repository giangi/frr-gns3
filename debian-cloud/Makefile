APPLIANCE_NAME := frr-debian-cloud
CLOUD_IMAGE_URL := https://cloud.debian.org/images/cloud/bullseye/20221108-1193/debian-11-genericcloud-amd64-20221108-1193.qcow2
CLOUD_IMAGE_SHA512SUMS_URL := https://cloud.debian.org/images/cloud/bullseye/20221108-1193/SHA512SUMS

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
# Download the cloud image
	wget -N '$(CLOUD_IMAGE_URL)'
	wget -N -O SHA512SUMS '$(CLOUD_IMAGE_SHA512SUMS_URL)'
	sha512sum -c --ignore-missing SHA512SUMS
# Prepare a "base image" for packer to work on. We are not using cloud-init
# because it seems hard in this context. We are instead relying on libguestfs
# which despite being an additional requirement is easy to use. The base image
# uses the cloud image as backing to save space and time.
	qemu-img create -b '$(abspath $(shell basename '$(CLOUD_IMAGE_URL)'))' -F qcow2 -f qcow2 base.qcow2
	virt-sysprep \
		--password root:password:gns3 \
		--hostname frr \
		--firstboot-command 'DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server' \
		--firstboot-command 'sed -i -e "s/^#\?\(PermitRootLogin\).*/\1 yes/g" /etc/ssh/sshd_config' \
		--firstboot-command 'sed -i -e "s/^#\?\(PasswordAuthentication\).*/\1 yes/g" /etc/ssh/sshd_config' \
		--firstboot-command 'systemctl restart ssh.service' \
		-a base.qcow2
# Build using packer on the base image
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

.PHONY: clean
clean:
	rm -f *.qcow2 *.gns3a SHA512SUMS frr-version
	rm -rf output-qemu

.PHONY: check
check:
	packer validate '$(PACKER_TEMPLATE)'
	shellcheck $(SCRIPTS)
	jq empty '$(GNS3A_TEMPLATE)'
