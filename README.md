# FRRouting GNS3 Appliances

This project contains experimental [FRRouting](https://frrouting.org/) appliances for [GNS3](https://www.gns3.com/)

## Appliances

* [`debian-standard`](./debian-standard/): built using a standard installation
  from [Debian netinst ISOs](https://www.debian.org/distrib/netinst#verysmall)
* [`debian-cloud`](./debian-cloud/): built by using [Debian Cloud
Images](https://cloud.debian.org/images/cloud/). Smaller size, may miss some
features.

Both Debian appliances install the [official stable Debian
packages](https://deb.frrouting.org/) of FRR.

## Build requirements

* [GNU Make](https://www.gnu.org/software/make/)
* [Packer](https://www.packer.io/)
* [jq](https://stedolan.github.io/jq/)
* [QEMU](https://www.qemu.org/)
* [libguestfs-tools](https://libguestfs.org/)

## Building

```sh
make
```

Will build all appliances. It is possible to run `make` from each appliance
directory to build just the one of interest.

Each appliance will build

* A crude GNS3 appliance template file (`.gns3a`) to ease importing into GNS3
* `<APPLIANCE>-<DEB_VERSION>-<TIMESTAMP>.qcow2`: appliance disk image
  (e.g. `frr-debian-cloud-8.3.1-0~deb11u1-20220131235959.qcow2`)
  * `APPLIANCE` is the appliance name
  * `DEB_VERSION` is the version of the installed `frr` Debian package
  * `TIMESTAMP` is a build timestamp in the format `YYYYmmddHHMMSS`

## Importing in GNS3

Since the project is experimental and all builds are local and ephemeral, it
does not aim to leverage the download and versioning capability of GNS3
appliances. The built GNS3 appliance template file does not incrementally
receive new versions, but tracks only a single version which changes at each
build.

To import the appliance, a good idea is to move relevant artifacts to a location
which GNS3 considers for discovery, e.g. the Downloads directory

```sh
cp *.gns3a frr-*.qcow2 ~/Downloads
```

then import the appliance template file.

On new builds, even though the appliance file contains a single version, It
should be then possible to repeat the above process ending up with multiple
versions of the appliance.

### Warning: cleanly re-importing the appliance

For a completely clean import, it is important to note that GNS3 seems to keep
track of appliance and disk image files (e.g. in `~/GNS3`) even after an
appliance gets uninstalled. As such, deleting and re-importing an appliance is
not *completely* clean.

For a full delete/import cycle, manual cleanup of all files seems necessary,
e.g. with a careful use of

```sh
find ~/GNS3 -type f -iname 'frr-debian*' -print0 | xargs -0 rm -i
```

## Usage

The image is set up to provide autologin as root in the serial console. If
needed, the root account password is `gns3`.

### Warning: gracefully shutting down the appliance

Even though
[GNS3/gns3-registry#441](https://github.com/GNS3/gns3-registry/issues/441) seems
to suggest so, I could not find any obvious way to setup qemu appliances to
perform graceful shutdowns via ACPI by default (i.e. through the a setting in
the `.gns3a` file). The `acpi_shutdown` boolean flag seems the right thing, but
it is not present in `.gns3a` schemas, and is ignored when importing the
appliance.

As such, each created instance must be manually configured to do so from its GUI
node if data integrity has to be guaranteed.
