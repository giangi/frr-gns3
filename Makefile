SUBDIRS := debian-cloud debian-standard

.PHONY: all clean
all clean: $(SUBDIRS)

.PHONY: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
