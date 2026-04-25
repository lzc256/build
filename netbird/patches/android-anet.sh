#!/bin/bash
DESCRIPTION="\
Android anet patch:
- Replace net.Interfaces() with anet.Interfaces()
- Replace iface.Addrs() with anet.InterfaceAddrsByInterface()
- Disable IsAddrRouted check (early return)
- Add anet import where needed"

TARGET="$1"

# 1. client/firewall/uspfilter/localip.go
FILE="$TARGET/client/firewall/uspfilter/localip.go"

perl -i -0pe '
s{(log "github.com/sirupsen/logrus"\n)}
{$1\t"github.com/wlynxg/anet"\n};

s{iface\.Addrs\(\)}
{anet.InterfaceAddrsByInterface(\&iface)}g;

s{net\.Interfaces\(\)}
{anet.Interfaces()}g;
' "$FILE"

# 2. client/internal/routemanager/systemops/systemops_generic.go
FILE="$TARGET/client/internal/routemanager/systemops/systemops_generic.go"

perl -i -0pe '
# Add anet import
s{(log "github.com/sirupsen/logrus"\n)}
{$1\t"github.com/wlynxg/anet"\n};

# refreshLocalSubnetsCache: net.Interfaces() -> anet.Interfaces()
s{localInterfaces, err := net\.Interfaces\(\)}
{localInterfaces, err := anet.Interfaces()};

# refreshLocalSubnetsCache: intf.Addrs() -> anet.InterfaceAddrsByInterface(&intf)
s{addrs, err := intf\.Addrs\(\)}
{addrs, err := anet.InterfaceAddrsByInterface(\&intf)};

# IsAddrRouted: early return with comment
s{(func IsAddrRouted\(addr netip\.Addr, vpnRoutes \[\]netip\.Prefix\) \(bool, netip\.Prefix\) \{\n)}
{$1\t// Android: Always skip route check. Advanced routing requires root, which Android lacks.\n\treturn false, netip.Prefix{}\n\n};
' "$FILE"

# 3. client/internal/stdnet/discover_pion.go
FILE="$TARGET/client/internal/stdnet/discover_pion.go"

perl -i -0pe '
s{import \(\n\t"net"\n\n\t"github.com/pion/transport/v3"\n\)}
{import (\n\t"github.com/pion/transport/v3"\n\t"github.com/wlynxg/anet"\n)};

s{net\.Interfaces\(\)}
{anet.Interfaces()}g;

s{oif\.Addrs\(\)}
{anet.InterfaceAddrsByInterface(\&oif)}g;
' "$FILE"

# 4. client/system/network_addr.go
FILE="$TARGET/client/system/network_addr.go"

perl -i -0pe '
# Add anet import (keep net import for net.FlagUp, net.IPNet, net.Addr)
s{import \(\n\t"net"\n\t"net/netip"\n\)}
{import (\n\t"net"\n\t"net/netip"\n\n\t"github.com/wlynxg/anet"\n)};

# net.Interfaces() -> anet.Interfaces()
s{interfaces, err := net\.Interfaces\(\)}
{interfaces, err := anet.Interfaces()};

# iface.Addrs() -> anet.InterfaceAddrsByInterface(&iface)
s{addrs, err := iface\.Addrs\(\)}
{addrs, err := anet.InterfaceAddrsByInterface(\&iface)};
' "$FILE"
