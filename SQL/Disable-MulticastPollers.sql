-- Scripts are provided AS IS without warranty of any kind.
-- No warranty expressed or implied. 
-- Use at your own risk.

UPDATE Pollers
SET [Enabled] = 0
WHERE PollerType LIKE 'N.MulticastRouting%' AND [Enabled] <> 0