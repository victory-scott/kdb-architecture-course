/q tick/hdb.q [options]
/  -p   <port>         # listening port (handled by q; defaults HDB_PORT or 5012)

/ allow -p to set listening port (q handles -p); default from env
envOr:{[k;def] v:getenv k; $[count v; v; def]};
if[not system"p"; system"p ", envOr["HDB_PORT";"5012"]]

if[1>count .z.x;show"Supply directory of historical database";exit 0];
hdb:.z.x 0
/Mount the Historical Date Partitioned Database
@[{system"l ",x};hdb;{show "Error message - ",x;exit 0}]

/ access function in RDB/HDB
selectFunc:{[tbl;sd;ed;ids]
  $[`date in cols tbl;
  select from tbl where date within (sd;ed),sym in ids;
  [res:$[.z.D within (sd;ed); select from tbl where sym in ids;0#value tbl];
    `date xcols update date:.z.D from res]] }

/- service readiness log
-1 "HDB ready on port ",string .z.p;
