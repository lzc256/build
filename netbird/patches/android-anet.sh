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
s{func IsAddrRouted\(addr netip\.Addr, vpnRoutes \[\]netip\.Prefix\) \(bool, netip\.Prefix\) \{\n}
{$0\treturn false, netip.Prefix{}\n};
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

# 4. client/system/info.go
FILE="$TARGET/client/system/info.go"

perl -i -0pe '
s{(log "github.com/sirupsen/logrus"\n)}
{$1\t"github.com/wlynxg/anet"\n};

s{net\.Interfaces\(\)}
{anet.Interfaces()}g;

s{iface\.Addrs\(\)}
{anet.InterfaceAddrsByInterface(\&iface)}g;
' "$FILE"
