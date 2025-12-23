SUMMARY = "Rockchip Binary Tools for creating bootloader images"
DESCRIPTION = "Tools from rkbin repository: loaderimage, trust_merger, boot_merger, etc."
LICENSE = "CLOSED"

SRC_URI = "git://github.com/rockchip-linux/rkbin.git;protocol=https;branch=master"
SRCREV = "7c35e21a8529b3758d1f051d1a5dc62aae934b2b"

S = "${WORKDIR}/git"

inherit native

DEPENDS = "python3-native"

do_configure[noexec] = "1"

do_compile() {
    # Build the tools in the tools directory
    cd ${S}/tools
    
    # Some tools need to be compiled
    if [ -f Makefile ]; then
        oe_runmake
    fi
}

do_install() {
    install -d ${D}${bindir}
    
    # Install all executable tools
    for tool in ${S}/tools/loaderimage \
                ${S}/tools/trust_merger \
                ${S}/tools/boot_merger \
                ${S}/tools/firmwareMerger \
                ${S}/tools/kernelimage \
                ${S}/tools/resource_tool; do
        if [ -f "$tool" ] && [ -x "$tool" ]; then
            install -m 0755 $tool ${D}${bindir}/$(basename $tool)
        fi
    done
    
    # Some tools might be scripts
    for script in ${S}/tools/*.sh; do
        if [ -f "$script" ]; then
            install -m 0755 $script ${D}${bindir}/$(basename $script)
        fi
    done
}

FILES:${PN} = "${bindir}/*"

BBCLASSEXTEND = "native nativesdk"
