BEGIN;

SELECT dropIfExists('FUNCTION', 'deleteworkcenter(integer)');
SELECT dropIfExists('FUNCTION', 'explodePlannedOrder(INTEGER, BOOLEAN)');
SELECT dropIfExists('FUNCTION', 'checkBOOSitePrivs(INTEGER)');
SELECT dropIfExists('FUNCTION', 'calcwooperstart(INTEGER, INTEGER)');
SELECT dropIfExists('FUNCTION', 'unWoClockOut(INTEGER)');

COMMIT;
