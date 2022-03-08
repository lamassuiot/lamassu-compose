CREATE DATABASE dmsenroller;

\connect dmsenroller

CREATE TABLE public.dms_store (
    id SERIAL PRIMARY KEY,
    name TEXT,
    serialNumber TEXT,
    keyType TEXT,
    keyBits int,    
    csrBase64 TEXT,
    status TEXT
);

CREATE TABLE public.authorized_cas (
    id SERIAL PRIMARY KEY,
    serialNumber TEXT,
    caname  TEXT
);