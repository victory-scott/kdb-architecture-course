/q tick/cep.q [options]
/  -p   <port>         # listening port (handled by q; defaults CEP_PORT or 5015)
/  -tp  <port>         # tickerplant port (defaults TP_PORT or 5010)
system"l tick/sym.q"

/ parse -tp <port> for tickerplant; allow -p for own port
getArg:{[flag;def] s:.z.x;i:where flag=s;$[count i;s 1+first i;def]};
envOr:{[k;def] v:getenv k; $[count v; v; def]};
if[not system"p";system"p 5015"]
if[not system"p"; system "p ", envOr["CEP_PORT";"5015"]];
tpPort:$[count p:getArg["-tp";""]; p; envOr["TP_PORT";"5010"]];
h_tp:hopen value tpPort;

/ initialize empty stats tables
.cep.tradeStats:([sym:`symbol$()]maxPrice:`float$();minPrice:`float$())
.cep.quoteStats:([sym:`symbol$()]maxBid:`float$();minAsk:`float$())

.cep.updTrade:{[x]
    .cep.tradeStats+:select maxPrice:max price, minPrice:min price by sym from x;
    `stats set .cep.tradeStats lj .cep.quoteStats
    }

.cep.updQuote:{[x]
    .cep.quoteStats+:select maxBid:max bid, minAsk:min ask by sym from x;
    `stats set .cep.tradeStats lj .cep.quoteStats
    }

upd:`trade`quote!(.cep.updTrade;.cep.updQuote)
h_tp"(.u.sub[`;`])";
.u.end:{}
