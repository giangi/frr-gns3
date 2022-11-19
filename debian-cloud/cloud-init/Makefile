PREREQ := user-data meta-data
SEED_IMG := seed.iso

.PHONY: all
all: $(SEED_IMG)

# Here we can use:
# - genisoimage as exemplified by
#   https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html
# - mkisofs
# - cloud-localds
# - mkfs.vfat (using ISO instead of FAT)
# And who knows how many others. Going with the first only because it is the
# first example from cloud-init's documentation.
$(SEED_IMG): $(PREREQ)
	genisoimage -output $@ -volid cidata -joliet -rock $^

.PHONY: clean
clean:
	rm -f $(SEED_IMG)
