/q tick/gw.q [options]
/  -p   <port>         # listening port (handled by q; defaults GW_PORT or 5014)
/  -rdb <port>         # RDB port (defaults RDB_PORT or 5011)
/  -hdb <port>         # HDB port (defaults HDB_PORT or 5012)

/ parse simple CLI flags; peers as ports
getArg:{[flag;def] s:.z.x;i:where flag=s;$[count i;s 1+first i;def]};
envOr:{[k;def] v:getenv k; $[count v; v; def]};

/ default own port from env if -p not provided
if[not system"p"; system "p ", envOr["GW_PORT";"5014"]]

/ peer addresses (ports only)
rdbPort:$[count rp:getArg["-rdb";""]; rp; envOr["RDB_PORT";"5011"]];
hdbPort:$[count hp:getArg["-hdb";""]; hp; envOr["HDB_PORT";"5012"]];

h_hdb:hopen value hdbPort;
h_rdb:hopen value rdbPort;

/- service readiness log
-1 "GW ready on port ",string .z.p," (rdb ",rdbPort,", hdb ",hdbPort,")";

/ stored procedure in gateway
/ sd:start date; ed:end date; ids:list of ids or symbols
getTradeData:{[sd;ed;ids]
  hdb:h_hdb(`selectFunc;`trade;sd;ed;ids);
  rdb:h_rdb(`selectFunc;`trade;sd;ed;ids);
  :select from hdb,rdb where time = (max;time) fby([]date;sym) }
