/q tick/rts.q [options]
/  -p   <port>         # listening port (handled by q; defaults RTS_PORT or 5013)
/  -tp  <port>         # tickerplant port (defaults TP_PORT or 5010)
system"l tick/sym.q"

/ parse -tp <port>; default from env if none
getArg:{[flag;def] s:.z.x;i:where flag=s;$[count i;s 1+first i;def]};
envOr:{[k;def] v:getenv k; $[count v; v; def]};
if[not system"p"; system "p ", envOr["RTS_PORT";"5013"]]
tpPort:$[count p:getArg["-tp";""]; p; envOr["TP_PORT";"5010"]];
h_tp:hopen value tpPort;

latestSymPrice: `sym xkey 0#trade;   //we key by sym as we want to know this on a per sym basis

upd:{[t;d]  insert[t;d];
            if[t~`trade;              //if the table is trade, then add the data to latestSymPrice
                 `latestSymPrice upsert select by sym from d]};

h_tp"(.u.sub[`;`])";

.u.end:{}
