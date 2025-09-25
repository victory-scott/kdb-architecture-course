/q tick/rdb.q [options]
/  -p   <port>         # listening port (handled by q; defaults RDB_PORT or 5011)
/  -tp  <port>         # tickerplant port (defaults TP_PORT or 5010)
/  -hdb <port>         # hdb port for EOD saves (defaults HDB_PORT or 5012)
/2008.09.09 .k ->.q

if[not "w"=first string .z.o;system "sleep 1"];

/. arg parsing; env-driven defaults
getArg:{[flag;def] s:.z.x;i:where flag=s;$[count i;s 1+first i;def]};
envOr:{[k;def] v:getenv k; $[count v; v; def]};

if[not system"p"; system "p ", envOr["RDB_PORT";"5011"]]

tpPort:$[count tpp:getArg["-tp";""]; tpp; envOr["TP_PORT";"5010"]];
hdbPort:$[count hpp:getArg["-hdb";""]; hpp; envOr["HDB_PORT";"5012"]];

/ retain .u.x values as port strings (tpPort; hdbPort)
.u.x:(tpPort; hdbPort);

upd:insert;

/ end of day: save, clear, hdb reload (connect to HDB on its port)
.u.end:{t:tables`.;t@:where `g=attr each t@\:`sym;.Q.hdpf[`$ ":",.u.x 1;`:.;x;`sym];@[;`sym;`g#] each t;};

/ init schema and sync up from log file;cd to hdb(so client save can run)
.u.rep:{(.[;();:;].)each x;if[null first y;:()];-11!y;system "cd ",1_-10_string first reverse y};
/ HARDCODE \cd if other than logdir/db

/ connect to ticker plant for (schema;(logcount;log))
.u.rep .(hopen value first .u.x)"(.u.sub[`;`];`.u `i`L)";

/- service readiness log
-1 "RDB ready on port ",string .z.p," (tp ",tpPort,", hdb ",hdbPort,")";

/ access function in RDB/HDB
selectFunc:{[tbl;sd;ed;ids]
  $[`date in cols tbl;
  select from tbl where date within (sd;ed),sym in ids;
  [res:$[.z.D within (sd;ed); select from tbl where sym in ids;0#value tbl];
    `date xcols update date:.z.D from res]] }
