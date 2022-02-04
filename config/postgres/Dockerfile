FROM postgres:14.1
COPY ./auth.sql /docker-entrypoint-initdb.d/
COPY ./dms-enroller.sql /docker-entrypoint-initdb.d/
COPY ./devices.sql /docker-entrypoint-initdb.d/