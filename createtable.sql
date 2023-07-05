CREATE TABLE IF NOT EXISTS perf_results (
    TS timestamp NOT NULL,
    VEGAVERSION text NOT NULL,
    VEGABRANCH text NOT NULL,
    TESTNAME text NOT NULL,
    LPUSERS integer,
    NORMALUSERS integer,
    MARKETS integer,
    VOTERS integer,
    LPOPS integer,
    PEGGED integer,
    USELP boolean,
    PRICELEVELS integer,
    FILLPL boolean,
    RUNTIME integer,
    OPS integer,
    EPS REAL,
    BACKLOG REAL,
    CORECPU REAL,
    DNCPU REAL,
    PGCPU REAL
);
