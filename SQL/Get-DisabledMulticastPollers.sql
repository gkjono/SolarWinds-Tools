-- Scripts are provided AS IS without warranty of any kind.
-- Use at your own risk.
-- https://github.com/gkjono/SolarWinds-Tools

SELECT n.Caption
	, n.IP_Address
	, n.Vendor
	, n.MachineType
	, p.PollerID
	, p.PollerType
	, [Enabled] 
FROM Pollers p
INNER JOIN NodesData n ON n.NodeID=p.NetObjectID
WHERE PollerType LIKE 'N.MulticastRouting%' AND [Enabled] = 0