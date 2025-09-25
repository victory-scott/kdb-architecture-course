/q tick/feed.q [options]
/  -tp  <port>         # tickerplant port (defaults TP_PORT or 5010)

/ parse simple CLI flags: -tp <port>; default from env
getArg:{[flag;def] s:.z.x;i:where flag=s;$[count i;s 1+first i;def]};
envOr:{[k;def] v:getenv k; $[count v; v; def]};

tpPort:$[count p:getArg["-tp";""]; p; envOr["TP_PORT";"5010"]];
h_tp:hopen value tpPort;

.z.ts:{h_tp"(.u.upd[`trade;(2#.z.n;2?`APPL`MSFT`AMZN`GOOGL`TSLA`META;2?10000f;2?`B`S)])";
      h_tp"(.u.upd[`quote;(2#.z.n;2?`APPL`MSFT`AMZN`GOOGL`TSLA`META;2?10000f;2?10000f;2?500i;2?500i)])"};
      
system"t 1000";

/ to run manually for demo purposes copy/paste the following:
/ h_tp"(.u.upd[`trade;(2#.z.n;2?`APPL`MSFT`AMZN`GOOGL`TSLA`META;2?10000f;2?`B`S)])"
