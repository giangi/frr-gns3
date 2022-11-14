SUBDIRS := debian-cloud debian-standard

.PHONY: all clean clean-build
all clean clean-build: $(SUBDIRS)

.PHONY: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
